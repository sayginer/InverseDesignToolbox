function H = nn_options(H)
% NN_OPTIONS  Defaults and validation of the neural-network (surrogate) optimizer settings.
%
%   H = nn_options(H)          H may be [] or hold only the fields you want to change.
%
% METHOD IN ONE PARAGRAPH
%   1. make random brick layouts and analyse them with the real FEA (the training data)
%   2. train a network that predicts f1 from the brick layout (unusable layouts count as f1 = 1 Hz)
%   3. search the surrogate with a genetic algorithm (ga): about a millisecond per design instead of a second
%   4. verify the best candidates with the real FEA, add them to the data, retrain, repeat ("rounds")
%
% GOAL (same names as SIMP)
%  Objective    'TargetF1'   'TargetF1': make f1 equal TargetF1 | 'MaximizeF1': highest f1 within VolMax
%  TargetF1     []           target for f1 [Hz] (required for 'TargetF1')
%  VolMax       []           largest volume fraction of the design domain, 0..1
%                            (required for 'MaximizeF1'; optional upper bound for 'TargetF1')
%
% TRAINING DATA
%  NumSamples   600          number of random layouts analysed for the first training set
%  VolFracRange [0.05 0.45]  each random layout gets a volume fraction drawn from this range
%  FieldRadius  6e-3         smoothness of the random layouts [m] (about 2 brick edges); bigger = blobbier
%  UseParallel  true         analyse layouts in parallel (Parallel Computing Toolbox); falls back to serial
%  Seed         1            random seed (reproducible data)
%
% NETWORK (Deep Learning Toolbox, trainnet)
%  Network      'cnn'        'cnn': 3-D convolutional network on the brick grid (needs less data, default)
%                            'mlp': fully connected network on the brick vector
%  Hidden       [256 128]    hidden layer sizes of the 'mlp'
%  MaxEpochs    300          training epochs (early stopping on the held-back data)
%  MiniBatch    64           mini-batch size
%  LearnRate    1e-3         Adam learning rate
%  ValFraction  0.15         fraction of the data held back to measure the prediction quality
%
% SEARCH ON THE SURROGATE (ga, Global Optimization Toolbox)
%  PopSize      200          individuals per generation
%  Generations  60           generations (every individual is cleaned in every generation, which dominates the run time)
%  TopK         24           candidates per round that are verified with the real FEA (in parallel). Many are
%                            hinge-like and fail, so verify generously.
%  Rounds       4            train + search + verify cycles (more rounds = better surrogate near the optimum)
%  Passes       2            search + verify passes per round; before each further pass the network is calibrated
%                            with the bias measured on the layouts just verified (the search exploits the
%                            network's errors, so the network is typically biased exactly where it looks)
%  VerifiedWeight 5          layouts verified by the real FEA are repeated this many times when retraining, so
%                            the network is corrected where the search looks
%
% PRINTABILITY (same functions as SIMP)
%  Clean        struct()     every layout (training data, search, answer) is made printable with idt_clean_bricks:
%                            gaps closed, features thinner than MinWidth bricks removed, no checkerboards or islands
%                            (face connectivity), only groups joining supports and load kept. The network therefore
%                            learns and searches printable layouts only. Fields: MinWidth (2), CloseGaps (2),
%                            Overhang (false), KeepOnly ('loadpath'). Clean = [] switches it off.
%  Polish       struct()     at the end, a local search with the real analysis adds / removes boundary bricks to close
%                            the last gap to the goal (idt_polish_bricks). Fields: MaxSteps (12), Tol (0.5 Hz).
%                            Polish = [] switches it off.
%
% OUTPUT
%  Verbose      true         print progress
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    D = struct('Objective', 'TargetF1', 'TargetF1', [], 'VolMax', [], ...
               'NumSamples', 600, 'VolFracRange', [0.05 0.45], 'FieldRadius', 6e-3, ...
               'UseParallel', true, 'Seed', 1, ...
               'Network', 'cnn', 'Hidden', [256 128], 'MaxEpochs', 300, 'MiniBatch', 64, 'LearnRate', 1e-3, ...
               'ValFraction', 0.15, 'PopSize', 200, 'Generations', 60, 'TopK', 24, 'Rounds', 4, 'Passes', 2, 'VerifiedWeight', 5, ...
               'Clean', struct(), 'Polish', struct(), 'Verbose', true);
    if nargin < 1 || isempty(H), H = struct(); end
    H = idt_fill_defaults(H, D);

    assert(any(strcmp(H.Objective, {'TargetF1', 'MaximizeF1'})), ...
        'nn_options:Objective', 'Objective must be ''TargetF1'' or ''MaximizeF1''.');
    if strcmp(H.Objective, 'TargetF1')
        assert(~isempty(H.TargetF1), 'nn_options:TargetF1', 'Objective ''TargetF1'' needs H.TargetF1 [Hz].');
    else
        assert(~isempty(H.VolMax), 'nn_options:VolMax', 'Objective ''MaximizeF1'' needs H.VolMax (0..1).');
    end
    assert(isempty(H.VolMax) || (H.VolMax > 0 && H.VolMax <= 1), 'VolMax must be in (0, 1].');
    assert(numel(H.VolFracRange) == 2 && H.VolFracRange(1) < H.VolFracRange(2), 'VolFracRange must be [low high].');
    assert(H.NumSamples >= 50, 'NumSamples must be at least 50.');
    assert(H.Rounds >= 1, 'Rounds must be >= 1.');
    assert(any(strcmp(H.Network, {'cnn', 'mlp'})), 'Network must be ''cnn'' or ''mlp''.');
end
