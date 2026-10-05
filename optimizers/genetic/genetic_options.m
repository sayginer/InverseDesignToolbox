function H = genetic_options(H)
% GENETIC_OPTIONS  Defaults and validation of the genetic-algorithm (GA) optimizer settings.
%
%   H = genetic_options(H)          H may be [] or hold only the fields you want to change.
%
% METHOD IN ONE PARAGRAPH
%   A population of brick layouts evolves by selection, crossover and mutation (ga, Global Optimization Toolbox).
%   Every individual is first made printable (idt_clean_bricks) and then judged with the REAL analysis (idt_analyze),
%   in parallel. No gradients and no network: it needs only the cost, so it works for any goal, but it needs many
%   analyses (population x generations).
%
% GOAL (same names as SIMP and the neural network)
%  Objective    'TargetF1'   'TargetF1': make f1 equal TargetF1 | 'MaximizeF1': highest f1 within VolMax
%  TargetF1     []           target for f1 [Hz] (required for 'TargetF1')
%  VolMax       []           largest volume fraction of the design domain, 0..1
%                            (required for 'MaximizeF1'; optional upper bound for 'TargetF1')
%
% GENETIC ALGORITHM
%  PopSize      60           individuals per generation
%  Generations  40           maximum number of generations
%  StallGenerations 12       stop when the best cost has not improved for this many generations
%  FreqTol      0.3          'TargetF1': stop as soon as |f1 - TargetF1| < FreqTol [Hz]
%  EliteCount   3            best individuals copied unchanged into the next generation
%  CrossoverFraction 0.8     fraction of children made by crossover (two-point: swaps contiguous blocks of bricks,
%                            which keeps local structure; scattered crossover shreds layouts)
%  MutationRate 0.004        probability that a brick flips in a child (402 bricks: about 1.6 flips per child)
%
% STARTING POPULATION (random smooth layouts, then cleaned)
%  VolFracRange [0.05 0.45]  volume fraction of the random layouts
%  FieldRadius  6e-3         smoothness of the random layouts [m] (about 2 brick edges)
%  Seed         1            random seed for the starting population
%
% PRINTABILITY (same functions as SIMP and the neural network)
%  Clean        struct()     every individual is cleaned before it is judged, so the GA searches printable layouts only
%                            (fields: MinWidth 2, CloseGaps 2, Overhang false, KeepOnly 'loadpath'). [] = off.
%  Polish       struct()     at the end, brick-by-brick fine tuning with the real analysis (MaxSteps 12, Tol 0.5 Hz). [] = off.
%
% OUTPUT
%  UseParallel  true         evaluate the individuals in parallel (Parallel Computing Toolbox); falls back to serial
%  Verbose      true         print one line per generation
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    D = struct('Objective', 'TargetF1', 'TargetF1', [], 'VolMax', [], ...
               'PopSize', 60, 'Generations', 40, 'StallGenerations', 12, 'FreqTol', 0.3, 'EliteCount', 3, ...
               'CrossoverFraction', 0.8, 'MutationRate', 0.004, ...
               'VolFracRange', [0.05 0.45], 'FieldRadius', 6e-3, 'Seed', 1, ...
               'Clean', struct(), 'Polish', struct(), 'UseParallel', true, 'Verbose', true);
    if nargin < 1 || isempty(H), H = struct(); end
    H = idt_fill_defaults(H, D);

    assert(any(strcmp(H.Objective, {'TargetF1', 'MaximizeF1'})), ...
        'genetic_options:Objective', 'Objective must be ''TargetF1'' or ''MaximizeF1''.');
    if strcmp(H.Objective, 'TargetF1')
        assert(~isempty(H.TargetF1), 'genetic_options:TargetF1', 'Objective ''TargetF1'' needs H.TargetF1 [Hz].');
    else
        assert(~isempty(H.VolMax), 'genetic_options:VolMax', 'Objective ''MaximizeF1'' needs H.VolMax (0..1).');
    end
    assert(isempty(H.VolMax) || (H.VolMax > 0 && H.VolMax <= 1), 'VolMax must be in (0, 1].');
    assert(H.PopSize >= 10 && H.Generations >= 1, 'PopSize must be >= 10 and Generations >= 1.');
    assert(H.EliteCount < H.PopSize, 'EliteCount must be smaller than PopSize.');
    assert(numel(H.VolFracRange) == 2 && H.VolFracRange(1) < H.VolFracRange(2), 'VolFracRange must be [low high].');
end
