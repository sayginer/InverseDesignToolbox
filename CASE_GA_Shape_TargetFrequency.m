%% CASE_GA_Shape_TargetFrequency  -  shape optimization: place holes and rectangles to reach a given f1.
%
%  Case study = saved simulation parameters + the shape optimizer + figures. The design is NOT a brick layout: it is a fixed number
%  of through-thickness cutters (holes and rectangles) that are subtracted from the design part. A genetic algorithm searches
%  their positions, sizes and angles with the real eigenfrequency analysis. The final design is checked with the exact CAD cut
%  and exported as a smooth STL (round holes stay round).
%
%  Details: docs/08_shape_cutters.md.
%  Steps:  1. load the problem   2. cutter design space   3. goal and optimizer options   4. optimize   5. report
%          6. figures   7. exact check (CAD cut + new mesh) and STL file   8. save
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

%% 1. LOAD THE PROBLEM  (the parameters saved by SIM_HarmonicMotion.m)
ProblemName = 'VibrationIsolator';
P = idt_load_params(ProblemName);

% Changes for the shape run:
P.Design.Type = 'none';                      % NO bricks: the design is the cutter list. P.Design.Part is the part that is cut.
P.Analysis.Transmissibility = false;         % not needed for the search: every analysis is faster

model = idt_build_model(P);

%% 2. CUTTER DESIGN SPACE  (every option is explained in functions/shape/idt_shape_options.m)
C = struct();
C.NumHoles      = 3;                         % round holes:  x, y, radius each
C.NumRects      = 2;                         % rectangles:   x, y, width, height, angle each
C.Region        = [];                        % [xmin xmax ymin ymax] where cutter centers may lie [m]; [] = bounding box of the design part
C.HoleRadius    = [];                        % [rmin rmax] [m]; a hole smaller than rmin is switched off; [] = [Hmax, 15 % of the part size]
C.RectSize      = [];                        % [smin smax] [m] for width and height, same rule;          [] = [2 x Hmax, 50 % of the part size]
C.AllowRotation = true;                      % false = rectangles stay axis-aligned
C.MinWall       = 2e-3;                      % [m] thinnest wall the cutters may leave (about two nozzle widths); 0 = no rule. Violations are penalized
C.Margin        = [];                      % [m] cutters closer than this to supports, load or outputs are switched off; [] = Hmax

[smodel, S] = idt_shape_setup(model, C);     % prints the design space

%% 3. GOAL AND OPTIMIZER OPTIONS  (every option is explained in optimizers/shape/shape_options.m)
H = struct();
H.Objective   = 'TargetF1';        % 'TargetF1' = hit a natural frequency | 'MaximizeF1' = highest f1 for VolMax
H.TargetF1    = 200;               % goal for the first natural frequency [Hz]  ('TargetF1'); the uncut part has about 302 Hz
H.VolMax      = [];                % largest fraction of the design part that may remain, 0..1 (needed for 'MaximizeF1')
H.PopSize     = 40;                % designs per generation (each one is a real analysis)
H.Generations = 40;                % maximum number of generations
H.StallGenerations = 10;           % stop when the best cost has not improved for this many generations
H.FreqTol     = 0.3;               % 'TargetF1': stop as soon as |f1 - target| < this [Hz]
H.EliteCount  = 2;                 % best designs copied unchanged into the next generation
H.UseParallel = true;              % evaluate the population in parallel (Parallel Computing Toolbox)
H.Seed        = 1;                 % random seed of the starting population

%% 4. OPTIMIZE  (evolve the cutter numbers; every design is a real analysis on the fixed mesh)
out = shape_optimize(smodel, S, H);
met = out.met;

%% 5. REPORT
fprintf('\n---------------- SHAPE OPTIMIZATION RESULT ----------------\n');
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
fprintf('  f1 / f2                : %.2f / %.2f Hz\n', met.f1, met.f2);
if strcmp(H.Objective, 'TargetF1'), fprintf('  target f1              : %.2f Hz\n', H.TargetF1); end
fprintf('  mass                   : %.2f g\n', met.Mass * 1e3);
fprintf('-----------------------------------------------------------\n');

%% 6. FIGURES
genetic_plot_history(out);                                  % best and mean cost per generation
idt_plot_cutters(smodel, S, out.cut);                       % the cutters on the part
idt_plot_analysis(smodel, out.X, out.res, 'Design', false, 'Transmissibility', false);   % response, modes

%% 7. EXACT CHECK AND STL  (real CAD cut, new mesh that follows the hole edges, closed STL for printing)
geom2 = idt_cutters_geometry(model, out.cut);               % subtract the cutters from the CAD part
[vmodel, vres, vmet] = idt_cutters_verify(model, geom2);    % mesh the cut CAD and analyse it again
fprintf('\n  f1 on the optimization mesh : %.2f Hz\n', met.f1);
fprintf('  f1 on the exact cut CAD     : %.2f Hz  (%.2f %% difference)\n', vmet.f1, 100 * (vmet.f1 - met.f1) / met.f1);
stl = idt_cutters_export_stl(geom2, ['shape_design_' ProblemName]);      % results/shape_design_<ProblemName>.stl, in mm

%% 8. SAVE
if ~isfolder(fullfile(idt_root(), 'results')), mkdir(fullfile(idt_root(), 'results')); end
save(fullfile(idt_root(), 'results', ['SHAPE_' ProblemName '.mat']), 'out', 'H', 'C', 'P', 'vmet');
fprintf('Saved results/SHAPE_%s.mat\n', ProblemName);
