%% SIM_ShapeCutters  -  step-by-step simulation: place holes and rectangles by hand and see what they do. No optimization.
%
%  The shape optimizer (CASE_GA_Shape_TargetFrequency.m) searches cutters; this script lets you place them yourself, look at
%  them, simulate them, and export the result, using exactly the same functions. Work through the numbered steps in order
%  (Ctrl+Enter runs one step, F5 the whole script). Every step shows its own figure.
%
%     1. load the problem + build the model   (the parameters saved by SIM_HarmonicMotion.m)
%     2. the cutter design space              -> prints the numbers an optimizer would search
%     3. place the cutters by hand            -> figure: exact cutter outlines on the analysis mesh
%     4. simulate (fast: mesh elements inside the cutters are removed)  -> eigenfrequencies + harmonic response
%     5. plot the results
%     6. exact check: CAD cut + new mesh      -> f1 on the real cut geometry
%     7. save the STL                         -> preview + closed-surface check
%
%  UNITS: meters (1e-3 = 1 mm), angles in degrees.   Details: docs/08_shape_cutters.md
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

%% 1. LOAD THE PROBLEM AND BUILD THE MODEL  (check: parts, supports, mesh as in SIM_HarmonicMotion)
ProblemName = 'VibrationIsolator';             % results/<ProblemName>.mat, saved by SIM_HarmonicMotion.m
P = idt_load_params(ProblemName);

P.Design.Type = 'none';                        % no bricks: the design is the cutter list. P.Design.Part = the part that is cut.
% P.Design.Part = 2;                           % which part gets the cutters (here: the design frame)
% P.Mesh.Hmax   = 2.0e-3;                      % element size: a cutter should span several elements (see step 2)
P.Analysis.Transmissibility = true;            % also compute the base-excitation transmissibility

model = idt_build_model(P);
plot_geometry(model.Geom);                     % check the parts and their face numbers


%% 2. THE CUTTER DESIGN SPACE  (what the optimizer may place; here it also gives the limits used in step 3)
C = struct();
C.NumHoles   = 3;                              % how many holes an optimizer would use (x, y, radius each)
C.NumRects   = 2;                              % how many rectangles (x, y, width, height, angle each)
C.Region     = [];                             % [xmin xmax ymin ymax]: where centers may be; [] = bounding box of the design part
C.HoleRadius = [];                             % [rmin rmax]: smaller than rmin = off;  [] = [Hmax, 15 % of the part size]
C.RectSize   = [];                             % [smin smax] for width and height;      [] = [2 x Hmax, 50 % of the part size]
C.MinWall    = 2e-3;                           % [m] thinnest wall your printer can make; thinner walls are marked red in step 3
C.Margin     = [];                           % cutters closer than this to supports, load or outputs are dropped; [] = Hmax

[smodel, S] = idt_shape_setup(model, C);       % prints the design space; smodel = model for cutter designs


%% 3. PLACE THE CUTTERS BY HAND  (check: the black outlines are where you want them, nothing sits on the supports or outputs)
% idt_cutter('hole', x, y, radius)                    round hole
% idt_cutter('rect', x, y, width, height, angleDeg)   rectangle, rotated counter-clockwise about its center
% All numbers in meters; (0, 0) is the center of the part. The cutters go through the full thickness.
cut = [ idt_cutter('hole', -14e-3,   0,     3.5e-3), ...
        idt_cutter('hole',  14e-3,   0,     3.5e-3), ...
        idt_cutter('rect',   0,      14e-3, 16e-3, 5e-3, 0), ...
        idt_cutter('rect',   0,     -14e-3, 12e-3, 4e-3, 20) ];
% cut = idt_cutter([]);                        % no cutters at all: the part as it is

[cut, dropped] = idt_cutters_filter(S, cut);   % drops cutters that touch supports, load or outputs
if any(dropped), fprintf('Dropped %d cutter(s) that touch a support, the load or an output point.\n', nnz(dropped)); end
idt_plot_cutters(smodel, S, cut);              % top view + 3-D: exact cutters on the mesh the analysis uses


%% 4. SIMULATE  (compute only: the mesh elements inside the cutters are removed, then the usual analysis)
[X, volFrac] = idt_cutters_mask(S, cut);       % X: one entry per removable element, 1 = kept, 0 = inside a cutter
[~, met0] = idt_analyze(smodel);               % reference: the part as it is
[res, met] = idt_analyze(smodel, X);
if ~met.Valid
    error('Design is not valid: the load / output points are cut off from every support.');
end

dirName = 'xyz';
fprintf('\n---------------- RESULT ----------------\n');
fprintf('  cutters                  : %d\n', numel(cut));
fprintf('  design part left         : %.1f %%\n', 100 * volFrac);
[wallOk, wall] = idt_cutters_wall(S, cut);
if wallOk, fprintf('  minimum wall             : OK (no wall thinner than %.1f mm)\n', C.MinWall * 1e3);
else, fprintf('  minimum wall             : VIOLATED, %.1f mm^2 thinner than %.1f mm\n', wall.Area * 1e6, C.MinWall * 1e3); end
fprintf('  natural frequencies [Hz] : %s\n', sprintf('%.1f  ', met.NaturalFreqs(1:min(6, end))));
fprintf('  f1 without cutters       : %.1f Hz\n', met0.f1);
fprintf('  mass                     : %.2f g  (without cutters %.2f g)\n', met.Mass * 1e3, met0.Mass * 1e3);
fprintf('  floating elements        : %d\n', met.Dropped);
fprintf('  modal coverage           : %.1fx   (want > 1.5)\n', res.ModalCoverage);
for o = 1:size(met.FRFPeak, 1)
    [pk, d] = max(met.FRFPeak(o, :));
    fprintf('  output %d: peak |u| = %.3g um (%s) at %.1f Hz\n', o, pk * 1e6, dirName(d), met.FRFPeakFreq(o, d));
end
fprintf('----------------------------------------\n');


%% 5. PLOT THE RESULTS  (response curves, mode shapes, transmissibility)
idt_plot_analysis(smodel, X, res, 'Design', false);


%% 6. EXACT CHECK  (real CAD cut, new mesh that follows the cutter edges, same analysis)
% Step 4 is fast but removes whole mesh elements, so cutter edges are only as exact as the mesh. This step cuts the real CAD part
% and meshes it again. A difference of a few percent in f1 is normal; a large one means the mesh is too coarse for your cutters.
geom2 = idt_cutters_geometry(model, cut);
[vmodel, vres, vmet] = idt_cutters_verify(model, geom2);
fprintf('\n  f1, fast analysis : %.2f Hz\n  f1, exact CAD cut : %.2f Hz  (%.2f %% difference)\n', ...
    met.f1, vmet.f1, 100 * (vmet.f1 - met.f1) / met.f1);


%% 7. SAVE THE STL  (the part you print: closed surface, round holes stay round)
stl = idt_cutters_export_stl(geom2, ['shape_manual_' ProblemName]);   % results/shape_manual_<ProblemName>.stl, in mm
