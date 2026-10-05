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
%                 a layout that cannot be analysed (cut off from the supports, hinge) costs 50
% The search starts from random smooth layouts. At the end idt_polish_bricks closes the last gap to the goal.
%
% Every evaluation is a real finite-element analysis: population x generations of them (about 2000 for the defaults).
% That is the price of needing neither gradients (SIMP) nor training data (neural network).
%
% OUTPUT out: .X (best layout, one entry per design brick), .M (brick matrix for idt_plot_brick_selection), .met, .res
%   (full analysis), .History (best and mean cost per generation), .Polish, .NumEvaluations, .Generations, .TotalTime, .H
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    H = genetic_options(H);
    tAll = tic;
    nVar = model.NumVars;
    assert(nVar > 0, 'genetic_optimize:NoDesign', 'The model has no design bricks.');
    isTarget = strcmp(H.Objective, 'TargetF1');
    Cs = [];  if ~isempty(H.Clean), Cs = idt_clean_setup(model); end
    ev = model.ElemVar;
    volBrick = accumarray(ev(ev > 0), model.Vol(ev > 0), [nVar, 1]);
    volTot = sum(volBrick);

    fref = 1;
    if ~isTarget, [~, m0] = idt_analyze(model); fref = m0.f1; end      % f1 with all bricks present scales 'MaximizeF1'

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

    hist = struct('best', [], 'mean', []);
    opts = optimoptions('ga', 'PopulationType', 'bitstring', 'UseParallel', useP, 'UseVectorized', false, ...
        'PopulationSize', H.PopSize, 'MaxGenerations', H.Generations, 'MaxStallGenerations', H.StallGenerations, ...
        'InitialPopulationMatrix', double(R), 'EliteCount', H.EliteCount, 'CrossoverFraction', H.CrossoverFraction, ...
        'CrossoverFcn', @crossovertwopoint, 'MutationFcn', {@mutationuniform, H.MutationRate}, ...
        'OutputFcn', @record, 'Display', 'off');
    if isTarget, opts.FitnessLimit = (H.FreqTol / H.TargetF1)^2; end      % stop as soon as the target is met

    if H.Verbose
        if useP, mode = 'parallel'; else, mode = 'serial'; end
        fprintf('GA: population %d, up to %d generations, real FEA for every individual (%s)\n', H.PopSize, H.Generations, mode);
    end
    [xb, ~, ~, output] = ga(cost, nVar, [], [], [], [], [], [], [], opts);

    X = xb(:) > 0.5;
    if ~isempty(Cs), X = idt_clean_bricks(Cs, X, H.Clean); end

    polish = [];
    if ~isempty(H.Polish) && ~isempty(Cs)
        goal = struct('Objective', H.Objective, 'TargetF1', H.TargetF1, 'VolMax', H.VolMax);
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
    if H.Verbose
        fprintf('GA finished: %d generations, %d analyses, %.0f s: f1 = %.2f Hz, %d of %d bricks kept\n', ...
            out.Generations, out.NumEvaluations, out.TotalTime, met.f1, nnz(X), nVar);
    end

    %% ---- nested: record the history and print one line per generation ---------------------------------
    function [state, options, optchanged] = record(options, state, flag)
        optchanged = false;
        if ~any(strcmp(flag, {'init', 'iter'})), return; end
        hist.best(end + 1) = min(state.Score);
        hist.mean(end + 1) = mean(state.Score);
        if H.Verbose && strcmp(flag, 'iter')
            fprintf('  generation %3d: best cost %.5f, mean %.4f\n', state.Generation, hist.best(end), hist.mean(end));
        end
    end
end

function J = genetic_cost(x, cm, cc, H, volBrick, volTot, isTarget, fref)
% cost of ONE individual (lower is better): clean -> real analysis -> goal
    model = cm.Value;  Cs = cc.Value;
    xb = x(:) > 0.5;
    if ~isempty(Cs), xb = idt_clean_bricks(Cs, xb, H.Clean); end
    if ~any(xb), J = 50; return; end
    [~, m] = idt_analyze(model, xb);
    if ~m.Valid || ~isfinite(m.f1) || m.f1 <= 1, J = 50; return; end        % cut off or hinge-like
    if isTarget
        J = ((m.f1 - H.TargetF1) / H.TargetF1)^2;
    else
        J = -m.f1 / fref;
    end
    if ~isempty(H.VolMax)
        vol = sum(volBrick(xb)) / volTot;
        J = J + 10 * max(0, vol - H.VolMax) / H.VolMax;
    end
end
