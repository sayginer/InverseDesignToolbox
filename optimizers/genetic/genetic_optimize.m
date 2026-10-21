function out = genetic_optimize(model, H)
% GENETIC_OPTIMIZE  Genetic-algorithm optimization of the brick layout with the real analysis. No figures.
%
%   out = genetic_optimize(model, H)          model: from idt_build_model        H: from genetic_options
%
% A population of brick layouts (one bit per design brick) evolves with ga (Global Optimization Toolbox, bit-string
% population, two-point crossover, uniform mutation). The cost of an individual is
%   1. clean      idt_clean_bricks: the individual becomes a printable layout (no checkerboards, islands, thin features)
%   2. analyse    idt_analyze: the REAL eigenfrequency analysis (in parallel over the population)
%   3. cost       'TargetF1'    ((f1 - TargetF1)/TargetF1)^2           (+ volume penalty if VolMax is set)
%                 'MaximizeF1'  -f1 / f1_full + volume penalty         (f1_full: f1 with all bricks present)
%                 'MinTransmissibility'  log10(largest transmissibility in the band H.Isolation.Band), plus a penalty if the optional
%                                flat passband H.Isolation.Pass is not flat (idt_isolation_cost)   ISOLATOR goal:
%                                the base motion must not reach the protected output (see idt_isolation_options). Transmissibility
%                                is switched on in the model for this goal. A volume penalty is added if VolMax is set.
%                 a layout that cannot be analysed (cut off from the supports, hinge) costs 50
% The search starts from random smooth layouts. At the end idt_polish_bricks closes the last gap to the goal.
%
% Every evaluation is a real finite-element analysis: population x generations of them (about 2000 for the defaults).
% That is the price of needing neither gradients (SIMP) nor training data (neural network).
%
% OUTPUT out: .X (best layout, one entry per design brick), .M (brick matrix for idt_plot_brick_selection), .met, .res
%   (full analysis), .History (best and mean cost per generation), .Polish, .NumEvaluations, .Generations, .TotalTime, .H,
%   and for 'MinTransmissibility': .PeakT (largest T in the band), .Isolation (table of peaks, see idt_isolation_metric);
%   out.res then contains the transmissibility (plot it with idt_plot_isolation)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    H = genetic_options(H);
    tAll = tic;
    nVar = model.NumVars;
    assert(nVar > 0, 'genetic_optimize:NoDesign', 'The model has no design bricks.');
    isTarget = strcmp(H.Objective, 'TargetF1');
    three = isfield(model, 'Damper') && ~isempty(model.Damper);     % three states per brick: void / structure / damper (two bits per brick)
    isIso = strcmp(H.Objective, 'MinTransmissibility');
    if isIso                                    % isolator goal: the transmissibility must be computed in every analysis
        model.Params.Analysis.Transmissibility = true;
        H.Isolation = idt_isolation_options(H.Isolation, model);
        if H.Verbose, fprintf('Isolator goal: minimize the peak transmissibility %g-%g Hz, output %s, pairs %s\n', H.Isolation.Band, mat2str(H.Isolation.Output), mat2str(H.Isolation.Pairs)); end
    end
    Cs = [];  if ~isempty(H.Clean), Cs = idt_clean_setup(model); end
    ev = model.ElemVar;
    volBrick = accumarray(ev(ev > 0), model.Vol(ev > 0), [nVar, 1]);
    volTot = sum(volBrick);

    fref = 1;
    if strcmp(H.Objective, 'MaximizeF1'), [~, m0] = idt_analyze(model); fref = m0.f1; end      % f1 with all bricks present scales 'MaximizeF1'

    %% parallel pool; the model is sent to the workers ONCE (parallel.pool.Constant), not with every generation
    useP = H.UseParallel && license('test', 'Distrib_Computing_Toolbox') && ~isempty(ver('parallel'));
    if useP
        try
            if isempty(gcp('nocreate')), parpool('Processes'); end
            pctRunOnAll('warning(''off'', ''all'')');
            cm = parallel.pool.Constant(model);  cc = parallel.pool.Constant(Cs);
        catch
            useP = false;
        end
    end
    if ~useP, cm = struct('Value', model);  cc = struct('Value', Cs); end
    cost = @(x) genetic_cost(x, cm, cc, H, volBrick, volTot, isTarget, fref);

    %% starting population: random smooth layouts, cleaned
    rs = RandStream('twister', 'Seed', H.Seed);
    R = idt_random_layouts(model, 3 * H.PopSize, H.VolFracRange, H.FieldRadius, rs);
    if ~isempty(Cs), R = idt_clean_bricks(Cs, R, H.Clean); end
    R = unique(R(any(R, 2), :), 'rows', 'stable');
    assert(~isempty(R), 'genetic_optimize:NoStart', 'No usable random starting layout; check H.Clean and the model.');
    R = R(mod(0:H.PopSize - 1, size(R, 1)) + 1, :);                       % repeat rows if there are too few
    if three                                                              % second bit per brick: damper (smooth random fields)
        D = idt_random_layouts(model, H.PopSize, H.DamperFracRange, H.FieldRadius, rs);
        R = [R, D];
    end

    hist = struct('best', [], 'mean', []);
    opts = optimoptions('ga', 'PopulationType', 'bitstring', 'UseParallel', useP, 'UseVectorized', false, ...
        'PopulationSize', H.PopSize, 'MaxGenerations', H.Generations, 'MaxStallGenerations', H.StallGenerations, ...
        'InitialPopulationMatrix', double(R), 'EliteCount', H.EliteCount, 'CrossoverFraction', H.CrossoverFraction, ...
        'CrossoverFcn', @crossovertwopoint, 'MutationFcn', {@mutationuniform, H.MutationRate}, ...
        'OutputFcn', @record, 'Display', 'off');
    if isTarget, opts.FitnessLimit = (H.FreqTol / H.TargetF1)^2; end      % stop as soon as the target is met
    if isIso && ~isempty(H.Isolation.TargetT) && isempty(H.Isolation.Pass), opts.FitnessLimit = log10(H.Isolation.TargetT); end

    if H.Verbose
        if useP, mode = 'parallel'; else, mode = 'serial'; end
        fprintf('GA: population %d, up to %d generations, real FEA for every individual (%s)\n', H.PopSize, H.Generations, mode);
    end
    [xb, ~, ~, output] = ga(cost, nVar * (1 + three), [], [], [], [], [], [], [], opts);

    X = decode_layout(xb, nVar, three, Cs, H.Clean);                      % 0/1 layout, or 0/1/2 (void/structure/damper)

    polish = [];
    if ~isempty(H.Polish) && three && H.Verbose, fprintf('  (polish is skipped for three-state designs: it toggles single bricks of the structure only)\n'); end
    if ~isempty(H.Polish) && ~isempty(Cs) && ~three
        goal = struct('Objective', H.Objective, 'TargetF1', H.TargetF1, 'VolMax', H.VolMax, 'Isolation', H.Isolation);
        po = H.Polish;  po.Verbose = H.Verbose;  po.UseParallel = H.UseParallel;
        [X, polish] = idt_polish_bricks(model, X, goal, Cs, H.Clean, po);
    end
    [res, met] = idt_analyze(model, X);
    M = nan(model.Bricks.Grid.N);
    M(model.Bricks.Present) = 1;
    M(model.VarBricks) = double(X);
    out = struct('X', X, 'M', M, 'met', met, 'res', res, 'History', hist, 'Polish', polish, ...
                 'NumEvaluations', output.funccount, 'Generations', output.generations, ...
                 'TotalTime', toc(tAll), 'H', H);
    if isIso
        [~, out.Isolation] = idt_isolation_cost(res, H.Isolation);  out.PeakT = out.Isolation.PeakT;  out.PassDev = out.Isolation.PassDev;
    end
    if H.Verbose
        fprintf('GA finished: %d generations, %d analyses, %.0f s: f1 = %.2f Hz, %d of %d bricks kept', ...
            out.Generations, out.NumEvaluations, out.TotalTime, met.f1, nnz(X), nVar);
        if three, fprintf(' (%d structure, %d damper)', nnz(X == 1), nnz(X == 2)); end
        fprintf('\n');
    end

    %% ---- nested: record the history and print one line per generation ---------------------------------
    function [state, options, optchanged] = record(options, state, flag)
        optchanged = false;
        if ~any(strcmp(flag, {'init', 'iter'})), return; end
        hist.best(end + 1) = min(state.Score);
        hist.mean(end + 1) = mean(state.Score);
        if H.LivePlot, genetic_plot_live(hist, 'GA', strcmp(H.Objective, 'TargetF1')); end
        if H.Verbose && strcmp(flag, 'iter')
            fprintf('  generation %3d: best cost %.5f, mean %.4f\n', state.Generation, hist.best(end), hist.mean(end));
        end
    end
end

function J = genetic_cost(x, cm, cc, H, volBrick, volTot, isTarget, fref)
% cost of ONE individual (lower is better): clean -> real analysis -> goal
    model = cm.Value;  Cs = cc.Value;
    three = isfield(model, 'Damper') && ~isempty(model.Damper);
    xb = decode_layout(x, model.NumVars, three, Cs, H.Clean);
    if ~any(xb), J = 50; return; end
    [res, m] = idt_analyze(model, xb);
    if ~m.Valid || ~isfinite(m.f1) || m.f1 <= 1, J = 50; return; end        % cut off or hinge-like
    if isTarget
        J = ((m.f1 - H.TargetF1) / H.TargetF1)^2;
    elseif strcmp(H.Objective, 'MinTransmissibility')
        J = idt_isolation_cost(res, H.Isolation);
        if ~isfinite(J), J = 50; return; end
    else
        J = -m.f1 / fref;
    end
    if ~isempty(H.VolMax)
        vol = sum(volBrick(xb > 0)) / volTot;
        J = J + 10 * max(0, vol - H.VolMax) / H.VolMax;
    end
end

function X = decode_layout(x, nVar, three, Cs, cleanOpt)
% genome -> layout. Bits 1..nVar: brick present. With a damper grade, bits nVar+1..2*nVar: that brick is damper. The present bricks
% are cleaned (printable); X is logical (present) or 0 / 1 / 2 (void / structure / damper).
    x = x(:) > 0.5;
    pres = x(1:nVar);
    if ~isempty(Cs), pres = idt_clean_bricks(Cs, pres, cleanOpt); end
    X = pres;
    if three, X = double(pres) + double(pres & x(nVar + 1:2 * nVar)); end
end
