%% CASE_SIMP_StaticBeam  -  SIMP topology optimization: the stiffest cantilever for a given volume.
%
%  Case study = saved simulation parameters (SIM_StaticLoad.m) + the static SIMP optimizer + figures.
%  Goal: minimize the compliance F'u (= maximize the stiffness) with at most VolMax of the design bricks.
%  Method and options: docs/11_static_optimization.md.
%
%  Steps:  1. load the problem   2. goal and options   3. optimize   4. report   5. figures   6. save
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

%% 1. LOAD THE PROBLEM  (the parameters saved by SIM_StaticLoad.m)
ProblemName = 'CantileverBeam';
P = idt_load_params(ProblemName);

% Changes for the optimization run: a coarser, linear mesh makes every analysis fast.
P.Mesh.Hmax  = 3.0e-3;
P.Mesh.Order = 'linear';

model = idt_build_model(P);

%% 2. GOAL AND OPTIONS  (every option is explained in optimizers/static/static_options.m)
S = struct();
S.Objective    = 'MinCompliance';  % stiffest layout for the volume below
S.VolMax       = 0.5;              % at most 50 % of the design-brick volume
S.Penal        = 3;                % SIMP penalization
S.FilterRadius = [];               % [] = 1.5 x brick edge (no checkerboards)
S.BetaMax      = 8;                % projection sharpness: pushes densities to 0 / 1
S.MaxIter      = 200;
S.Clean        = [];               % [] = no printability clean-up (the beam is only 6 bricks tall)

%% 3. OPTIMIZE
out = static_simp_optimize(model, S);
met = out.met;
[~, m0] = idt_analyze(model);      % the full beam, for comparison

%% 4. REPORT
fprintf('\n---------------- SIMP RESULT ----------------\n');
fprintf('  iterations             : %d  (%.0f s)\n', out.Iterations, out.TotalTime);
fprintf('  design bricks kept     : %d of %d\n', nnz(out.X), model.NumVars);
fprintf('  gray bricks            : %.0f %% (0.1 < density < 0.9, removed or kept by the threshold)\n', 100 * out.Grayness);
fprintf('  tip deflection         : %.2f um   (full beam %.2f um)\n', abs(met.OutDefl(1, 3)) * 1e6, abs(m0.OutDefl(1, 3)) * 1e6);
fprintf('  compliance             : %.4g mJ   (full beam %.4g mJ)\n', met.Compliance * 1e3, m0.Compliance * 1e3);
fprintf('  mass                   : %.1f g    (full beam %.1f g)\n', met.Mass * 1e3, m0.Mass * 1e3);
fprintf('  max von Mises          : %.1f MPa  (full beam %.1f MPa)\n', met.MaxVonMises * 1e-6, m0.MaxVonMises * 1e-6);
fprintf('---------------------------------------------\n');

%% 5. FIGURES
static_plot_history(out);                                        % compliance and volume per iteration
idt_plot_brick_selection(model.Geom, model.Bricks, out.M);       % the layout as clean bricks
idt_plot_static(model, out.X, out.res);                          % deformed shape and stress

%% 6. SAVE
if ~isfolder(fullfile(idt_root(), 'results')), mkdir(fullfile(idt_root(), 'results')); end
save(fullfile(idt_root(), 'results', ['SIMPstatic_' ProblemName '.mat']), 'out', 'S', 'P');
fprintf('Saved results/SIMPstatic_%s.mat\n', ProblemName);
