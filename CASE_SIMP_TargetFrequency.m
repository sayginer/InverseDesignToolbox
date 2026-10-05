%% CASE_SIMP_TargetFrequency  -  topology optimization with SIMP: find the brick layout with a given f1.
%
%  Case study = saved simulation parameters + the SIMP optimizer + figures. No physics code here.
%  The problem comes from the simulation script: run SIM_HarmonicMotion.m once, check the setup, let it
%  save results/<ProblemName>.mat, then optimize exactly that problem.
%
%  What SIMP does (details in docs/03_simp.md): every design brick gets a density between 0 and 1.
%  One eigenvalue solution gives the exact gradient of f1 with respect to ALL densities (adjoint method),
%  and fmincon moves the densities downhill. A filter removes islands / checkerboards and a projection
%  pushes the field to solid / void, so the result can be built from bricks.
%
%  Steps:  1. load the problem   2. choose the goal and options   3. precompute   4. optimize
%          5. post-process (densities -> printable solid bricks, verified by idt_analyze)   6. figures
%          7. manufacturable shape: preview + STL file   8. save
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

%% 1. LOAD THE PROBLEM  (the parameters saved by SIM_HarmonicMotion.m)
ProblemName = 'VibrationIsolator';
P = idt_load_params(ProblemName);

% You may change single parameters for the optimization run. IMPORTANT: SIMP with the default 'sqp'
% solver is slow above about 1000 design bricks, so use big bricks (Density 30 = 402 bricks):
P.Design.Density = 30;             % bigger bricks = fewer variables (keep Hmax <= 0.7 x brick edge)
% P.Analysis.Transmissibility = false;

model = idt_build_model(P);                  % geometry + bricks + BC + mesh + element matrices

%% 2. GOAL AND OPTIONS  (every option is explained in optimizers/topology/simp_options.m)
H = struct();
H.Objective    = 'TargetF1';       % 'TargetF1' = hit a natural frequency | 'MaximizeF1' = highest f1 for VolMax
H.TargetF1     = 100;              % goal for the first natural frequency [Hz]  ('TargetF1')
H.VolMax       = [];               % largest volume fraction of the design domain, 0..1 (needed for 'MaximizeF1')
H.FilterRadius = 'auto';           % density filter radius [m] or 'auto' (= 1.3 x Clean.MinWidth x brick edge = 8 mm here):
                                   % it must match the printable minimum width, larger = thicker, smoother arms
H.VolFracInit  = 0.30;             % starting density of every brick
H.PenalStiff   = 3;                % SIMP penalization p (grey material is "inefficient")
H.RhoMin       = 1e-6;             % stiffness of void: keep tiny, void must not carry load
H.BetaStart    = 1;                % Heaviside projection sharpness: first stage ...
H.BetaMax      = 64;               % ... last stage (higher = closer to solid/void; 1 = projection OFF: grey material)
H.StageIter    = 10;               % fmincon iterations per beta stage (beta doubles between stages)
H.MoveLimit    = 0.3;              % max density change per stage (trust region)
H.Algorithm    = 'sqp';            % fmincon algorithm: 'sqp' | 'interior-point' | 'active-set'
H.Thresholds   = [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9];   % cutoffs tried when making solid bricks
% PRINTABILITY: every candidate layout is cleaned (no checkerboards / islands / thin features) and the answer polished.
H.Clean        = struct('MinWidth', 2, ...        % smallest feature width in bricks
                        'CloseGaps', 2, ...       % one-brick gaps and holes are filled
                        'Overhang', false, ...    % true = remove bricks without support below (print bottom-up)
                        'KeepOnly', 'loadpath');  % keep only groups joining supports and load ('attached' | 'all')
H.Polish       = struct('MaxSteps', 12, 'Tol', 0.5);   % brick-by-brick fine tuning with the real analysis; [] = off
H.LivePlot     = true;             % convergence figure while running

%% 3. PRECOMPUTE  (matrices that do not change between iterations)
H = simp_options(H);               % fills defaults and checks the settings
S = simp_precompute(model, H);     % resolves FilterRadius = 'auto' from H.Clean.MinWidth

%% 4. OPTIMIZE
out = simp_optimize(model, S, H);

%% 5. POST-PROCESS  (densities -> solid bricks, verified with the full analysis)
post = simp_postprocess(model, S, out, H);
met = post.met;

fprintf('\n---------------- SIMP RESULT ----------------\n');
fprintf('  optimizer: %d evaluations, %.1f s\n', out.Iterations, out.TotalTime);
fprintf('  cutoff used            : %.2f (%d of %d design bricks kept)\n', post.Threshold, nnz(post.X), model.NumVars);
fprintf('  f1 / f2                : %.2f / %.2f Hz\n', met.f1, met.f2);
if strcmp(H.Objective, 'TargetF1'), fprintf('  target f1              : %.2f Hz\n', H.TargetF1); end
fprintf('  mass                   : %.2f g\n', met.Mass * 1e3);
fprintf('  floating elements      : %d\n', met.Dropped);
fprintf('---------------------------------------------\n');

%% 6. FIGURES
simp_plot_live(out.History, out.Iterations, H.TargetF1);                 % convergence
simp_plot_density(model, post.rho_b, post.X);                            % densities and solid layers
idt_plot_brick_selection(model.Geom, model.Bricks, post.M);              % the layout as clean bricks
idt_plot_analysis(model, post.X, post.res, 'Design', true);              % response, modes, transmissibility

%% 7. MANUFACTURABLE SHAPE: preview and STL file  (the part you print; checked for a closed surface)
stl = idt_export_stl(model, post.X, ['simp_design_' ProblemName]);       % results/simp_design_<ProblemName>.stl, in mm

%% 8. SAVE
if ~isfolder(fullfile(idt_root(), 'results')), mkdir(fullfile(idt_root(), 'results')); end
save(fullfile(idt_root(), 'results', ['SIMP_' ProblemName '.mat']), 'post', 'out', 'H', 'P');
fprintf('Saved results/SIMP_%s.mat\n', ProblemName);