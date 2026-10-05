function fig = plot_mesh(mesh, varargin)
% PLOT_MESH  STEP 4 view - the free tetrahedral mesh, in one figure with two panels:
%   left  = outer surface mesh
%   right = cut-away showing the interior mesh (elements with centroid y <= 0 by default)
%
%   plot_mesh(mesh)
%   plot_mesh(mesh, 'ClipX', 0)     cut along x instead ('ClipY' default 0, 'ClipZ' also possible)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)
    p = inputParser;
    addParameter(p, 'ClipX', []); addParameter(p, 'ClipY', []); addParameter(p, 'ClipZ', []);
    parse(p, varargin{:});
    r = p.Results;
    if isempty(r.ClipX) && isempty(r.ClipY) && isempty(r.ClipZ), r.ClipY = 0; end

    el = mesh.Elements(:, 1:4); nd = mesh.Nodes;
    c = (nd(el(:,1),:) + nd(el(:,2),:) + nd(el(:,3),:) + nd(el(:,4),:)) / 4;
    keep = true(size(el, 1), 1);
    clipTxt = '';
    if ~isempty(r.ClipX), keep = keep & c(:,1) <= r.ClipX; clipTxt = sprintf('x <= %.1f mm', r.ClipX * 1e3); end
    if ~isempty(r.ClipY), keep = keep & c(:,2) <= r.ClipY; clipTxt = sprintf('y <= %.1f mm', r.ClipY * 1e3); end
    if ~isempty(r.ClipZ), keep = keep & c(:,3) <= r.ClipZ; clipTxt = sprintf('z <= %.1f mm', r.ClipZ * 1e3); end

    fig = figure('Name', 'Mesh', 'Color', 'w', 'Position', [100 100 1200 560]);
    tiledlayout(1, 2, 'TileSpacing', 'compact');
    panel(el, nd, sprintf('%s mesh: %d elements, %d nodes, Hmax %.2f mm', ...
        ternary(size(mesh.Elements, 2) == 10, 'TET10', 'TET4'), size(mesh.Elements, 1), ...
        size(mesh.Nodes, 1), mesh.Hmax * 1e3));
    panel(el(keep, :), nd, ['Cut-away (interior), elements with ' clipTxt]);
end

function panel(el, nd, ttl)
    nexttile;
    F = boundary_faces(el);
    patch('Faces', F, 'Vertices', nd * 1e3, 'FaceColor', [0.75 0.85 1], 'EdgeColor', [0.2 0.2 0.3], ...
          'LineWidth', 0.25);
    axis equal; grid on; view(35, 28); xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
    title(ttl);
end

function o = ternary(c, a, b)
    if c, o = a; else, o = b; end
end
