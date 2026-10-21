%% CASE_GA_Shape_StaticBeam  -  shape optimization of the cantilever: place holes and rectangles for the stiffest / lightest beam.
%
%  Case study = saved simulation parameters (SIM_StaticLoad.m) + the shape optimizer + figures. The design is NOT a brick layout: it is
%  a fixed number of through-thickness cutters (holes and rectangles) subtracted from the design frame. A genetic algorithm searches
%  their positions, sizes and angles with the real static analysis. The final design is checked with the exact CAD cut and exported
%  as a smooth STL.
%
%  The shape module cuts through z, so the beam is rotated by -90 degrees about x on import (thickness along z, beam height along y);
%  the load direction and the output points are rotated with it. The face numbers do not change.
%
%  Goals:  'MinCompliance'  stiffest design that keeps at most VolMax of the design frame
%          'MinMass'        lightest design whose tip deflection stays below MaxDeflection
%  Details: docs/08_shape_cutters.md, docs/11_static_optimization.md.
%  Steps:  1. load the problem   2. cutter design space   3. goal and optimizer options   4. optimize   5. report
%          6. figures   7. exact check (CAD cut + new mesh) and STL file   8. save
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

%% 1. LOAD THE PROBLEM  (the parameters saved by SIM_StaticLoad.m)
ProblemName = 'CantileverBeam';
P = idt_load_params(ProblemName);

% Changes for the shape run:
P.Geometry.Rotate  = [-90 1 0 0];            % thickness along z: (x, y, z) -> (x, z, -y)
P.BC.LoadDirection = [0 -1 0];               % "down" is now -y
P.BC.OutPoints     = [75e-3 0 -5e-3; ...     % output 1 = the tip
                      0 -25e-3 -5e-3];       % output 2 = middle of the lower flange
P.Design.Type  = 'none';                     % NO bricks: the design is the cutter list. P.Design.Part is the part that is cut.
P.Mesh.Hmax    = 2.5e-3;
P.Mesh.Order   = 'linear';                   % fast; the exact check in step 7 uses the same settings

model = idt_build_model(P);
[~, m0] = idt_analyze(model);                % the uncut beam

%% 2. CUTTER DESIGN SPACE  (every option is explained in functions/shape/idt_shape_options.m)
C = struct();
C.NumHoles      = 3;                         % round holes:  x, y, radius each
C.NumRects      = 2;                         % rectangles:   x, y, width, height, angle each
C.Region        = [];                        % [xmin xmax ymin ymax] where cutter centers may lie [m]; [] = bounding box of the design part
C.HoleRadius    = [];                        % [rmin rmax] [m]; [] = [Hmax, 15 % of the part size]
C.RectSize      = [];                        % [smin smax] [m] for width and height; [] = [2 x Hmax, 50 % of the part size]
C.AllowRotation = true;                      % false = rectangles stay axis-aligned
C.MinWall       = 2e-3;                      % [m] thinnest wall the cutters may leave; 0 = no rule. Violations are penalized
C.Margin        = [];                        % [m] cutters closer than this to supports, load or outputs are switched off; [] = Hmax

[smodel, S] = idt_shape_setup(model, C);     % prints the design space

%% 3. GOAL AND OPTIMIZER OPTIONS  (every option is explained in optimizers/shape/shape_options.m)
H = struct();
H.Objective     = 'MinCompliance';           % 'MinCompliance' | 'MinMass'
H.VolMax        = 0.85;                      % 'MinCompliance': at most 85 % of the design frame may remain (5 small cutters cannot remove much more)
H.MaxDeflection = 2 * abs(m0.OutDefl(1, 2)); % 'MinMass': the tip may move at most twice as much as the uncut beam [m]
H.PopSize       = 40;                        % designs per generation (each one is a real analysis)
H.Generations   = 40;
H.StallGenerations = 10;
H.EliteCount    = 2;
H.UseParallel   = true;
H.Seed          = 1;

%% 4. OPTIMIZE  (evolve the cutter numbers; every design is a real analysis on the fixed mesh)
out = shape_optimize(smodel, S, H);
met = out.met;

%% 5. REPORT
fprintf('\n---------------- SHAPE OPTIMIZATION RESULT ----------------\n');
fprintf('  analyses used          : %d  (%d generations), total time %.0f s\n', out.NumEvaluations, out.Generations, out.TotalTime);
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
fprintf('  tip deflection         : %.2f um   (uncut beam %.2f um)\n', abs(met.OutDefl(1, 2)) * 1e6, abs(m0.OutDefl(1, 2)) * 1e6);
fprintf('  compliance             : %.4g mJ   (uncut beam %.4g mJ)\n', met.Compliance * 1e3, m0.Compliance * 1e3);
fprintf('  mass                   : %.1f g    (uncut beam %.1f g)\n', met.Mass * 1e3, m0.Mass * 1e3);
fprintf('  max von Mises          : %.1f MPa  (uncut beam %.1f MPa)\n', met.MaxVonMises * 1e-6, m0.MaxVonMises * 1e-6);
fprintf('-----------------------------------------------------------\n');

%% 6. FIGURES
genetic_plot_history(out);                                  % best and mean cost per generation
idt_plot_cutters(smodel, S, out.cut);                       % the cutters on the part
idt_plot_static(smodel, out.X, out.res);                    % deformed shape and stress

%% 7. EXACT CHECK AND STL  (real CAD cut, new mesh that follows the hole edges, closed STL for printing)
geom2 = idt_cutters_geometry(model, out.cut);               % subtract the cutters from the CAD part
[vmodel, vres, vmet] = idt_cutters_verify(model, geom2);    % mesh the cut CAD and analyse it again
fprintf('\n  compliance on the optimization mesh : %.4g mJ\n', met.Compliance * 1e3);
fprintf('  compliance on the exact cut CAD     : %.4g mJ  (%.2f %% difference)\n', vmet.Compliance * 1e3, 100 * (vmet.Compliance - met.Compliance) / met.Compliance);
stl = idt_cutters_export_stl(geom2, ['shape_design_' ProblemName]);      % results/shape_design_<ProblemName>.stl, in mm

%% 8. SAVE
if ~isfolder(fullfile(idt_root(), 'results')), mkdir(fullfile(idt_root(), 'results')); end
save(fullfile(idt_root(), 'results', ['SHAPEstatic_' ProblemName '.mat']), 'out', 'H', 'C', 'P', 'vmet');
fprintf('Saved results/SHAPEstatic_%s.mat\n', ProblemName);
