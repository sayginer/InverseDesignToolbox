%% CASE_GA_Isolator_Damper  -  isolator whose DAMPING comes from the geometry: structure + damper material, placed by a GA.
%
%  Same goal as CASE_GA_Isolator.m (flat response below a corner, isolation above it, measured by the transmissibility T of the protected
%  output), but the damping is no longer one fixed number for the whole part. Every brick of the design frame is VOID, STRUCTURE (stiff,
%  low loss) or DAMPER (soft, high loss); the GA chooses (two bits per brick). Void is needed: slender flexures are what make a low f1.
%  Each mode is damped according to how much of its strain energy sits in the lossy material (modal strain energy method, core/solve_frf.m), so the GA can
%  put the damper exactly where the troublesome resonance bends the part. Details: docs/10_damping_geometry.md.
%
%  PRINTING: two files are written, the structure and the damper, for a multi-material printer (two TPU grades, or TPU + a damping insert).
%
%  IMPORTANT: the loss factors and the damper stiffness below are ASSUMED values. Replace them by measured data (DMA: E' and tan delta of your
%  materials at the frequencies of interest). The result depends strongly on them.
%
%  Steps:  1. load the problem + materials   2. isolation goal and options   3. optimize   4. report   5. figures
%          6. manufacturable shapes (structure + damper STL)   7. save
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

%% 1. LOAD THE PROBLEM AND DEFINE THE TWO GRADES  (parameters saved by SIM_HarmonicMotion.m)
ProblemName = 'VibrationIsolator';
P = idt_load_params(ProblemName);

P.Design.Density = 30;                       % bigger bricks = fewer variables (402 bricks)
P.Analysis.Transmissibility = true;          % REQUIRED for the isolator goal
P.Analysis.FreqStart = 2;                    % the sweep must contain the band and the passband below
P.Analysis.FreqEnd   = 500;
P.Analysis.NModes    = 12;                   % highest mode should be above 1.5 x FreqEnd (see "modal coverage" in the report)
P.Analysis.Zeta      = 0.05;                 % damping of any material WITHOUT a loss factor (2 x Zeta = its loss factor)

% STRUCTURAL grade = the material of the design part from the saved parameters. Give all parts a loss factor eta = tan(delta).
% eta = 0.10 corresponds to zeta = 0.05 (zeta = eta / 2), the value of the single-material runs.
for i = 1:numel(P.Geometry.Materials)
    P.Geometry.Materials{i}.LossFactor = 0.10;
end
% DAMPER grade: soft and lossy. ASSUMED: ten times softer than the structure, loss factor 0.5. Same Poisson ratio as the structure.
P.Design.Damper = struct('Name', 'Damper TPU', 'E', 5e6, 'nu', 0.45, 'rho', 1100, 'LossFactor', 0.50);

model = idt_build_model(P);                  % prints the damper / structure ratios

%% 2. ISOLATION GOAL AND OPTIONS  (explained in functions/analysis/idt_isolation_options.m and optimizers/genetic/genetic_options.m)
H = struct();
H.Objective = 'MinTransmissibility';         % ISOLATOR: smallest peak transmissibility in the stop band (+ flat passband)
H.Isolation.Band     = [100 500];            % stop band [f_low f_high] Hz: T should be small here
H.Isolation.Pass     = [2 60];               % flat passband Hz: T should stay near 1 here (no resonance peak); [] = no passband rule
H.Isolation.PassTol  = 3;                    % allowed deviation of 20*log10(T) in the passband [dB]
H.Isolation.PassWeight = 1;                  % cost of 1 dB passband violation relative to 1 dB less isolation
H.Isolation.Output   = 1;                    % protected output point: 1 = holder centre, 'all' = worst of all
H.Isolation.Pairs    = [3 3];                % [response base] directions, 1 x, 2 y, 3 z: [3 3] = vertical
H.VolMax      = [];                          % not used here
H.PopSize     = 60;                          % individuals per generation (each one is a real analysis)
H.Generations = 40;                          % maximum number of generations
H.StallGenerations = 12;                     % stop when the best cost has not improved for this many generations
H.EliteCount  = 3;
H.CrossoverFraction = 0.8;
H.MutationRate = 0.004;
H.VolFracRange = [0.05 0.45];                % share of bricks that are present (structure or damper) in the random starting layouts
H.DamperFracRange = [0.1 0.5];               % share of the present bricks that are damper in the random starting layouts
H.FieldRadius  = 6e-3;
H.UseParallel  = true;
H.Seed         = 1;
% PRINTABILITY: the present bricks (structure + damper) are cleaned: no checkerboards, islands or thin features, one connected piece.
H.Clean  = struct('MinWidth', 2, 'CloseGaps', 2, 'Overhang', false, 'KeepOnly', 'loadpath');
H.Polish = [];                              % polish is not available for three-state designs (it toggles structure bricks only)

%% 3. OPTIMIZE  (every individual is cleaned and analysed with transmissibility and per-mode damping)
out = genetic_optimize(model, H);
met = out.met;  res = out.res;  I = out.H.Isolation;

%% 4. REPORT
fprintf('\n---------------- DAMPED ISOLATOR RESULT ----------------\n');
fprintf('  real FEA analyses used : %d  (%d generations), total time %.0f s\n', out.NumEvaluations, out.Generations, out.TotalTime);
fprintf('  bricks                 : %d structure + %d damper + %d void  (of %d)\n', nnz(out.X == 1), nnz(out.X == 2), nnz(out.X == 0), model.NumVars);
fprintf('  STOP BAND %g - %g Hz  : peak T %.3g  (%.1f dB) at %.0f Hz\n', I.Band, out.PeakT, 20 * log10(out.PeakT), out.Isolation.Worst.PeakFreq);
fprintf('  PASSBAND  %g - %g Hz   : largest deviation from T = 1 is %.1f dB (allowed %.1f dB)   [%s]\n', I.Pass, out.PassDev, I.PassTol, ...
    ternary(out.PassDev <= I.PassTol, 'flat: OK', 'NOT flat'));
fprintf('  f1 / f2                : %.2f / %.2f Hz\n', met.f1, met.f2);
fprintf('  damping ratio of modes 1-4 (from the geometry): %s\n', sprintf('%.3f  ', res.ZetaModes(1:min(4, end))));
fprintf('  mass                   : %.2f g\n', met.Mass * 1e3);
fprintf('  modal coverage         : %.1fx   (want > 1.5)\n', res.ModalCoverage);
fprintf('--------------------------------------------------------\n');

%% 5. FIGURES
genetic_plot_history(out);                                       % best and mean cost per generation
idt_plot_brick_selection(model.Geom, model.Bricks, out.M);       % blue = structure, orange = damper, ghost = void
idt_plot_isolation(res, I, 'damper geometry, ');                 % transmissibility with stop band and passband marked
idt_plot_analysis(model, out.X, res, 'Design', false, 'Transmissibility', false);   % force response, modes

%% 6. MANUFACTURABLE SHAPES: two STL files for a multi-material print
stlStruct = idt_export_stl(model, out.X == 1, ['isolator_damper_structure_' ProblemName]);                  % assembly with void and damper bricks cut out
if any(out.X == 2)
    stlDamper = idt_export_stl(model, out.X == 2, ['isolator_damper_material_' ProblemName], struct('Content', 'bricks'));   % only the damper bricks
end

%% 7. SAVE
if ~isfolder(fullfile(idt_root(), 'results')), mkdir(fullfile(idt_root(), 'results')); end
save(fullfile(idt_root(), 'results', ['ISODAMP_' ProblemName '.mat']), 'out', 'H', 'P');
fprintf('Saved results/ISODAMP_%s.mat\n', ProblemName);

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
