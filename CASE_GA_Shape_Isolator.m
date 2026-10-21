%% CASE_GA_Shape_Isolator  -  vibration isolator by shape: place holes and rectangles so that a frequency band is blocked.
%
%  Same goal as CASE_GA_Isolator.m (the largest transmissibility T inside a frequency band, T < 1 = vibration reduced), but the
%  design is a set of through-thickness cutters (holes, rectangles) subtracted from the design part instead of a brick layout.
%  The result is smooth and printable (minimum wall rule), checked with the exact CAD cut and exported as an STL.
%  Details: docs/08_shape_cutters.md and docs/09_isolator.md.
%
%  LIMIT (measured, see docs/09_isolator.md): cutters only remove material, so the part stays stiff (f1 about 300 Hz for the example) and\n%  cannot isolate from 100 Hz. This script then reports T > 1; use it only for geometries whose f1 is already low, or as a finishing\n%  step after a brick design. For the example geometry use CASE_GA_Isolator.m.
%
%  Steps:  1. load the problem   2. cutter design space   3. isolation goal and options   4. optimize   5. report
%          6. figures   7. exact check (CAD cut + new mesh) and STL file   8. save
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

%% 1. LOAD THE PROBLEM  (the parameters saved by SIM_HarmonicMotion.m)
ProblemName = 'VibrationIsolator';
P = idt_load_params(ProblemName);

P.Design.Type = 'none';                      % NO bricks: the design is the cutter list. P.Design.Part is the part that is cut.
P.Analysis.Transmissibility = true;          % REQUIRED for this goal (also switched on automatically)
P.Analysis.FreqStart = 2;                    % the sweep must contain the band below
P.Analysis.FreqEnd   = 500;                  % [Hz] end of the sweep; the band may end here at most
P.Analysis.NModes    = 10;                   % highest mode should be above 1.5 x FreqEnd, or the high-frequency T is not reliable
P.Analysis.Zeta      = 0.05;                 % modal damping ratio: ASSUMED, measure it for your material

model = idt_build_model(P);

%% 2. CUTTER DESIGN SPACE  (every option is explained in functions/shape/idt_shape_options.m)
C = struct();
C.NumHoles      = 3;                         % round holes:  x, y, radius each
C.NumRects      = 2;                         % rectangles:   x, y, width, height, angle each
C.Region        = [];                        % [xmin xmax ymin ymax] where cutter centers may lie [m]; [] = bounding box of the design part
C.HoleRadius    = [];                        % [rmin rmax] [m]; a hole smaller than rmin is switched off; [] = [Hmax, 15 % of the part size]
C.RectSize      = [];                        % [smin smax] [m] for width and height, same rule;          [] = [2 x Hmax, 50 % of the part size]
C.AllowRotation = true;                      % false = rectangles stay axis-aligned
C.MinWall       = 2e-3;                      % [m] thinnest wall the cutters may leave (about two nozzle widths); 0 = no rule
C.Margin        = [];                        % [m] cutters closer than this to supports, load or outputs are switched off; [] = Hmax

[smodel, S] = idt_shape_setup(model, C);     % prints the design space

%% 3. ISOLATION GOAL AND OPTIONS  (explained in functions/analysis/idt_isolation_options.m and optimizers/shape/shape_options.m)
H = struct();
H.Objective = 'MinTransmissibility';         % ISOLATOR: the smallest peak transmissibility inside the band
H.Isolation.Band    = [100 500];             % [f_low f_high] Hz that must be blocked
H.Isolation.Output  = 1;                     % protected output point(s): 1 = holder centre, 2 = second point, 'all' = worst of all
H.Isolation.Pairs   = [3 3];                 % [response base] directions, 1 x, 2 y, 3 z: [3 3] = vertical; [3 3; 1 1; 2 2] adds both lateral
H.Isolation.TargetT = 0.5;                   % stop as soon as the peak T in the band is below this (0.1 = -20 dB); [] = never stop early
H.VolMax      = [];                          % optional: largest fraction of the design part that may remain, 0..1
H.PopSize     = 40;                          % designs per generation (each one is a real analysis)
H.Generations = 40;                          % maximum number of generations
H.StallGenerations = 10;                     % stop when the best cost has not improved for this many generations
H.EliteCount  = 2;                           % best designs copied unchanged into the next generation
H.UseParallel = true;                        % evaluate the population in parallel (Parallel Computing Toolbox)
H.Seed        = 1;                           % random seed of the starting population

%% 4. OPTIMIZE  (evolve the cutter numbers; every design is a real analysis with transmissibility)
out = shape_optimize(smodel, S, H);
met = out.met;  res = out.res;  I = out.H.Isolation;

%% 5. REPORT
fprintf('\n---------------- SHAPE ISOLATOR RESULT ----------------\n');
fprintf('  real FEA analyses used : %d  (%d generations), total time %.0f s\n', out.NumEvaluations, out.Generations, out.TotalTime);
fprintf('  active cutters         : %d of %d\n', numel(out.cut), S.NumHoles + S.NumRects);
for k = 1:numel(out.cut)
    c = out.cut(k);
    if strcmp(c.Type, 'hole')
        fprintf('    %d  hole  at (%6.2f, %6.2f) mm, radius %.2f mm\n', k, c.X * 1e3, c.Y * 1e3, c.A * 1e3);
    else
        fprintf('    %d  rect  at (%6.2f, %6.2f) mm, %.2f x %.2f mm, %.0f deg\n', k, c.X * 1e3, c.Y * 1e3, c.A * 1e3, c.B * 1e3, c.AngleDeg);
    end
end
fprintf('  design part left       : %.1f %%\n', 100 * out.VolFrac);
if C.MinWall > 0
    if out.WallOk, fprintf('  minimum wall           : OK, no wall thinner than %.1f mm\n', C.MinWall * 1e3);
    else, fprintf('  minimum wall           : VIOLATED, %.1f mm^2 thinner than %.1f mm (red in the cutter figure)\n', out.Wall.Area * 1e6, C.MinWall * 1e3); end
end
fprintf('  band to block          : %g - %g Hz\n', I.Band);
fprintf('  PEAK T IN THE BAND     : %.3g  (%.1f dB)  at %.0f Hz   [%s]\n', out.PeakT, 20 * log10(out.PeakT), out.Isolation.Worst.PeakFreq, ...
    ternary(out.PeakT < 1, 'isolates: the whole band is reduced', 'NOT isolating: T > 1 somewhere in the band'));
disp(out.Isolation.Table);
fprintf('  f1 / f2                : %.2f / %.2f Hz\n', met.f1, met.f2);
fprintf('  mass                   : %.2f g\n', met.Mass * 1e3);
fprintf('  modal coverage         : %.1fx   (want > 1.5)\n', res.ModalCoverage);
fprintf('-------------------------------------------------------\n');

%% 6. FIGURES
genetic_plot_history(out);                                  % best and mean cost per generation
idt_plot_cutters(smodel, S, out.cut);                       % the cutters on the part
idt_plot_isolation(res, I);                                 % transmissibility with the band marked
idt_plot_analysis(smodel, out.X, res, 'Design', false, 'Transmissibility', false);   % force response, modes

%% 7. EXACT CHECK AND STL  (real CAD cut, new mesh that follows the hole edges, closed STL for printing)
geom2 = idt_cutters_geometry(model, out.cut);               % subtract the cutters from the CAD part
vmodel0 = model;  vmodel0.Params.Analysis.Transmissibility = true;
[vmodel, vres, vmet] = idt_cutters_verify(vmodel0, geom2);  % mesh the cut CAD and analyse it again (with transmissibility)
vPeak = idt_isolation_metric(vres, I);
fprintf('\n  peak T in the band, optimization mesh : %.3g\n', out.PeakT);
fprintf('  peak T in the band, exact cut CAD     : %.3g   (f1 %.2f Hz)\n', vPeak, vmet.f1);
stl = idt_cutters_export_stl(geom2, ['isolator_shape_' ProblemName]);    % results/isolator_shape_<ProblemName>.stl, in mm

%% 8. SAVE
if ~isfolder(fullfile(idt_root(), 'results')), mkdir(fullfile(idt_root(), 'results')); end
save(fullfile(idt_root(), 'results', ['ISOSHAPE_' ProblemName '.mat']), 'out', 'H', 'C', 'P', 'vPeak');
fprintf('Saved results/ISOSHAPE_%s.mat\n', ProblemName);

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
