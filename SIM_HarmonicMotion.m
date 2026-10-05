%% SIM_HarmonicMotion  -  step-by-step simulation: import -> bricks -> BC -> mesh -> model -> simulate.
%
%  No optimization. Work through the numbered steps in order (run a step with Ctrl+Enter, or run the
%  whole script with F5). EVERY step has its own parameters at its top and shows its own figure,
%  so you can check each result before going on:
%
%     1. import the CAD files      -> figures: each part | the assembly with its face numbers
%     2. brick the design domain   -> figure: brick grid
%     3. choose the bricks to keep -> figure: brick selection preview (clean boxes)
%     4. boundary conditions       -> figure: supports, load, output points
%     5. mesh                      -> figure: tetrahedral mesh
%     6. build the model           -> (numbers printed; analysis settings)
%     7. apply the selection       -> figure: the meshed design
%     8. simulate                  -> eigenfrequencies + harmonic response
%     9. plot the results
%    10. save the parameters       -> an optimizer can then run on exactly the same problem:
%                                     P = idt_load_params('<ProblemName>');
%
%  Every parameter is explained in docs/01_model_setup.md.
%  UNITS: meters, kilograms, newtons, seconds, Hz.   (1e-3 = 1 mm)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

ProblemName = 'VibrationIsolator';      % the parameters are saved as results/<ProblemName>.mat (step 9)
P = struct();                           % all parameters are collected in P, step by step


%% 1. IMPORT AND VIEW THE GEOMETRY  (check: is everything imported correctly? note the face numbers)
% STEP / IGES / STL files; relative paths start in the toolbox folder (cad/...). Any number of parts.
% Where parts overlap, the FIRST part owns the overlap. Face numbers depend on this order.
P.Geometry.Files = {'cad/03AccHolder.STEP', ...      % part 1: central holder (carries the sensor)
                    'cad/02DesignFrame.STEP', ...    % part 2: design frame (the part that can be redesigned)
                    'cad/01FixedFrame.STEP'};        % part 3: outer fixed frame
P.Geometry.Names = {'Holder', 'Design frame', 'Fixed frame'};
P.Geometry.Scale = 1;                                % file units -> meters (STEP is already meters; STL in mm: 1e-3)

% Materials: a library name ('Aluminum-6061', 'Structural-Steel', 'PLA', ... see core/get_material_properties.m)
% or your own struct(Name, E [Pa], nu, rho [kg/m^3]).
TPU       = struct('Name', 'TPU',       'E', 0.05e9, 'nu', 0.45, 'rho', 1200);
TPU_heavy = struct('Name', 'TPU-Heavy', 'E', 0.05e9, 'nu', 0.45, 'rho', 2000);
P.Geometry.Materials = {TPU_heavy, TPU, TPU};        % one per file, same order

geom = idt_import_geometry(P);
plot_geometry(geom);            % figure 1: each imported part (check size and shape) | figure 2: the fused assembly WITH FACE NUMBERS
faces = list_faces(geom);       % table: face ID, centroid, size (helps to identify faces in the figure)


%% 2. BRICK THE DESIGN DOMAIN  (check: do the bricks cover the part you want to redesign?)
% The part an optimizer may change is cut into a grid of switchable bricks (1 = present, 0 = removed).
P.Design.Type         = 'bricks';   % 'bricks' | 'none' (no design domain: analyse the geometry as imported)
P.Design.Part         = 2;          % which part is the design domain (index in Files above)
P.Design.MinPrintSize = 1.0e-3;     % smallest printable feature [m]
P.Design.Density      = 80;         % 0 = coarse bricks ... 100 = finest (edge = MinPrintSize)
P.Design.Layers       = [0 0 3];    % hard layer count [nx ny nz]; 0 = automatic. [0 0 3] = exactly 3 layers in z
P.Design.MinFill      = 0.5;        % a grid cell becomes a brick only if >= 50 % full of design material
P.Design.MaxOverlap   = 0;          % ... and overlaps other parts by at most this fraction

bricks = idt_make_bricks(P, geom);
if strcmpi(P.Design.Type, 'bricks'), plot_bricks(geom, bricks); end


%% 3. CHOOSE THE BRICKS TO KEEP  (check: the preview shows exactly the layout you want to simulate)
% M is the selection on the brick grid: 1 = present, 0 = removed, NaN = not a brick. Coordinates are
% brick centers in meters. Start from "all present" and remove / keep bricks with a rule, or edit M by hand.
M = idt_select_bricks(bricks);                                            % A: all bricks present
% M = idt_select_bricks(bricks, 'KeepFcn', @(x,y,z) abs(x) < 3e-3 | abs(y) < 3e-3);   % B: keep only a cross
% M = idt_select_bricks(bricks, 'RemoveBox', [-20e-3 20e-3 5e-3 20e-3 0 5e-3]);     %    cut a slot
% M = idt_select_bricks(bricks, 'RemoveIJK', [3 4 1; 3 5 1]);                       %    remove by grid index
% M(5:8, :, 1) = 0;                                                                 % C: edit the matrix by hand
% brick_matrix([], M);                       % prints the layer maps ('#' present, '.' removed) to check an edit

if strcmpi(P.Design.Type, 'bricks'), idt_plot_brick_selection(geom, bricks, M); end


%% 4. BOUNDARY CONDITIONS AND LOAD  (check: supports red, load arrow magenta, outputs green)
% Read the face numbers from the figure of step 1 (or the table `faces`) and enter them here.
P.BC.FixedFaces    = [1 2 3 4];                 % clamped faces (u = v = w = 0), here the 4 bolt holes
P.BC.LoadPoint     = [0 0 5e-3];                % [x y z] where the harmonic force acts [m]
P.BC.LoadDirection = [0 0 1];                   % force direction (z = vertical)
P.BC.LoadAmplitude = 1.0;                       % force amplitude [N]
P.BC.OutPoints     = [0 0 5e-3; ...             % response points [m], one per row (output 1, 2, ...)
                      8.67e-3 6.76e-3 5e-3];
P.BC.ExtraMass     = 0.005;                     % lumped extra mass, e.g. a sensor [kg] (0 = none)
P.BC.ExtraMassBox  = [-10.25e-3 10.25e-3 -8e-3 8e-3 -Inf Inf];   % where it sits [xmin xmax ymin ymax zmin zmax]

bc = idt_make_bc(P);
plot_bc(geom, bc);


%% 5. MESH  (check: elements clearly smaller than a brick)
% The mesh follows the CAD surfaces and is independent of the bricks.
% Keep Hmax <= about 0.7 x the brick edge (printed in step 2), otherwise step 6 warns about bricks
% that contain no element and cannot be switched.
P.Mesh.Hmax   = 2.0e-3;             % target element size [m]
P.Mesh.Order  = 'linear';           % 'linear' = TET4 (fast, ~18 % too stiff) | 'quadratic' = TET10 (accurate, slower)
P.Mesh.Refine = {};                 % local refinement, e.g. {[1 2 3 4], 1e-3} = finer mesh at faces 1-4

mesh = idt_make_mesh(P, geom);
plot_mesh(mesh);                    % left: outer surface | right: cut-away of the interior


%% 6. BUILD THE MODEL  (element matrices; read the printed numbers and warnings)
% Analysis settings: harmonic motion = eigenfrequencies + forced response.
P.Analysis.Type             = 'ModalHarmonic';
P.Analysis.FreqStart        = 2;    % sweep start [Hz]
P.Analysis.FreqEnd          = 500;  % sweep end   [Hz]
P.Analysis.FreqStep         = 3;    % sweep step  [Hz] (larger = faster, coarser curves)
P.Analysis.Zeta             = 0.05; % modal damping ratio (0.05 = 5 %)
P.Analysis.NModes           = 8;    % eigenmodes kept (want highest mode > 1.5 x FreqEnd, see "modal coverage")
P.Analysis.Transmissibility = true; % also compute base-excitation transmissibility

model = idt_assemble_model(P, geom, bricks, bc, mesh);


%% 7. APPLY THE SELECTION  (X: one entry per design brick, 1 = present, 0 = removed)
% The model now knows which bricks are locked by supports / load / outputs (they always stay solid),
% so the selection M of step 3 becomes the design vector X. Removed bricks delete the mesh elements
% whose centroid lies in them, so the cut edges follow the mesh (about one element size).
X = select_bricks(model, 'Matrix', M);

plot_design(model, X);              % the meshed design with supports, load and outputs


%% 8. SIMULATE  (eigenfrequencies + harmonic response; compute only)
[res, met] = idt_analyze(model, X);
if ~met.Valid
    error('Design is not valid: the load / output points are cut off from every support.');
end

dirName = 'xyz';
fprintf('\n---------------- RESULT ----------------\n');
fprintf('  natural frequencies [Hz] : %s\n', sprintf('%.1f  ', met.NaturalFreqs(1:min(6, end))));
fprintf('  mass                     : %.2f g\n', met.Mass * 1e3);
fprintf('  bricks present           : %d of %d\n', nnz(X), model.NumVars);
fprintf('  floating elements        : %d\n', met.Dropped);
fprintf('  modal coverage           : %.1fx   (want > 1.5)\n', res.ModalCoverage);
for o = 1:size(met.FRFPeak, 1)
    [pk, d] = max(met.FRFPeak(o, :));
    fprintf('  output %d: peak |u| = %.3g um (%s) at %.1f Hz\n', o, pk * 1e6, dirName(d), met.FRFPeakFreq(o, d));
end
fprintf('----------------------------------------\n');


%% 9. PLOT THE RESULTS  (response curves, mode shapes, transmissibility)
idt_plot_analysis(model, X, res, 'Design', false);      % 'Design', true also redraws the design figure


%% 10. SAVE THE PARAMETERS  (so an optimizer can use exactly the same problem)
idt_save_params(P, ProblemName);
% Optional: export the design as STL (in mm):
% export_geometry(model, X, fullfile(idt_root(), 'results', 'my_design'));
