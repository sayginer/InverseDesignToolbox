%% CASE_NN_StaticBeam  -  neural-network surrogate optimization: the stiffest cantilever for a given volume.
%
%  Case study = saved simulation parameters (SIM_StaticLoad.m) + the static neural-network optimizer + figures. Same problem and goal
%  as CASE_SIMP_StaticBeam.m and CASE_GA_StaticBeam.m, so the three methods can be compared directly.
%
%  What it does (docs/11_static_optimization.md): real static analyses of random layouts train a network that predicts the stiffness
%  of a layout; a genetic algorithm searches the network (milliseconds per design); the best candidates are verified with the real
%  analysis, added to the data and the network is retrained. Needs the Deep Learning Toolbox.
%
%  Steps:  1. load the problem   2. goal and options   3. optimize   4. report   5. figures   6. save
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

%% 1. LOAD THE PROBLEM  (the parameters saved by SIM_StaticLoad.m)
ProblemName = 'CantileverBeam';
P = idt_load_params(ProblemName);

P.Mesh.Hmax  = 3.0e-3;               % coarser, linear mesh: every analysis is fast
P.Mesh.Order = 'linear';

model = idt_build_model(P);
[~, m0] = idt_analyze(model);        % the full beam

%% 2. GOAL AND OPTIONS  (every option is explained in optimizers/static/static_options.m)
S = struct();
S.Objective    = 'MinCompliance';    % stiffest layout for the volume below
S.VolMax       = 0.5;                % at most 50 % of the design-brick volume
S.NNSamples    = 800;                % random layouts analysed for the first training set
S.NNNetwork    = 'cnn';              % 'cnn' (3-D convolutional) | 'mlp'
S.NNRounds     = 4;                  % train + search + verify cycles
S.NNTopK       = 24;                 % candidates verified with the real analysis per round
S.NNPop        = 200;                % search on the network: individuals per generation
S.NNGenerations = 60;                % search on the network: generations
S.UseParallel  = true;
S.Seed         = 1;
S.Clean        = [];                 % [] = no printability clean-up (the beam is only 6 bricks tall)

%% 3. OPTIMIZE
out = static_nn_optimize(model, S);
met = out.met;

%% 4. REPORT
fprintf('\n---------------- NEURAL NETWORK RESULT ----------------\n');
fprintf('  real analyses used     : %d  (%d rounds), total time %.0f s\n', out.NumEvaluations, numel(out.Rounds), out.TotalTime);
fprintf('  design bricks kept     : %d of %d\n', nnz(out.X), model.NumVars);
if out.FromSearch, src = 'proposed by the search'; else, src = 'one of the random starting layouts'; end
fprintf('  answer                 : %s\n', src);
fprintf('  tip deflection         : %.2f um   (full beam %.2f um)\n', abs(met.OutDefl(1, 3)) * 1e6, abs(m0.OutDefl(1, 3)) * 1e6);
fprintf('  compliance             : %.4g mJ   (full beam %.4g mJ)\n', met.Compliance * 1e3, m0.Compliance * 1e3);
fprintf('  mass                   : %.1f g    (full beam %.1f g)\n', met.Mass * 1e3, m0.Mass * 1e3);
fprintf('  max von Mises          : %.1f MPa  (full beam %.1f MPa)\n', met.MaxVonMises * 1e-6, m0.MaxVonMises * 1e-6);
fprintf('-------------------------------------------------------\n');

%% 5. FIGURES
static_plot_history(out);                                        % network quality, progress per round, GA on the network
idt_plot_brick_selection(model.Geom, model.Bricks, out.M);       % the layout as clean bricks
idt_plot_static(model, out.X, out.res);                          % deformed shape and stress

%% 6. SAVE
if ~isfolder(fullfile(idt_root(), 'results')), mkdir(fullfile(idt_root(), 'results')); end
save(fullfile(idt_root(), 'results', ['NNstatic_' ProblemName '.mat']), 'out', 'S', 'P');
fprintf('Saved results/NNstatic_%s.mat\n', ProblemName);
