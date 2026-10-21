%% CASE_GA_Isolator  -  vibration isolator: find the brick layout that blocks a frequency band.
%
%  Case study = saved simulation parameters + the genetic-algorithm optimizer + figures. The GOAL is isolation: the clamped
%  base moves, and the protected output point (the sensor on the holder) must move as little as possible inside a frequency
%  band. The measure is the transmissibility T = |response of the output / motion of the base|. T < 1 means the vibration is
%  reduced, T > 1 means it is amplified. The optimizer minimizes the LARGEST T inside the band, so every resonance in the band
%  counts (not only the first one). Details: docs/09_isolator.md.
%
%  Optional FLAT PASSBAND (H.Isolation.Pass): below the stop band the response should follow the base (T = 1, no resonance peak),
%  within +-PassTol dB. Flat below a corner AND isolating above it is a low-pass behaviour: it needs strong damping (P.Analysis.Zeta)
%  and several modes working together; a single resonance cannot do it (docs/09_isolator.md).
%
%  A frequency target on f1 alone does NOT make an isolator: a second mode inside the band puts a peak above 1 there.
%
%  Steps:  1. load the problem   2. isolation goal and options   3. optimize   4. report   5. figures
%          6. manufacturable shape: preview + STL file   7. save
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

%% 1. LOAD THE PROBLEM  (the parameters saved by SIM_HarmonicMotion.m)
ProblemName = 'VibrationIsolator';
P = idt_load_params(ProblemName);

% Changes for the isolator run:
P.Design.Density = 30;                       % bigger bricks = fewer variables (402 bricks)
P.Analysis.Transmissibility = true;          % REQUIRED for this goal (also switched on automatically)
P.Analysis.FreqStart = 2;                    % the sweep must contain the band below
P.Analysis.FreqEnd   = 500;                  % [Hz] end of the sweep; the band may end here at most
P.Analysis.NModes    = 12;                   % modes kept: the highest should be above 1.5 x FreqEnd, or the high-frequency T is not reliable
P.Analysis.Zeta      = 0.05;                 % modal damping ratio: ASSUMED, measure it for your material. Resonance peaks are about 1/(2 Zeta):
                                             % 0.05 -> 10x, 0.3 -> 1.7x. A flat passband needs a high value (see docs/09_isolator.md)

model = idt_build_model(P);

%% 2. ISOLATION GOAL AND OPTIONS  (explained in functions/analysis/idt_isolation_options.m and optimizers/genetic/genetic_options.m)
H = struct();
H.Objective = 'MinTransmissibility';         % ISOLATOR: the smallest peak transmissibility inside the band
H.Isolation.Band    = [100 500];             % [f_low f_high] Hz that must be blocked
H.Isolation.Output  = 1;                     % protected output point(s): 1 = holder centre, 2 = second point, 'all' = worst of all
H.Isolation.Pairs   = [3 3];                 % [response base] directions, 1 x, 2 y, 3 z: [3 3] = vertical base motion -> vertical response
                                             % [3 3; 1 1; 2 2] would block vertical AND both lateral directions
H.Isolation.Pass    = [2 60];               % FLAT PASSBAND [f_low f_high] Hz: T should stay near 1 here (no resonance peak); [] = no passband rule
H.Isolation.PassTol = 3;                    % allowed deviation of 20*log10(T) in the passband [dB] (3 dB = T between 0.71 and 1.41)
                                             % between Pass(2) and Band(1) the response is free (the transition from passing to blocking)
H.Isolation.TargetT = 0.5;                   % stop as soon as the peak T in the band is below this (0.1 = -20 dB); [] = never stop early
H.VolMax      = [];                          % optional: largest volume fraction of the design domain, 0..1
H.PopSize     = 60;                          % individuals per generation (each one is a real analysis)
H.Generations = 40;                          % maximum number of generations
H.StallGenerations = 12;                     % stop when the best cost has not improved for this many generations
H.EliteCount  = 3;                           % best individuals copied unchanged into the next generation
H.CrossoverFraction = 0.8;                   % fraction of children made by two-point crossover
H.MutationRate = 0.004;                      % probability that a brick flips
H.VolFracRange = [0.05 0.45];                % volume fraction of the random starting layouts
H.FieldRadius  = 6e-3;                       % smoothness of the random starting layouts [m]
H.UseParallel  = true;                       % evaluate the population in parallel (Parallel Computing Toolbox)
H.Seed         = 1;                          % random seed of the starting population
% PRINTABILITY: every individual is cleaned (no checkerboards / islands / thin features) and the answer is polished.
H.Clean  = struct('MinWidth', 2, 'CloseGaps', 2, 'Overhang', false, 'KeepOnly', 'loadpath');
H.Polish = struct('MaxSteps', 8, 'Tol', 0.5);       % brick-by-brick fine tuning of the peak T with the real analysis; [] = off

%% 3. OPTIMIZE  (evolve the layouts; every individual is cleaned and analysed with transmissibility)
out = genetic_optimize(model, H);
met = out.met;  res = out.res;  I = out.H.Isolation;

%% 4. REPORT
fprintf('\n---------------- ISOLATOR RESULT ----------------\n');
fprintf('  real FEA analyses used : %d  (%d generations), total time %.0f s\n', out.NumEvaluations, out.Generations, out.TotalTime);
fprintf('  design bricks kept     : %d of %d\n', nnz(out.X), model.NumVars);
fprintf('  band to block          : %g - %g Hz\n', I.Band);
if ~isempty(I.Pass)
    fprintf('  PASSBAND %g - %g Hz     : largest deviation from T = 1 is %.1f dB (allowed %.1f dB)   [%s]\n', I.Pass, out.PassDev, I.PassTol, ...
        ternary(out.PassDev <= I.PassTol, 'flat: OK', 'NOT flat'));
end
fprintf('  PEAK T IN THE BAND     : %.3g  (%.1f dB)  at %.0f Hz   [%s]\n', out.PeakT, 20 * log10(out.PeakT), out.Isolation.Worst.PeakFreq, ...
    ternary(out.PeakT < 1, 'isolates: the whole band is reduced', 'NOT isolating: T > 1 somewhere in the band'));
disp(out.Isolation.Table);
fprintf('  f1 / f2                : %.2f / %.2f Hz\n', met.f1, met.f2);
fprintf('  mass                   : %.2f g\n', met.Mass * 1e3);
fprintf('  floating elements      : %d\n', met.Dropped);
fprintf('  modal coverage         : %.1fx   (want > 1.5; below that the T at the top of the band is not reliable)\n', res.ModalCoverage);
fprintf('-------------------------------------------------\n');

%% 5. FIGURES
genetic_plot_history(out);                                       % best and mean cost per generation
idt_plot_brick_selection(model.Geom, model.Bricks, out.M);       % the layout as clean bricks
idt_plot_isolation(res, I, sprintf('zeta %.2f, ', P.Analysis.Zeta));                                      % transmissibility with the band marked
idt_plot_analysis(model, out.X, res, 'Design', false, 'Transmissibility', false);   % force response, modes

%% 6. MANUFACTURABLE SHAPE: preview and STL file  (the part you print; checked for a closed surface)
stl = idt_export_stl(model, out.X, ['isolator_design_' ProblemName]);    % results/isolator_design_<ProblemName>.stl, in mm

%% 7. SAVE
if ~isfolder(fullfile(idt_root(), 'results')), mkdir(fullfile(idt_root(), 'results')); end
save(fullfile(idt_root(), 'results', ['ISO_' ProblemName '.mat']), 'out', 'H', 'P');
fprintf('Saved results/ISO_%s.mat\n', ProblemName);

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
