%% SIM_StaticLoad  -  step-by-step simulation: import -> bricks -> BC -> mesh -> model -> static solve.
%
%  A cantilever beam under a constant force. No optimization. Work through the numbered steps in
%  order (run a step with Ctrl+Enter, or run the whole script with F5). EVERY step has its own
%  parameters at its top and shows its own figure, so you can check each result before going on.
%  Same steps as SIM_HarmonicMotion.m; only the loading (steps 4, 6) and the results (steps 8, 9) differ:
%
%     1. import the CAD files      -> figures: each part | the assembly with its face numbers
%     2. brick the design domain   -> figure: brick grid
%     3. choose the bricks to keep -> figure: brick selection preview (clean boxes)
%     4. boundary conditions       -> figure: clamped face, load, output points
%     5. mesh                      -> figure: tetrahedral mesh
%     6. build the model           -> (numbers printed; analysis settings)
%     7. apply the selection       -> figure: the meshed design
%     8. solve                     -> deflection, stress, stiffness, mass
%     9. plot the results          -> figures: deformed shape | von Mises stress
%    10. save the parameters       -> an optimizer can then run on exactly the same problem:
%                                     P = idt_load_params('<ProblemName>');
%
%  The geometry (cad/): a 150 x 50 x 10 mm fixed frame (steel) whose 140 x 40 mm window is filled
%  by the design frame (aluminum, the part that can be redesigned). The frame is clamped at its
%  left end and loaded at its right end, so the whole piece acts as a cantilever beam: the frame's
%  top and bottom bars are the flanges, the design part between them is the web.
%
%  Every parameter is explained in docs/01_model_setup.md (analysis: docs/10_static_load.md).
%  UNITS: meters, kilograms, newtons, seconds.   (1e-3 = 1 mm)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

ProblemName = 'CantileverBeam';         % the parameters are saved as results/<ProblemName>.mat (step 10)
P = struct();                           % all parameters are collected in P, step by step


%% 1. IMPORT AND VIEW THE GEOMETRY  (check: is everything imported correctly? note the face numbers)
% STEP / IGES / STL files; relative paths start in the toolbox folder (cad/...). Any number of parts.
% Where parts overlap, the FIRST part owns the overlap. Face numbers depend on this order.
P.Geometry.Files = {'cad/02StaticBeamDesignFrame.STEP', ...   % part 1: design frame (the part that can be redesigned)
                    'cad/01StaticBeamFixedFrame.STEP'};       % part 2: outer frame that holds it
P.Geometry.Names = {'Design frame', 'Fixed frame'};
P.Geometry.Scale = 1;                                % file units -> meters (STEP is already meters; STL in mm: 1e-3)

% Materials: a library name ('Aluminum-6061', 'Structural-Steel', 'PLA', ... see core/get_material_properties.m)
% or your own struct(Name, E [Pa], nu, rho [kg/m^3]).
P.Geometry.Materials = {'Aluminum-6061', 'Structural-Steel'};   % one per file, same order

geom = idt_import_geometry(P);
plot_geometry(geom);            % figure 1: each imported part (check size and shape) | figure 2: the fused assembly WITH FACE NUMBERS
faces = list_faces(geom);       % table: face ID, centroid, size (helps to identify faces in the figure)


%% 2. BRICK THE DESIGN DOMAIN  (check: do the bricks cover the part you want to redesign?)
% The part an optimizer may change is cut into a grid of switchable bricks (1 = present, 0 = removed).
P.Design.Type         = 'bricks';   % 'bricks' | 'none' (no design domain: analyse the geometry as imported)
P.Design.Part         = 1;          % which part is the design domain (index in Files above)
P.Design.MinPrintSize = 5.0e-3;     % smallest printable feature [m]
P.Design.Density      = 80;         % 0 = coarse bricks ... 100 = finest (edge = MinPrintSize)
P.Design.Layers       = [0 1 0];    % hard layer count [nx ny nz]; 0 = automatic. [0 1 0] = one layer through the 10 mm thickness
P.Design.MinFill      = 0.5;        % a grid cell becomes a brick only if >= 50 % full of design material
P.Design.MaxOverlap   = 0;          % ... and overlaps other parts by at most this fraction

bricks = idt_make_bricks(P, geom);
if strcmpi(P.Design.Type, 'bricks'), plot_bricks(geom, bricks); end


%% 3. CHOOSE THE BRICKS TO KEEP  (check: the preview shows exactly the layout you want to simulate)
% M is the selection on the brick grid: 1 = present, 0 = removed, NaN = not a brick. Coordinates are
% brick centers in meters. Start from "all present" and remove / keep bricks with a rule, or edit M by hand.
M = idt_select_bricks(bricks);                                                      % A: all bricks present (solid web)
% M = idt_select_bricks(bricks, 'RemoveBox', [-40e-3 40e-3 -1 1 -10e-3 10e-3]);     % B: cut a window out of the web
% M = idt_select_bricks(bricks, 'KeepFcn', @(x,y,z) abs(z) > 12e-3 | abs(x) > 55e-3);   % C: keep only the flanges' neighbourhood and the ends
% M = idt_select_bricks(bricks, 'RemoveIJK', [3 1 2; 3 1 3]);                       %    remove by grid index
% M(5:8, :, 2) = 0;                                                                 % D: edit the matrix by hand
% brick_matrix([], M);                       % prints the layer maps ('#' present, '.' removed) to check an edit

if strcmpi(P.Design.Type, 'bricks'), idt_plot_brick_selection(geom, bricks, M); end


%% 4. BOUNDARY CONDITIONS AND LOAD  (check: supports red, load arrow magenta, outputs green)
% Read the face numbers from the figure of step 1 (or the table `faces`) and enter them here.
P.BC.FixedFaces    = 5;                         % clamped face (u = v = w = 0): the left end, x = -75 mm
P.BC.LoadFaces     = 3;                         % the force is spread over this face: the right end, x = +75 mm
P.BC.LoadDirection = [0 0 -1];                  % force direction (z down)
P.BC.LoadAmplitude = 500;                       % total force [N]
P.BC.OutPoints     = [75e-3 5e-3 0; ...         % displacement is reported here: output 1 = the tip
                      0     5e-3 -25e-3];       % output 2 = middle of the lower flange
P.BC.ExtraMass     = 0;                         % no lumped mass in a static example

idt_validate_params(P, geom);       % plain-language check of everything entered so far (stops with a list of problems)
bc = idt_make_bc(P);
plot_bc(geom, bc);


%% 5. MESH  (check: elements clearly smaller than a brick)
% The mesh follows the CAD surfaces and is independent of the bricks.
% Keep Hmax <= about 0.7 x the brick edge (printed in step 2), otherwise step 6 warns about bricks
% that contain no element and cannot be switched.
P.Mesh.Hmax   = 2.0e-3;             % target element size [m]
P.Mesh.Order  = 'quadratic';        % 'linear' = TET4 (fast, too stiff in bending) | 'quadratic' = TET10 (accurate, slower)
P.Mesh.Refine = {};                 % local refinement, e.g. {[1 2 3 4], 1e-3} = finer mesh at faces 1-4

mesh = idt_make_mesh(P, geom);
plot_mesh(mesh);                    % left: outer surface | right: cut-away of the interior


%% 6. BUILD THE MODEL  (element matrices; read the printed numbers and warnings)
% Analysis settings: a static analysis has no further parameters. The load is P.BC.LoadAmplitude.
P.Analysis.Type = 'Static';

model = idt_assemble_model(P, geom, bricks, bc, mesh);


%% 7. APPLY THE SELECTION  (X: one entry per design brick, 1 = present, 0 = removed)
% The model now knows which bricks are locked by supports / load / outputs (they always stay solid),
% so the selection M of step 3 becomes the design vector X. Removed bricks delete the mesh elements
% whose centroid lies in them, so the cut edges follow the mesh (about one element size).
X = select_bricks(model, 'Matrix', M);

plot_design(model, X);              % the meshed design with supports, load and outputs


%% 8. SOLVE  (K u = F; compute only)
[res, met] = idt_analyze(model, X);
if ~met.Valid
    error('Design is not valid: the load is cut off from the supports, or the bricks touch only along an edge or corner (a mechanism).');
end

fprintf('\n---------------- RESULT ----------------\n');
fprintf('  load                     : %.4g N along [%g %g %g]\n', model.BC.LoadAmplitude, model.BC.LoadDirection);
fprintf('  max displacement         : %.4g um\n', met.MaxDisp * 1e6);
for o = 1:size(met.OutDefl, 1)
    fprintf('  output %d displacement    : [%.4g %.4g %.4g] um\n', o, met.OutDefl(o, :) * 1e6);
end
fprintf('  stiffness (output 1)     : %.4g N/mm\n', met.Stiffness * 1e-3);
fprintf('  compliance F''u           : %.4g mJ\n', met.Compliance * 1e3);
fprintf('  max von Mises stress     : %.4g MPa  (peaks at the clamp / load nodes grow with mesh refinement)\n', met.MaxVonMises * 1e-6);
fprintf('  mass                     : %.2f g\n', met.Mass * 1e3);
fprintf('  bricks present           : %d of %d\n', nnz(X), model.NumVars);
fprintf('  floating elements        : %d\n', met.Dropped);
fprintf('  reaction check           : sum of support forces = [%.4g %.4g %.4g] N (should be minus the load)\n', res.Reaction);
fprintf('----------------------------------------\n');
idt_sanity_checks(model, res, met);     % reaction = load? mesh fine enough? no floating pieces? Read every line.


%% 9. PLOT THE RESULTS  (deformed shape and von Mises stress)
idt_plot_static(model, X, res);         % 'Scale', 100 sets the magnification of the deformation


%% 10. SAVE THE PARAMETERS  (so an optimizer can use exactly the same problem)
idt_save_params(P, ProblemName);
% Optional: export the design as STL (in mm):
% export_geometry(model, X, fullfile(idt_root(), 'results', 'my_design'));
