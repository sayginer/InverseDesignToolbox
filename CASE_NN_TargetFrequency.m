%% CASE_NN_TargetFrequency  -  neural-network surrogate optimization: find the brick layout with a given f1.
%
%  Case study = saved simulation parameters + the neural-network optimizer + figures. Same problem and same
%  goal as CASE_SIMP_TargetFrequency.m, so the two optimizers can be compared directly.
%
%  What it does (details in docs/04_neural_network.md):
%     1. analyse random smooth brick layouts with the real FEA            -> training data (in parallel)
%     2. train a 3-D convolutional network: brick layout -> f1            (Deep Learning Toolbox)
%     3. search the network with a genetic algorithm (ga)                 about a millisecond per design
%     4. verify the best candidates with the real FEA, add them to the data, retrain -> repeat ("rounds")
%  The answer is always a layout verified with the real analysis, never a prediction.
%
%  Steps:  1. load the problem   2. goal and options   3. optimize   4. report   5. figures
%          6. manufacturable shape: preview + STL file   7. save
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

%% 1. LOAD THE PROBLEM  (the parameters saved by SIM_HarmonicMotion.m)
ProblemName = 'VibrationIsolator';
P = idt_load_params(ProblemName);

% Changes for the optimization run (the same ones as in CASE_SIMP_TargetFrequency.m, so results are comparable):
P.Design.Density = 30;                       % bigger bricks = fewer variables (402 bricks)
P.Analysis.Transmissibility = false;         % not needed for the search: every analysis is faster

model = idt_build_model(P);

%% 2. GOAL AND OPTIONS  (every option is explained in optimizers/neural/nn_options.m)
H = struct();
H.Objective    = 'TargetF1';       % 'TargetF1' = hit a natural frequency | 'MaximizeF1' = highest f1 for VolMax
H.TargetF1     = 100;              % goal for the first natural frequency [Hz]  ('TargetF1')
H.VolMax       = [];               % largest volume fraction of the design domain, 0..1 (needed for 'MaximizeF1')
H.NumSamples   = 1000;             % random layouts analysed to start with (more = better network, longer)
H.VolFracRange = [0.05 0.45];      % volume fraction of the random layouts
H.FieldRadius  = 6e-3;             % smoothness of the random layouts [m]
H.UseParallel  = true;             % analyse layouts in parallel (Parallel Computing Toolbox)
H.Network      = 'cnn';            % 'cnn' = 3-D convolutional network | 'mlp' = fully connected
H.MaxEpochs    = 300;              % training epochs (early stopping on held-back data)
H.PopSize      = 200;              % genetic algorithm: individuals per generation
H.Generations  = 60;               % genetic algorithm: generations
H.TopK         = 24;               % candidates per pass verified with the real FEA
H.Rounds       = 4;                % train + search + verify cycles
H.Passes       = 2;                % search + verify passes per round; the network is calibrated between passes
H.VerifiedWeight = 5;              % verified layouts count this much when retraining
H.Seed         = 1;                % random seed
% PRINTABILITY: every layout is cleaned (no checkerboards / islands / thin features) and the answer is polished.
H.Clean        = struct('MinWidth', 2, ...        % smallest feature width in bricks
                        'CloseGaps', 2, ...       % one-brick gaps and holes are filled
                        'Overhang', false, ...    % true = remove bricks without support below (print bottom-up)
                        'KeepOnly', 'loadpath');  % keep only groups joining supports and load ('attached' | 'all')
H.Polish       = struct('MaxSteps', 12, 'Tol', 0.5);   % brick-by-brick fine tuning with the real analysis; [] = off

%% 3. OPTIMIZE  (training data -> network -> ga on the network -> verification, repeated)
out = nn_optimize(model, H);
met = out.met;

%% 4. REPORT
fprintf('\n---------------- NEURAL-NETWORK RESULT ----------------\n');
fprintf('  real FEA analyses used : %d  (%.0f s of FEA), total time %.0f s\n', size(out.D.X, 1), out.D.time, out.TotalTime);
fprintf('  final layout           : %s\n', ternary(out.FromSearch, 'proposed by the search', 'one of the random starting layouts'));
fprintf('  design bricks kept     : %d of %d\n', nnz(out.X), model.NumVars);
fprintf('  f1 / f2                : %.2f / %.2f Hz\n', met.f1, met.f2);
if strcmp(H.Objective, 'TargetF1'), fprintf('  target f1              : %.2f Hz\n', H.TargetF1); end
fprintf('  mass                   : %.2f g\n', met.Mass * 1e3);
fprintf('  floating elements      : %d\n', met.Dropped);
fprintf('-------------------------------------------------------\n');

%% 5. FIGURES
nn_plot_surrogate(out);                                          % how good is the network, progress per round
idt_plot_brick_selection(model.Geom, model.Bricks, out.M);       % the layout as clean bricks
idt_plot_analysis(model, out.X, out.res, 'Design', true, 'Transmissibility', false);   % response, modes

%% 6. MANUFACTURABLE SHAPE: preview and STL file  (the part you print; checked for a closed surface)
stl = idt_export_stl(model, out.X, ['nn_design_' ProblemName]);          % results/nn_design_<ProblemName>.stl, in mm

%% 7. SAVE  (out.D keeps all analysed layouts: they can train other networks)
if ~isfolder(fullfile(idt_root(), 'results')), mkdir(fullfile(idt_root(), 'results')); end
save(fullfile(idt_root(), 'results', ['NN_' ProblemName '.mat']), 'out', 'H', 'P');
fprintf('Saved results/NN_%s.mat\n', ProblemName);

function o = ternary(c, a, b)
    if c, o = a; else, o = b; end
end
