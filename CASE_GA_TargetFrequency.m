%% CASE_GA_TargetFrequency  -  genetic-algorithm optimization: find the brick layout with a given f1.
%
%  Case study = saved simulation parameters + the genetic-algorithm optimizer + figures. Same problem, same goal and
%  same printability clean-up as CASE_SIMP_TargetFrequency.m and CASE_NN_TargetFrequency.m, so the three methods can be
%  compared directly.
%
%  What it does (details in docs/07_genetic_algorithm.md): a population of brick layouts evolves by selection, crossover
%  and mutation (ga). Every individual is made printable and judged with the REAL analysis, in parallel. No gradients
%  and no network, but every individual costs one finite-element analysis.
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

% Changes for the optimization run (the same ones as in the SIMP and neural-network case studies):
P.Design.Density = 30;                       % bigger bricks = fewer variables (402 bricks)
P.Analysis.Transmissibility = false;         % not needed for the search: every analysis is faster

model = idt_build_model(P);

%% 2. GOAL AND OPTIONS  (every option is explained in optimizers/genetic/genetic_options.m)
H = struct();
H.Objective    = 'TargetF1';       % 'TargetF1' = hit a natural frequency | 'MaximizeF1' = highest f1 for VolMax
H.TargetF1     = 100;              % goal for the first natural frequency [Hz]  ('TargetF1')
H.VolMax       = [];               % largest volume fraction of the design domain, 0..1 (needed for 'MaximizeF1')
H.PopSize      = 60;               % individuals per generation (each one is a real analysis)
H.Generations  = 40;               % maximum number of generations
H.StallGenerations = 12;           % stop when the best cost has not improved for this many generations
H.FreqTol      = 0.3;              % 'TargetF1': stop as soon as |f1 - target| < this [Hz]
H.EliteCount   = 3;                % best individuals copied unchanged into the next generation
H.CrossoverFraction = 0.8;         % fraction of children made by two-point crossover (swaps blocks of bricks)
H.MutationRate = 0.004;            % probability that a brick flips (about 1.6 flips per child)
H.VolFracRange = [0.05 0.45];      % volume fraction of the random starting layouts
H.FieldRadius  = 6e-3;             % smoothness of the random starting layouts [m]
H.UseParallel  = true;             % evaluate the population in parallel (Parallel Computing Toolbox)
H.Seed         = 1;                % random seed of the starting population
% PRINTABILITY: every individual is cleaned (no checkerboards / islands / thin features) and the answer is polished.
H.Clean        = struct('MinWidth', 2, ...        % smallest feature width in bricks
                        'CloseGaps', 2, ...       % one-brick gaps and holes are filled
                        'Overhang', false, ...    % true = remove bricks without support below (print bottom-up)
                        'KeepOnly', 'loadpath');  % keep only groups joining supports and load ('attached' | 'all')
H.Polish       = struct('MaxSteps', 12, 'Tol', 0.5);   % brick-by-brick fine tuning with the real analysis; [] = off

%% 3. OPTIMIZE  (evolve the population; every individual is cleaned and analysed)
out = genetic_optimize(model, H);
met = out.met;

%% 4. REPORT
fprintf('\n---------------- GENETIC ALGORITHM RESULT ----------------\n');
fprintf('  real FEA analyses used : %d  (%d generations), total time %.0f s\n', out.NumEvaluations, out.Generations, out.TotalTime);
fprintf('  design bricks kept     : %d of %d\n', nnz(out.X), model.NumVars);
fprintf('  f1 / f2                : %.2f / %.2f Hz\n', met.f1, met.f2);
if strcmp(H.Objective, 'TargetF1'), fprintf('  target f1              : %.2f Hz\n', H.TargetF1); end
fprintf('  mass                   : %.2f g\n', met.Mass * 1e3);
fprintf('  floating elements      : %d\n', met.Dropped);
fprintf('----------------------------------------------------------\n');

%% 5. FIGURES
genetic_plot_history(out);                                       % best and mean cost per generation
idt_plot_brick_selection(model.Geom, model.Bricks, out.M);       % the layout as clean bricks
idt_plot_analysis(model, out.X, out.res, 'Design', true, 'Transmissibility', false);   % response, modes

%% 6. MANUFACTURABLE SHAPE: preview and STL file  (the part you print; checked for a closed surface)
stl = idt_export_stl(model, out.X, ['ga_design_' ProblemName]);          % results/ga_design_<ProblemName>.stl, in mm

%% 7. SAVE
if ~isfolder(fullfile(idt_root(), 'results')), mkdir(fullfile(idt_root(), 'results')); end
save(fullfile(idt_root(), 'results', ['GA_' ProblemName '.mat']), 'out', 'H', 'P');
fprintf('Saved results/GA_%s.mat\n', ProblemName);
