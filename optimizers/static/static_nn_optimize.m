function out = static_nn_optimize(model, S)
% STATIC_NN_OPTIMIZE  Neural-network surrogate optimization of the brick layout for static stiffness. No figures.
%
%   out = static_nn_optimize(model, S)       model: from idt_build_model (P.Analysis.Type = 'Static')
%                                            S: from static_options ([] = defaults)
%
% Same method as nn_optimize (frequency goals), with the static analysis as the physics:
%   1. make random smooth brick layouts and analyse them with the real static analysis (training data)
%   2. train a network (nn_train, 3-D CNN or MLP) that predicts the relative stiffness  s = compliance(full) / compliance(layout)
%   3. search the network with a genetic algorithm (about a millisecond per design instead of a solve), volume limit S.VolMax
%   4. verify the best candidates with the real analysis, add them to the data (counted S.NNVerifiedWeight times), retrain, repeat
% Goal: 'MinCompliance' (stiffest layout for S.VolMax). Every layout is cleaned first when S.Clean is set.
%
% OUTPUT out: .X, .M, .met, .res, .D (all analysed layouts: .X .comp .vol .mass .usable .f1fit), .sur (last network),
%   .Rounds (per round: R2, MAPE, nData, nVerified, bestCompliance), .GAHistory (.best .mean .start), .NumEvaluations (real solves),
%   .TotalTime, .S
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    S = static_options(S);
    tAll = tic;
    nVar = model.NumVars;
    assert(nVar > 0, 'static_nn_optimize:NoDesign', 'The model has no design bricks.');
    assert(strcmp(model.Params.Analysis.Type, 'Static'), 'static_nn_optimize:Type', ...
        'Set P.Analysis.Type = ''Static'' before building the model.');
    assert(strcmp(S.Objective, 'MinCompliance'), 'static_nn_optimize:Objective', ...
        'The neural-network optimizer minimizes the compliance; use static_ga_optimize for ''MinMass''.');
    volBrick = nn_brick_volumes(model);  volTot = sum(volBrick);
    Vgraph = nn_validity_setup(model);
    Cs = [];  if ~isempty(S.Clean), Cs = idt_clean_setup(model); end
    [~, m0] = idt_analyze(model);  c0 = m0.Compliance;           % all bricks present: the reference of the label
    Hn = nn_options(struct('Objective', 'MaximizeF1', 'VolMax', S.VolMax, 'Network', S.NNNetwork, 'Hidden', S.NNHidden, ...
                           'MaxEpochs', S.NNEpochs, 'MiniBatch', S.NNMiniBatch, 'LearnRate', S.NNLearnRate, ...
                           'ValFraction', S.NNValFraction, 'Seed', S.Seed, 'Verbose', false, 'UseParallel', S.UseParallel));
    useP = S.UseParallel && license('test', 'Distrib_Computing_Toolbox') && ~isempty(ver('parallel'));
    if useP
        try
            if isempty(gcp('nocreate')), parpool('Processes'); end
            pctRunOnAll('warning(''off'', ''all'')');
        catch
            useP = false;
        end
    end
    rs = RandStream('twister', 'Seed', S.Seed);

    %% 1. training data: random smooth layouts
    R = idt_random_layouts(model, 3 * S.NNSamples, S.VolFracRange, S.FieldRadius, rs);
    R = clean_rows(Cs, R, S.Clean);
    R = R(nn_is_valid(Vgraph, R), :);
    R = R(1:min(S.NNSamples, size(R, 1)), :);
    D = analyse(model, R, c0, volBrick, volTot, useP);
    if S.Verbose, fprintf('NN: %d training layouts analysed (%.1f s)\n', size(D.X, 1), D.time); end
    nReal = size(D.X, 1);

    gaHist = struct('best', [], 'mean', [], 'start', []);
    rounds = repmat(struct('R2', NaN, 'MAPE', NaN, 'nData', 0, 'nVerified', 0, 'bestCompliance', NaN), 1, S.NNRounds);
    for r = 1:S.NNRounds
        sur = nn_train(model, D, Hn);
        score = true_score(D, S);
        [~, ord] = sort(score, 'ascend');
        nBest = min(nnz(isfinite(score)), round(S.NNPop / 2));
        seedIdx = [ord(1:nBest); randi(rs, size(D.X, 1), S.NNPop - nBest, 1)];
        fit = @(Pm) surrogate_cost(Pm, sur, S, volBrick, volTot, Vgraph, Cs);
        gaopts = optimoptions('ga', 'PopulationType', 'bitstring', 'UseVectorized', true, ...
            'PopulationSize', S.NNPop, 'MaxGenerations', S.NNGenerations, 'MaxStallGenerations', 40, ...
            'InitialPopulationMatrix', double(D.X(seedIdx, :)), 'CrossoverFraction', 0.8, 'CrossoverFcn', @crossovertwopoint, ...
            'MutationFcn', {@mutationuniform, 0.01}, 'EliteCount', 5, 'Display', 'off', 'OutputFcn', @recordGA);
        gaHist.start(end + 1) = numel(gaHist.best) + 1;
        [~, ~, ~, ~, pop, sc] = ga(fit, nVar, [], [], [], [], [], [], [], gaopts);

        [~, o] = sort(sc, 'ascend');
        cand = clean_rows(Cs, logical(pop(o, :) > 0.5), S.Clean);
        cand = unique(cand, 'rows', 'stable');
        cand = cand(~ismember(cand, D.X, 'rows'), :);
        cand = cand(nn_is_valid(Vgraph, cand), :);
        nVer = 0;
        if ~isempty(cand)
            cand = cand(1:min(S.NNTopK, size(cand, 1)), :);
            Dn = analyse(model, cand, c0, volBrick, volTot, useP);
            nVer = size(Dn.X, 1);
            Dn.w = S.NNVerifiedWeight * ones(size(Dn.w));           % verified layouts count more when retraining
            D = struct('X', [D.X; Dn.X], 'comp', [D.comp; Dn.comp], 'usable', [D.usable; Dn.usable], 'vol', [D.vol; Dn.vol], ...
                       'mass', [D.mass; Dn.mass], 'w', [D.w; Dn.w], 'fit', [D.fit; Dn.fit], 'f1fit', [D.f1fit; Dn.f1fit], ...
                       'f1', [D.f1; Dn.f1], 'time', D.time + Dn.time);
        end
        [bs, ib] = min(true_score(D, S));
        rounds(r) = struct('R2', sur.metrics.R2, 'MAPE', sur.metrics.MAPE, 'nData', size(D.X, 1), 'nVerified', nVer, ...
                           'bestCompliance', bs);
        if S.Verbose
            fprintf('Round %d/%d: surrogate R^2 %.2f, mean error %.0f %% | %d candidates verified | best compliance %.4g mJ (vol %.1f %%)\n', ...
                r, S.NNRounds, sur.metrics.R2, sur.metrics.MAPE, nVer, bs * 1e3, 100 * D.vol(ib));
        end
        if isempty(cand) && S.Verbose, fprintf('  (the search proposed nothing new)\n'); break; end
    end

    [bs, ib] = min(true_score(D, S));
    if ~isfinite(bs), [~, ib] = min(D.vol); end                      % nothing within the volume limit: the smallest layout
    X = D.X(ib, :)';
    [res, met] = idt_analyze(model, X);
    M = nan(model.Bricks.Grid.N);
    M(model.Bricks.Present) = 1;
    M(model.VarBricks) = double(X);
    out = struct('Method', 'NN', 'X', X, 'M', M, 'met', met, 'res', res, 'D', D, 'sur', sur, 'Rounds', rounds, ...
                 'GAHistory', gaHist, 'FromSearch', ib > nReal, 'NumEvaluations', size(D.X, 1), 'TotalTime', toc(tAll), 'S', S);
    if S.Verbose
        fprintf('NN optimization finished in %.0f s: compliance %.4g mJ, %d of %d bricks kept, %d layouts analysed in total\n', ...
            out.TotalTime, met.Compliance * 1e3, nnz(X), nVar, size(D.X, 1));
    end

    function [state, options, optchanged] = recordGA(options, state, flag)
        optchanged = false;
        if ~any(strcmp(flag, {'init', 'iter'})), return; end
        gaHist.best(end + 1) = min(state.Score);
        gaHist.mean(end + 1) = mean(state.Score);
        if S.LivePlot, genetic_plot_live(gaHist, 'NN surrogate search'); end
    end
end

function D = analyse(model, X, c0, volBrick, volTot, useP)
% real static analysis of every row of X; label = relative stiffness c0 / compliance
    n = size(X, 1);  comp = nan(n, 1);  mass = nan(n, 1);
    t0 = tic;
    if useP
        parfor i = 1:n
            [~, m] = idt_analyze(model, X(i, :)');
            if m.Valid, comp(i) = m.Compliance; mass(i) = m.Mass; end
        end
    else
        for i = 1:n
            [~, m] = idt_analyze(model, X(i, :)');
            if m.Valid, comp(i) = m.Compliance; mass(i) = m.Mass; end
        end
    end
    usable = isfinite(comp) & comp > 0;
    s = c0 ./ comp;  s(~usable) = NaN;
    D = struct('X', logical(X), 'comp', comp, 'usable', usable, 'vol', (double(X) * volBrick) / volTot, 'mass', mass, ...
               'w', ones(n, 1), 'fit', usable, 'f1fit', s, 'f1', s, 'time', toc(t0));
end

function X = clean_rows(Cs, X, cleanOpt)
% printable layouts only: clean every row, drop empty and duplicate layouts (order kept)
    if isempty(Cs), X = unique(X(any(X, 2), :), 'rows', 'stable'); return; end
    X = idt_clean_bricks(Cs, X, cleanOpt);
    X = X(any(X, 2), :);
    [~, iu] = unique(X, 'rows', 'stable');
    X = X(iu, :);
end

function J = surrogate_cost(Pm, sur, S, volBrick, volTot, Vgraph, Cs)
% cost of a whole generation (rows of Pm) predicted by the network; lower is better
    Xb = Pm > 0.5;
    if ~isempty(Cs), Xb = idt_clean_bricks(Cs, Xb, S.Clean); end
    s = nn_predict(sur, Xb);                                   % predicted relative stiffness
    vol = (double(Xb) * volBrick) / volTot;
    J = -s + 10 * max(0, vol - S.VolMax) / S.VolMax + 50 * ~nn_is_valid(Vgraph, Xb);
end

function sc = true_score(D, S)
% ranking by the real analysis (Inf = not analysable or over the volume limit)
    sc = inf(size(D.comp));
    ok = D.usable & D.vol <= S.VolMax * 1.0000001;
    sc(ok) = D.comp(ok);
end
