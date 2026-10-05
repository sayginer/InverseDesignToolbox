function out = nn_optimize(model, H)
% NN_OPTIMIZE  Neural-network surrogate optimization of the brick layout. No figures.
%
%   out = nn_optimize(model, H)         model: from idt_build_model        H: from nn_options
%
% First: H.NumSamples random smooth layouts are analysed with the real FEA (nn_make_dataset).
% Then, for every round
%   1. train  a network that predicts f1 from the brick layout (nn_train)
%   2. search the network with a genetic algorithm (ga, bit-string, vectorized): the fitness of a whole
%      generation costs about a second instead of hundreds of finite-element analyses
%   3. verify the best TopK candidates with the REAL analysis (idt_analyze, in parallel)
%   4. CALIBRATE: the network is biased exactly where the search looks (it finds the layouts the network
%      likes best, which are often the ones it is most wrong about). The median log(true f1 / predicted f1) of
%      the verified candidates is used as a correction and steps 2-3 are repeated (H.Passes passes per round)
%   5. add the verified layouts to the training data (weighted), retrain in the next round
%
% Goal (H.Objective, same as SIMP)
%   'TargetF1'    minimize ((f1 - TargetF1)/TargetF1)^2          (VolMax optional upper bound)
%   'MaximizeF1'  maximize f1 subject to volume fraction <= VolMax
% The final answer is always the best layout that was verified with the real analysis, never a prediction.
%
% OUTPUT out: .X (best verified layout, one entry per design brick), .M (brick matrix for
%   idt_plot_brick_selection), .met, .res (full analysis of it), .D (all analysed layouts), .sur (last network),
%   .Rounds (struct array per round: surrogate quality, candidate quality, best f1, data size), .FromSearch (true if
%   the final layout was proposed by the search rather than being one of the random starting layouts), .TotalTime, .H
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    H = nn_options(H);
    tAll = tic;
    nVar = model.NumVars;
    volBrick = nn_brick_volumes(model);  volTot = sum(volBrick);
    isTarget = strcmp(H.Objective, 'TargetF1');
    Vgraph = nn_validity_setup(model);
    Cs = [];  if ~isempty(H.Clean), Cs = idt_clean_setup(model); end

    D = nn_make_dataset(model, H);                       % first training data: random smooth layouts
    nStart = size(D.X, 1);
    rounds = repmat(struct('R2', NaN, 'MAPE', NaN, 'nData', 0, 'nVerified', 0, 'nUsable', 0, 'bias', 0, ...
                           'errFirst', NaN, 'errLast', NaN, 'candBest', NaN, 'bestTrue', NaN, 'bestVol', NaN), 1, H.Rounds);
    rs = RandStream('twister', 'Seed', H.Seed + 1);

    for r = 1:H.Rounds
        %% 1. train
        sur = nn_train(model, D, H);
        fref = max(D.f1(D.usable));
        bias = 0;  nVer = 0;  nUse = 0;  errFirst = NaN;  errLast = NaN;  candBest = NaN;  scBest = Inf;

        for pass = 1:H.Passes
            %% 2. search the surrogate with ga (seeded with the best layouts verified so far)
            fit = @(P) surrogate_cost(P, sur, H, volBrick, volTot, isTarget, fref, Vgraph, bias, Cs);
            score = true_score(D, H, isTarget);
            [~, ord] = sort(score, 'ascend');
            nBest = min(nnz(isfinite(score)), round(H.PopSize / 2));
            seedIdx = [ord(1:nBest); randi(rs, size(D.X, 1), H.PopSize - nBest, 1)];
            gaopts = optimoptions('ga', 'PopulationType', 'bitstring', 'UseVectorized', true, ...
                'PopulationSize', H.PopSize, 'MaxGenerations', H.Generations, 'MaxStallGenerations', 40, ...
                'InitialPopulationMatrix', double(D.X(seedIdx, :)), 'CrossoverFraction', 0.8, ...
                'CrossoverFcn', @crossovertwopoint, ...     % swaps contiguous blocks of bricks, keeps local structure
                'MutationFcn', {@mutationuniform, 0.004}, 'EliteCount', 5, 'Display', 'off');
            [~, ~, ~, ~, pop, sc] = ga(fit, nVar, [], [], [], [], [], [], [], gaopts);

            %% 3. verify the best new candidates with the real analysis
            [~, o] = sort(sc, 'ascend');
            cand = logical(pop(o, :) > 0.5);
            if ~isempty(Cs)                                  % the answer must be printable: clean the candidates
                cand = idt_clean_bricks(Cs, cand, H.Clean);
                cand = cand(any(cand, 2), :);
            end
            cand = unique(cand, 'rows', 'stable');
            cand = cand(~ismember(cand, D.X, 'rows'), :);    % only layouts not analysed yet
            if isempty(cand), break; end
            cand = cand(1:min(H.TopK, size(cand, 1)), :);
            Hq = H;  Hq.Verbose = false;
            Dn = nn_make_dataset(model, Hq, cand);           % (cleans again and skips cut-off layouts)
            if isempty(Dn.X), break; end
            predRaw = nn_predict(sur, Dn.X);                 % uncorrected predictions for the layouts actually analysed
            us = Dn.usable;
            nVer = nVer + size(Dn.X, 1);  nUse = nUse + nnz(us);
            if nnz(us) > 0
                pc = predRaw(us) * exp(bias);                % what the search believed
                err = median(abs(pc - Dn.f1(us)) ./ Dn.f1(us)) * 100;     % median: robust against single outliers
                if pass == 1, errFirst = err; end
                errLast = err;
                bias = bias + median(log(Dn.f1(us) ./ pc));  % calibrate for the next pass
            end
            [bsc, ibc] = min(true_score(Dn, H, isTarget));
            if isfinite(bsc) && bsc < scBest, scBest = bsc; candBest = Dn.f1(ibc); end

            %% 4. add to the data (verified layouts count more when retraining)
            % A verified layout that turned out to be a hinge is a lesson: the search proposed it because the network
            % liked it. It enters the training data with the label f1 = 1 Hz so the network learns to avoid that region.
            Dn.w = H.VerifiedWeight * ones(size(Dn.w));
            Dn.fit = true(size(Dn.fit));
            Dn.f1fit = Dn.f1;  Dn.f1fit(~Dn.usable) = 1;
            D = struct('X', [D.X; Dn.X], 'f1', [D.f1; Dn.f1], 'usable', [D.usable; Dn.usable], ...
                       'vol', [D.vol; Dn.vol], 'mass', [D.mass; Dn.mass], 'w', [D.w; Dn.w], ...
                       'fit', [D.fit; Dn.fit], 'f1fit', [D.f1fit; Dn.f1fit], 'time', D.time + Dn.time);
        end

        [bs, ib] = min(true_score(D, H, isTarget));
        rounds(r) = struct('R2', sur.metrics.R2, 'MAPE', sur.metrics.MAPE, 'nData', size(D.X, 1), 'nVerified', nVer, ...
            'nUsable', nUse, 'bias', bias, 'errFirst', errFirst, 'errLast', errLast, 'candBest', candBest, ...
            'bestTrue', D.f1(ib), 'bestVol', D.vol(ib));
        if H.Verbose
            fprintf(['Round %d/%d: surrogate R^2 %.2f | %d candidates verified (%d usable) | surrogate error on them %.0f %% -> %.0f %% after calibration | ' ...
                     'best candidate f1 = %.2f Hz | best overall f1 = %.2f Hz (vol %.1f %%)\n'], ...
                r, H.Rounds, sur.metrics.R2, nVer, nUse, errFirst, errLast, candBest, D.f1(ib), 100 * D.vol(ib));
        end
        if ~isfinite(bs), warning('nn_optimize:NoUsable', 'No usable layout found yet.'); end
    end

    [~, ib] = min(true_score(D, H, isTarget));
    X = D.X(ib, :)';
    polish = [];
    if ~isempty(H.Polish) && ~isempty(Cs)                % close the last gap with the real analysis (printable bricks only)
        goal = struct('Objective', H.Objective, 'TargetF1', H.TargetF1, 'VolMax', H.VolMax);
        po = H.Polish;  po.Verbose = H.Verbose;  po.UseParallel = H.UseParallel;
        [X, polish] = idt_polish_bricks(model, X, goal, Cs, H.Clean, po);
    end
    [res, met] = idt_analyze(model, X);
    M = nan(model.Bricks.Grid.N);
    M(model.Bricks.Present) = 1;
    M(model.VarBricks) = double(X);
    out = struct('X', X, 'M', M, 'met', met, 'res', res, 'D', D, 'sur', sur, 'Rounds', rounds, 'Polish', polish, ...
                 'FromSearch', ib > nStart, 'TotalTime', toc(tAll), 'H', H);
    if H.Verbose
        if out.FromSearch, src = 'proposed by the search'; else, src = 'one of the random starting layouts'; end
        fprintf('NN optimization finished in %.0f s: f1 = %.2f Hz (%s), %d of %d bricks kept, %d layouts analysed in total\n', ...
            out.TotalTime, met.f1, src, nnz(X), nVar, size(D.X, 1));
    end
end

function J = surrogate_cost(P, sur, H, volBrick, volTot, isTarget, fref, Vgraph, bias, Cs)
% cost of a whole generation (rows of P) predicted by the (bias-corrected) network; lower is better.
% Every individual is cleaned first, so the search judges the printable layout it would actually produce.
    Xb = P > 0.5;
    if ~isempty(Cs), Xb = idt_clean_bricks(Cs, Xb, H.Clean); end
    f = nn_predict(sur, Xb) * exp(bias);
    vol = (double(Xb) * volBrick) / volTot;
    if isTarget
        J = ((f - H.TargetF1) / H.TargetF1).^2;
    else
        J = -f / fref;
    end
    if ~isempty(H.VolMax), J = J + 10 * max(0, vol - H.VolMax) / H.VolMax; end
    J = J + 50 * ~nn_is_valid(Vgraph, Xb);                % cut-off layouts are exactly known to be useless
end

function s = true_score(D, H, isTarget)
% ranking of the layouts analysed with the real FEA (Inf = not usable or over the volume limit)
    s = inf(size(D.f1));
    ok = D.usable;
    if ~isempty(H.VolMax), ok = ok & D.vol <= H.VolMax * 1.0000001; end
    if isTarget, s(ok) = abs(D.f1(ok) - H.TargetF1); else, s(ok) = -D.f1(ok); end
end
