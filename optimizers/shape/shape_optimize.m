function out = shape_optimize(smodel, S, H)
% SHAPE_OPTIMIZE  Genetic-algorithm optimization of cutter positions and sizes with the real analysis. No figures.
%
%   out = shape_optimize(smodel, S, H)      smodel, S: from idt_shape_setup       H: from shape_options
%
% The unknowns are the numbers of S.NumParams cutter parameters (S.Names): x, y, radius for every hole and x, y, width, height,
% angle for every rectangle. ga (Global Optimization Toolbox, real-valued, bounds S.LB / S.UB) evolves a population of them.
% The cost of one individual:
%   1. cutters   idt_cutters_from_vector: too small or too close to a support = switched off
%   2. analyse   idt_cutters_mask removes the mesh elements inside the cutters, idt_analyze runs the REAL eigen-analysis
%   3. cost      'TargetF1'    ((f1 - TargetF1)/TargetF1)^2          (+ volume penalty if VolMax is set)
%                'MaximizeF1'  -f1 / f1_uncut + volume penalty
%                a design that cannot be analysed (load cut off from the supports) costs 50
%                walls thinner than S.C.MinWall add 10 x (their area / design-part area)
%                After the search the best design is repaired (idt_cutters_repair_walls: the cutters shrink a little).
% The population is evaluated in parallel; the model is sent to the workers once (parallel.pool.Constant).
% Cutters can switch themselves off (size below the minimum), so a design may use fewer cutters than S.NumHoles + S.NumRects.
% Check the best design with the exact CAD cut afterwards: idt_cutters_geometry + idt_cutters_verify.
%
% OUTPUT out: .p (best number vector), .cut (its cutters), .X (element mask), .VolFrac, .met, .res (full analysis),
%   .History (best and mean cost per generation; genetic_plot_history draws it), .NumEvaluations, .Generations,
%   .TotalTime, .H, .WallOk / .Wall (minimum-wall check of the result, see idt_cutters_wall)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    H = shape_options(H);
    tAll = tic;
    isTarget = strcmp(H.Objective, 'TargetF1');
    [~, m0] = idt_analyze(smodel);                       % the part as it is: scale for 'MaximizeF1'
    fref = m0.f1;

    useP = H.UseParallel && license('test', 'Distrib_Computing_Toolbox') && ~isempty(ver('parallel'));
    if useP
        try
            if isempty(gcp('nocreate')), parpool('Processes'); end
            pctRunOnAll('warning(''off'', ''all'')');
            cm = parallel.pool.Constant(smodel);  cs = parallel.pool.Constant(S);
        catch
            useP = false;
        end
    end
    if ~useP, cm = struct('Value', smodel);  cs = struct('Value', S); end
    cost = @(p) shape_cost(p, cm, cs, H, fref, isTarget);

    rs = RandStream('twister', 'Seed', H.Seed);
    P0 = S.LB + rand(rs, H.PopSize, S.NumParams) .* (S.UB - S.LB);       % random starting designs

    hist = struct('best', [], 'mean', []);
    opts = optimoptions('ga', 'UseParallel', useP, 'UseVectorized', false, 'PopulationSize', H.PopSize, ...
        'MaxGenerations', H.Generations, 'MaxStallGenerations', H.StallGenerations, ...
        'InitialPopulationMatrix', P0, 'EliteCount', H.EliteCount, 'OutputFcn', @record, 'Display', 'off');
    if isTarget, opts.FitnessLimit = (H.FreqTol / H.TargetF1)^2; end

    if H.Verbose
        if useP, mode = 'parallel'; else, mode = 'serial'; end
        fprintf('Shape GA: %d numbers (%d holes, %d rectangles), population %d, up to %d generations (%s)\n', ...
            S.NumParams, S.NumHoles, S.NumRects, H.PopSize, H.Generations, mode);
    end
    [pb, ~, ~, output] = ga(cost, S.NumParams, [], [], [], [], S.LB, S.UB, [], opts);

    cut = idt_cutters_from_vector(S, pb);
    [cut, nRep] = idt_cutters_repair_walls(S, cut);        % the search only penalized thin walls: fix what is left
    if H.Verbose && nRep > 0, fprintf('  minimum wall: cutters shrunk %.0f %% to remove the last thin walls\n', 100 * (1 - 0.97^nRep)); end
    [X, vf] = idt_cutters_mask(S, cut);
    [res, met] = idt_analyze(smodel, X);
    [wallOk, wall] = idt_cutters_wall(S, cut);
    out = struct('p', pb(:)', 'cut', cut, 'X', X, 'VolFrac', vf, 'WallOk', wallOk, 'Wall', wall, 'met', met, 'res', res, 'History', hist, ...
                 'NumEvaluations', output.funccount, 'Generations', output.generations, ...
                 'TotalTime', toc(tAll), 'H', H);
    if H.Verbose
        fprintf('Shape GA finished: %d generations, %d analyses, %.0f s: f1 = %.2f Hz, %d cutter(s) active, %.1f %% of the part left\n', ...
            out.Generations, out.NumEvaluations, out.TotalTime, met.f1, numel(cut), 100 * vf);
    end

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

function J = shape_cost(p, cm, cs, H, fref, isTarget)
% cost of ONE design (lower is better)
    smodel = cm.Value;  S = cs.Value;
    cut = idt_cutters_from_vector(S, p);
    [X, vf] = idt_cutters_mask(S, cut);
    [wallOk, wall] = idt_cutters_wall(S, cut);              % walls thinner than S.C.MinWall are penalized below
    [~, m] = idt_analyze(smodel, X);
    if ~m.Valid || ~isfinite(m.f1) || m.f1 <= 1, J = 50; return; end
    if isTarget
        J = ((m.f1 - H.TargetF1) / H.TargetF1)^2;
    else
        J = -m.f1 / fref;
    end
    if ~isempty(H.VolMax), J = J + 10 * max(0, vf - H.VolMax) / H.VolMax; end
    if ~wallOk, J = J + 1e-5 + 10 * wall.Fraction; end      % thin walls cost more than a small miss of the goal; repaired at the end
end
