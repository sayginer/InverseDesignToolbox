%% CASE_GA_StaticBeam  -  genetic-algorithm optimization of the cantilever beam under a static load.
%
%  Case study = saved simulation parameters (SIM_StaticLoad.m) + the static genetic algorithm + figures.
%  Same problem as CASE_SIMP_StaticBeam.m, so the two methods can be compared. Two goals:
%     'MinCompliance'  stiffest layout for at most VolMax of the design volume
%     'MinMass'        lightest layout whose tip deflection stays below MaxDeflection
%  Every individual costs one real static analysis. Method and options: docs/11_static_optimization.md.
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
S.Objective     = 'MinCompliance';   % 'MinCompliance' | 'MinMass'
S.VolMax        = 0.5;               % 'MinCompliance': at most 50 % of the design-brick volume
S.MaxDeflection = 2 * abs(m0.OutDefl(1, 3));   % 'MinMass': tip may move at most twice as much as the full beam [m]
S.PopSize       = 60;                % individuals per generation (each one is a real analysis)
S.Generations   = 40;
S.StallGenerations = 12;
S.MutationRate  = 0.01;
S.UseParallel   = true;
S.Seed          = 1;
S.Clean         = [];                % [] = no printability clean-up

%% 3. OPTIMIZE
out = static_ga_optimize(model, S);
met = out.met;

%% 4. REPORT
fprintf('\n---------------- GENETIC ALGORITHM RESULT ----------------\n');
fprintf('  analyses used          : %d  (%d generations), total time %.0f s\n', out.NumEvaluations, out.Generations, out.TotalTime);
fprintf('  design bricks kept     : %d of %d\n', nnz(out.X), model.NumVars);
fprintf('  tip deflection         : %.2f um   (full beam %.2f um)\n', abs(met.OutDefl(1, 3)) * 1e6, abs(m0.OutDefl(1, 3)) * 1e6);
fprintf('  compliance             : %.4g mJ   (full beam %.4g mJ)\n', met.Compliance * 1e3, m0.Compliance * 1e3);
fprintf('  mass                   : %.1f g    (full beam %.1f g)\n', met.Mass * 1e3, m0.Mass * 1e3);
fprintf('  max von Mises          : %.1f MPa  (full beam %.1f MPa)\n', met.MaxVonMises * 1e-6, m0.MaxVonMises * 1e-6);
fprintf('  floating elements      : %d\n', met.Dropped);
fprintf('----------------------------------------------------------\n');

%% 5. FIGURES
static_plot_history(out);                                        % best and mean cost per generation
idt_plot_brick_selection(model.Geom, model.Bricks, out.M);       % the layout as clean bricks
idt_plot_static(model, out.X, out.res);                          % deformed shape and stress

%% 6. SAVE
if ~isfolder(fullfile(idt_root(), 'results')), mkdir(fullfile(idt_root(), 'results')); end
save(fullfile(idt_root(), 'results', ['GAstatic_' ProblemName '.mat']), 'out', 'S', 'P');
fprintf('Saved results/GAstatic_%s.mat\n', ProblemName);
