function bc = define_bc(varargin)
% DEFINE_BC  STEP 3 - boundary conditions, load and output points.
%
%   bc = define_bc('FixedFaces', [5 6 7 8], ...
%                  'LoadPoint', [0 0 5e-3], 'LoadDirection', [0 0 1], 'LoadAmplitude', 10, ...
%                  'OutPoints', [0 0 5e-3; 8.67e-3 6.76e-3 5e-3], ...
%                  'ExtraMass', 0.005, 'ExtraMassRegion', @(x,y,z) abs(x) < 10.25e-3 & abs(y) < 8e-3)
%
%   'FixedFaces'       assembly face IDs clamped (u = v = w = 0); see plot_geometry / list_faces
%   'FixedFcn'         optional @(x,y,z) selecting extra clamped nodes
%   'LoadFaces'        force spread equally over all nodes of these faces, OR
%   'LoadPoint'        force applied at the node nearest to this [x y z] (m)
%   'LoadDirection'    [dx dy dz] (normalized internally), 'LoadAmplitude' (N)
%   'OutPoints'        n x 3 points where x, y, z displacement is reported
%   'ExtraMass'        lumped mass (kg) spread over the nodes selected by 'ExtraMassRegion'
%
% Mesh elements touching fixed / load / output nodes are locked (never removed).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'FixedFaces', []);
    addParameter(p, 'FixedFcn', []);
    addParameter(p, 'LoadFaces', []);
    addParameter(p, 'LoadPoint', []);
    addParameter(p, 'LoadDirection', [0 0 1]);
    addParameter(p, 'LoadAmplitude', 1);
    addParameter(p, 'OutPoints', []);
    addParameter(p, 'ExtraMass', 0);
    addParameter(p, 'ExtraMassRegion', []);
    parse(p, varargin{:});
    bc = p.Results;
    assert(~isempty(bc.FixedFaces) || ~isempty(bc.FixedFcn), 'Define at least one fixed face or FixedFcn.');
    assert(~isempty(bc.LoadFaces) || ~isempty(bc.LoadPoint), 'Define LoadFaces or LoadPoint.');
    assert(~isempty(bc.OutPoints), 'Define at least one output point.');
    assert(bc.ExtraMass == 0 || ~isempty(bc.ExtraMassRegion), 'ExtraMass needs ExtraMassRegion.');
end
