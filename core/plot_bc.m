function fig = plot_bc(geom, bc)
% PLOT_BC  STEP 3 view - constraints (red), load (magenta arrow), outputs (green).
% Uses a coarse preview mesh, independent of the analysis mesh.
%
%   fig = plot_bc(geom, bc)
%
%   geom : from import_geometry / idt_import_geometry
%   bc   : from define_bc / idt_make_bc (FixedFaces, FixedFcn, LoadFaces or LoadPoint, LoadDirection, OutPoints)
%   fig  : handle of the figure
%
% Output points are numbered; the numbers are the curve numbers in the FRF figure.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)
    gm = geom.Assembly;
    ext = max(max(gm.Vertices) - min(gm.Vertices));
    m = generateMesh(femodel(AnalysisType="structuralStatic", Geometry=gm), ...
                     Hmax=ext / 18, GeometricOrder="linear");
    nd = m.Mesh.Nodes';
    fig = figure('Name', 'Boundary conditions', 'Color', 'w', 'Position', [140 100 760 580]);
    pdegplot(gm, 'FaceAlpha', 0.15); hold on;

    fixed = [];
    if ~isempty(bc.FixedFaces), fixed = findNodes(m.Mesh, 'region', 'Face', bc.FixedFaces)'; end
    if ~isempty(bc.FixedFcn)
        fixed = union(fixed, find(bc.FixedFcn(nd(:,1), nd(:,2), nd(:,3))));
    end
    h1 = plot3(nd(fixed,1), nd(fixed,2), nd(fixed,3), 'r^', 'MarkerFaceColor', 'r', 'MarkerSize', 5);

    d = bc.LoadDirection(:)' / norm(bc.LoadDirection); L = 0.12 * ext;
    if ~isempty(bc.LoadFaces)
        ln = findNodes(m.Mesh, 'region', 'Face', bc.LoadFaces)';
        lp = mean(nd(ln, :), 1);
        plot3(nd(ln,1), nd(ln,2), nd(ln,3), 'm.', 'MarkerSize', 8);
    else
        [~, k] = min(sum((nd - bc.LoadPoint).^2, 2)); lp = nd(k, :);
    end
    h2 = quiver3(lp(1)-L*d(1), lp(2)-L*d(2), lp(3)-L*d(3), L*d(1), L*d(2), L*d(3), 0, ...
                 'm', 'LineWidth', 3, 'MaxHeadSize', 1.2);
    h3 = plot3(bc.OutPoints(:,1), bc.OutPoints(:,2), bc.OutPoints(:,3), 'go', ...
               'MarkerFaceColor', 'g', 'MarkerSize', 9);
    for o = 1:size(bc.OutPoints, 1)       % number the outputs = curve numbers in the FRF plot
        text(bc.OutPoints(o,1), bc.OutPoints(o,2), bc.OutPoints(o,3) + 0.0012, sprintf(' %d', o), ...
             'FontWeight', 'bold', 'FontSize', 12, 'Color', [0 0.45 0]);
    end
    legend([h1 h2 h3], {'Fixed (u=v=w=0)', sprintf('Load %.1f N', bc.LoadAmplitude), 'Output points'}, ...
           'Location', 'bestoutside');
    view(35, 28); axis equal; grid on;
    title('Boundary conditions, load and output points');
end
