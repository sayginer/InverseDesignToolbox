function H = shape_options(H)
% SHAPE_OPTIONS  Defaults and validation of the shape (cutter) optimizer settings.
%
%   H = shape_options(H)          H may be [] or hold only the fields you want to change.
%
% METHOD IN ONE PARAGRAPH
%   The design is a fixed number of holes and rectangles (idt_shape_options) that are subtracted from the design part. The
%   numbers that describe them (positions, sizes, angles) are searched by a genetic algorithm (ga, Global Optimization
%   Toolbox, real-valued). Each individual is analysed with the REAL eigenfrequency analysis on the fixed mesh (the elements
%   inside the cutters are removed), in parallel. Afterwards the best design is checked with the exact CAD cut and a new mesh.
%
% GOAL (same names as the brick optimizers)
%  Objective    'TargetF1'   'TargetF1': make f1 equal TargetF1 | 'MaximizeF1': highest f1 within VolMax |
%                            'MinTransmissibility': ISOLATOR, the smallest peak transmissibility in a frequency band |
%                            STATIC load (P.Analysis.Type = 'Static'): 'MinCompliance': stiffest design for VolMax (smallest F'u) |
%                            'MinMass': lightest design whose deflection stays below MaxDeflection
%  TargetF1     []           target for f1 [Hz] (required for 'TargetF1')
%  VolMax       []           largest fraction of the design part's volume that may remain, 0..1
%                            (required for 'MaximizeF1'; optional upper bound for the other goals)
%  MaxDeflection []          'MinMass': largest allowed |displacement| of output 1 along the load direction [m]
%  Isolation    struct()     'MinTransmissibility' only: Band [f_low f_high] Hz that must be blocked, Output (protected point(s)),
%                            Pairs ([response base] directions, [3 3] = vertical), TargetT (stop below this peak T).
%                            Cost = log10(largest T in the band). See idt_isolation_options. Transmissibility is switched on for you.
%
% GENETIC ALGORITHM
%  PopSize      40           individuals per generation (each one is a real analysis, about 1 s)
%  Generations  40           maximum number of generations
%  StallGenerations 10       stop when the best cost has not improved for this many generations
%  FreqTol      0.3          'TargetF1': stop as soon as |f1 - TargetF1| < FreqTol [Hz]
%  EliteCount   2            best individuals copied unchanged into the next generation
%  Seed         1            random seed of the starting population
%
% OUTPUT
%  UseParallel  true         evaluate the individuals in parallel (Parallel Computing Toolbox); falls back to serial
%  LivePlot     true         redraw the convergence figure after every generation (does not take the focus)
%  Verbose      true         print one line per generation
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    D = struct('Objective', 'TargetF1', 'TargetF1', [], 'VolMax', [], 'MaxDeflection', [], 'Isolation', struct(), ...
               'PopSize', 40, 'Generations', 40, 'StallGenerations', 10, 'FreqTol', 0.3, 'EliteCount', 2, ...
               'Seed', 1, 'UseParallel', true, 'LivePlot', true, 'Verbose', true);
    if nargin < 1 || isempty(H), H = struct(); end
    H = idt_fill_defaults(H, D);

    assert(any(strcmp(H.Objective, {'TargetF1', 'MaximizeF1', 'MinTransmissibility', 'MinCompliance', 'MinMass'})), ...
        'shape_options:Objective', 'Objective must be ''TargetF1'', ''MaximizeF1'', ''MinTransmissibility'', ''MinCompliance'' or ''MinMass''.');
    if strcmp(H.Objective, 'MinCompliance'), assert(~isempty(H.VolMax), 'shape_options:VolMax', 'Objective ''MinCompliance'' needs H.VolMax (0..1).'); end
    if strcmp(H.Objective, 'MinMass'), assert(~isempty(H.MaxDeflection), 'shape_options:MaxDeflection', 'Objective ''MinMass'' needs H.MaxDeflection [m].'); end
    if strcmp(H.Objective, 'TargetF1')
        assert(~isempty(H.TargetF1), 'shape_options:TargetF1', 'Objective ''TargetF1'' needs H.TargetF1 [Hz].');
    elseif strcmp(H.Objective, 'MaximizeF1')
        assert(~isempty(H.VolMax), 'shape_options:VolMax', 'Objective ''MaximizeF1'' needs H.VolMax (0..1).');
    end
    assert(isempty(H.VolMax) || (H.VolMax > 0 && H.VolMax <= 1), 'VolMax must be in (0, 1].');
    assert(H.PopSize >= 10 && H.Generations >= 1, 'PopSize must be >= 10 and Generations >= 1.');
    assert(H.EliteCount < H.PopSize, 'EliteCount must be smaller than PopSize.');
end
