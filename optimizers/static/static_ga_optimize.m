function out = static_ga_optimize(model, S)
% STATIC_GA_OPTIMIZE  Genetic-algorithm optimization of the brick layout for a static load. No figures.
%
%   out = static_ga_optimize(model, S)       model: from idt_build_model (P.Analysis.Type = 'Static')
%                                            S: from static_options ([] = defaults)
%
% A population of brick layouts (one bit per design brick) evolves with ga (Global Optimization Toolbox).
% Every individual is cleaned (optional), analysed with the REAL static analysis and judged:
%   'MinCompliance'  cost = compliance / compliance(all bricks) + 10 * max(0, vol - VolMax) / VolMax
%   'MinMass'        cost = mass / mass(all bricks) + 10 * max(0, |defl| / MaxDeflection - 1)
%                    (|defl| = displacement of output 1 along the load direction)
% A layout that cannot be analysed (cut off from the supports) costs 50.
% Needs no gradients, so any goal works; the price is population x generations static solves.
%
% OUTPUT out: .X, .M, .met, .res, .History (.best, .mean per generation), .NumEvaluations, .Generations,
%   .TotalTime, .S
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    S = static_options(S);
    tAll = tic;
    nVar = model.NumVars;
    assert(nVar > 0, 'static_ga_optimize:NoDesign', 'The model has no design bricks.');
    assert(strcmp(model.Params.Analysis.Type, 'Static'), 'static_ga_optimize:Type', ...
        'Set P.Analysis.Type = ''Static'' before building the model.');
    ev = model.ElemVar;
    volBrick = accumarray(ev(ev > 0), model.Vol(ev > 0), [nVar, 1]);
    volTot = sum(volBrick);
    [~, m0] = idt_analyze(model);                       % all bricks present: the reference of the cost
    ref = struct('Compliance', m0.Compliance, 'Mass', m0.Mass);
    Cs = [];  if ~isempty(S.Clean), Cs = idt_clean_setup(model); end

    useP = S.UseParallel && license('test', 'Distrib_Computing_Toolbox') && ~isempty(ver('parallel'));
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
    cost = @(x) ga_cost(x, cm, cc, S, volBrick, volTot, ref);

    rs = RandStream('twister', 'Seed', S.Seed);
    Rm = idt_random_layouts(model, 3 * S.PopSize, S.VolFracRange, S.FieldRadius, rs);
    if ~isempty(Cs), Rm = idt_clean_bricks(Cs, Rm, S.Clean); end
    Rm = unique(Rm(any(Rm, 2), :), 'rows', 'stable');
    assert(~isempty(Rm), 'static_ga_optimize:NoStart', 'No usable random starting layout; check S.Clean and the model.');
    Rm = Rm(mod(0:S.PopSize - 1, size(Rm, 1)) + 1, :);

    hist = struct('best', [], 'mean', []);
    opts = optimoptions('ga', 'PopulationType', 'bitstring', 'UseParallel', useP, 'UseVectorized', false, ...
        'PopulationSize', S.PopSize, 'MaxGenerations', S.Generations, 'MaxStallGenerations', S.StallGenerations, ...
        'InitialPopulationMatrix', double(Rm), 'EliteCount', S.EliteCount, 'CrossoverFraction', S.CrossoverFraction, ...
        'CrossoverFcn', @crossovertwopoint, 'MutationFcn', {@mutationuniform, S.MutationRate}, ...
        'OutputFcn', @record, 'Display', 'off');
    if S.Verbose
        if useP, mode = 'parallel'; else, mode = 'serial'; end
        fprintf('GA: population %d, up to %d generations, real static analysis for every individual (%s)\n', S.PopSize, S.Generations, mode);
    end
    [xb, ~, ~, output] = ga(cost, nVar, [], [], [], [], [], [], [], opts);

    X = decode(xb, Cs, S.Clean);
    [res, met] = idt_analyze(model, X);
    M = nan(model.Bricks.Grid.N);
    M(model.Bricks.Present) = 1;
    M(model.VarBricks) = double(X);
    out = struct('Method', 'GA', 'X', X, 'M', M, 'met', met, 'res', res, 'History', hist, ...
                 'NumEvaluations', output.funccount, 'Generations', output.generations, ...
                 'TotalTime', toc(tAll), 'S', S);
    if S.Verbose
        fprintf('GA finished: %d generations, %d analyses, %.0f s, %d of %d bricks kept, compliance %.4g mJ\n', ...
            out.Generations, out.NumEvaluations, out.TotalTime, nnz(X), nVar, met.Compliance * 1e3);
    end

    function [state, options, optchanged] = record(options, state, flag)
        optchanged = false;
        if ~any(strcmp(flag, {'init', 'iter'})), return; end
        hist.best(end + 1) = min(state.Score);
        hist.mean(end + 1) = mean(state.Score);
        if S.LivePlot, genetic_plot_live(hist, 'Static GA'); end
        if S.Verbose && strcmp(flag, 'iter')
            fprintf('  generation %3d: best cost %.5f, mean %.4f\n', state.Generation, hist.best(end), hist.mean(end));
        end
    end
end

function J = ga_cost(x, cm, cc, S, volBrick, volTot, ref)
    model = cm.Value;  Cs = cc.Value;
    xb = decode(x, Cs, S.Clean);
    if ~any(xb), J = 50; return; end
    [~, m] = idt_analyze(model, xb);
    if ~m.Valid, J = 50; return; end
    if strcmp(S.Objective, 'MinCompliance')
        vol = sum(volBrick(xb)) / volTot;
        J = m.Compliance / ref.Compliance + 10 * max(0, vol - S.VolMax) / S.VolMax;
    else
        d = model.BC.LoadDirection(:)' / norm(model.BC.LoadDirection);
        defl = abs(m.OutDefl(1, :) * d');
        J = m.Mass / ref.Mass + 10 * max(0, defl / S.MaxDeflection - 1);
    end
end

function X = decode(x, Cs, cleanOpt)
    X = x(:) > 0.5;
    if ~isempty(Cs), X = idt_clean_bricks(Cs, X, cleanOpt); end
end
