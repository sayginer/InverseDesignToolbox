function S = static_options(S)
% STATIC_OPTIONS  Defaults and validation of the settings of the static-load optimizers
% (static_simp_optimize and static_ga_optimize).
%
%   S = static_options(S)          S may be [] or hold only the fields you want to change.
%
% GOAL
%  Objective     'MinCompliance'  'MinCompliance': stiffest layout for the volume VolMax (smallest F'u) |
%                                 'MinMass': lightest layout whose deflection stays below MaxDeflection (GA only)
%  VolMax        0.5              largest fraction of the DESIGN-BRICK volume that may be present, 0..1.
%                                 Bricks locked by supports / load / outputs are not counted.
%  MaxDeflection []               'MinMass': largest allowed |displacement| of output 1 along the load direction [m]
%
% SIMP (static_simp_optimize)
%  Penal         3                SIMP penalization exponent p: stiffness of a brick = rho^p
%  Emin          1e-6             stiffness of a removed brick relative to a solid one (keeps K regular)
%  FilterRadius  []               density filter radius [m]; [] = 1.5 x the median brick edge. Prevents checkerboards.
%  BetaMax       8                Heaviside projection: sharpness doubles from 1 up to BetaMax (pushes densities to 0 / 1)
%  BetaEvery     30               iterations between the doublings
%  MaxIter       200              iteration limit
%  Tol           0.01             stop when no brick density changes by more than this (after BetaMax is reached)
%  MoveLimit     0.2              largest change of a brick density per iteration (optimality-criteria update)
%
% GENETIC ALGORITHM (static_ga_optimize)
%  PopSize 60, Generations 40, StallGenerations 12, EliteCount 3, CrossoverFraction 0.8, MutationRate 0.01
%  VolFracRange  [0.3 0.7]        volume fraction of the random starting layouts
%  FieldRadius   10e-3            smoothness of the random starting layouts [m]
%  Seed          1                random seed of the starting population
%  UseParallel   true             evaluate the population in parallel (falls back to serial)
%  LivePlot      true             redraw the convergence figure after every generation (does not take the focus)
%
% NEURAL NETWORK (static_nn_optimize)
%  NNSamples 300 random training layouts | NNNetwork 'cnn' ('cnn' | 'mlp') | NNHidden [256 128] (mlp) | NNEpochs 300 | NNMiniBatch 64
%  NNLearnRate 1e-3 | NNValFraction 0.15 | NNPop 200 and NNGenerations 60 (search on the network) | NNTopK 24 (verified per round)
%  NNRounds 3 (train + search + verify cycles) | NNVerifiedWeight 5 (verified layouts are repeated this often when retraining)
%  (VolFracRange, FieldRadius, Seed and UseParallel of the GA block are used for the training layouts too)
%
% PRINTABILITY (all)
%  Clean         struct()         the result (SIMP) or every individual (GA) is cleaned with idt_clean_bricks:
%                                 fields MinWidth 1, CloseGaps 1, Overhang false, KeepOnly 'loadpath'. [] = off.
%                                 (MinWidth / CloseGaps 1 = off: the example beam is only 6 bricks tall.)
%  Verbose       true             print progress
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    D = struct('Objective', 'MinCompliance', 'VolMax', 0.5, 'MaxDeflection', [], ...
               'Penal', 3, 'Emin', 1e-6, 'FilterRadius', [], 'BetaMax', 8, 'BetaEvery', 30, 'MaxIter', 200, 'Tol', 0.01, 'MoveLimit', 0.2, ...
               'PopSize', 60, 'Generations', 40, 'StallGenerations', 12, 'EliteCount', 3, ...
               'CrossoverFraction', 0.8, 'MutationRate', 0.01, 'VolFracRange', [0.3 0.7], ...
               'FieldRadius', 10e-3, 'Seed', 1, 'UseParallel', true, 'LivePlot', true, ...
               'NNSamples', 300, 'NNNetwork', 'cnn', 'NNHidden', [256 128], 'NNEpochs', 300, 'NNMiniBatch', 64, ...
               'NNLearnRate', 1e-3, 'NNValFraction', 0.15, 'NNPop', 200, 'NNGenerations', 60, 'NNTopK', 24, ...
               'NNRounds', 3, 'NNVerifiedWeight', 5, ...
               'Clean', struct(), 'Verbose', true);
    if nargin < 1 || isempty(S), S = struct(); end
    S = idt_fill_defaults(S, D);
    if isstruct(S.Clean) && isempty(fieldnames(S.Clean))
        S.Clean = struct('MinWidth', 1, 'CloseGaps', 1, 'Overhang', false, 'KeepOnly', 'loadpath');
    end

    assert(any(strcmp(S.Objective, {'MinCompliance', 'MinMass'})), ...
        'static_options:Objective', 'Objective must be ''MinCompliance'' or ''MinMass''.');
    assert(S.VolMax > 0 && S.VolMax <= 1, 'static_options:VolMax', 'VolMax must be in (0, 1].');
    if strcmp(S.Objective, 'MinMass')
        assert(~isempty(S.MaxDeflection) && S.MaxDeflection > 0, 'static_options:MaxDeflection', ...
            'Objective ''MinMass'' needs S.MaxDeflection [m].');
    end
    assert(S.PopSize >= 10 && S.Generations >= 1, 'PopSize must be >= 10 and Generations >= 1.');
    assert(S.EliteCount < S.PopSize, 'EliteCount must be smaller than PopSize.');
end
