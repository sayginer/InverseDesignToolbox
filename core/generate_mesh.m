function mesh = generate_mesh(geom, varargin)
% GENERATE_MESH  STEP 4 - free tetrahedral mesh of the real CAD geometry.
% The mesh follows the CAD surfaces (round holes stay round) and is completely
% independent of the bricks.
%
%   mesh = generate_mesh(geom, 'Hmax', 2e-3, 'Order', 'quadratic', 'Refine', {[5 6 7 8], 1e-3})
%
%   'Hmax'    target element size (m), default = largest dimension / 25
%   'Hmin'    minimum element size (optional)
%   'Hgrad'   growth rate (optional, default 1.5)
%   'Order'   'quadratic' (TET10, default) or 'linear' (TET4)
%   'Refine'  {faceIDs, size, faceIDs, size, ...} local refinement on assembly faces
%
% For brick switching to be meaningful, elements should be clearly smaller than a
% brick (Hmax <= about 0.7 x brick size).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'Hmax', []);
    addParameter(p, 'Hmin', []);
    addParameter(p, 'Hgrad', []);
    addParameter(p, 'Order', 'quadratic');
    addParameter(p, 'Refine', {});
    addParameter(p, 'Verbose', true);
    parse(p, varargin{:});
    r = p.Results;

    gm = geom.Assembly;
    Hmax = r.Hmax;
    if isempty(Hmax), Hmax = max(max(gm.Vertices) - min(gm.Vertices)) / 25; end
    args = {'Hmax', Hmax, 'GeometricOrder', r.Order};
    if ~isempty(r.Hmin),   args = [args, {'Hmin', r.Hmin}]; end
    if ~isempty(r.Hgrad),  args = [args, {'Hgrad', r.Hgrad}]; end
    if ~isempty(r.Refine), args = [args, {'Hface', r.Refine}]; end

    mdl = femodel(AnalysisType="structuralModal", Geometry=gm);
    mdl = generateMesh(mdl, args{:});

    mesh = struct('Model', mdl, 'Mesh', mdl.Mesh, 'Nodes', mdl.Mesh.Nodes', ...
                  'Elements', mdl.Mesh.Elements', 'Order', r.Order, 'Hmax', Hmax);
    if r.Verbose
        fprintf('--- Mesh ---\n  %s tetrahedra: %d elements, %d nodes (%d DOFs), Hmax = %.2f mm\n\n', ...
            ternary(strcmp(r.Order, 'quadratic'), 'TET10', 'TET4'), size(mesh.Elements, 1), ...
            size(mesh.Nodes, 1), 3 * size(mesh.Nodes, 1), Hmax * 1e3);
    end
end

function o = ternary(c, a, b)
    if c, o = a; else, o = b; end
end
