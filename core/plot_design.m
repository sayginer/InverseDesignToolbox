function fig = plot_design(model, X)
% PLOT_DESIGN  The meshed structure for brick layout X (removed bricks are gone),
% colored by CAD part, with constraints, load and output points.
%   plot_design(model, X)     X = [] shows all bricks present
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)
    if nargin < 2 || isempty(X), X = true(model.NumVars, 1); end
    X = X(:) > 0.5;
    ev = model.ElemVar; act = ev == 0; act(ev > 0) = X(ev(ev > 0));
    [F, own] = boundary_faces(model.Elem(act, :));
    ids = find(act); part = model.Tag(ids(own));
    cmap = lines(max(numel(model.Geom.Parts), 1));
    fig = figure('Name', 'Design', 'Color', 'w', 'Position', [180 100 760 580]);
    patch('Faces', F, 'Vertices', model.Nodes * 1e3, 'FaceVertexCData', cmap(part, :), ...
          'FaceColor', 'flat', 'EdgeColor', 'none', 'FaceLighting', 'flat');
    hold on; axis equal; grid on; view(35, 28); camlight headlight;
    c = model.Nodes * 1e3;
    h1 = plot3(c(model.FixedNodes,1), c(model.FixedNodes,2), c(model.FixedNodes,3), 'r^', ...
               'MarkerFaceColor', 'r', 'MarkerSize', 3);
    d = model.BC.LoadDirection(:)' / norm(model.BC.LoadDirection); L = 8;
    lp = mean(c(model.LoadNodes, :), 1);
    h2 = quiver3(lp(1)-L*d(1), lp(2)-L*d(2), lp(3)-L*d(3), L*d(1), L*d(2), L*d(3), 0, 'm', ...
                 'LineWidth', 2.5, 'MaxHeadSize', 1);
    h3 = plot3(c(model.OutNodes,1), c(model.OutNodes,2), c(model.OutNodes,3), 'go', ...
               'MarkerFaceColor', 'g', 'MarkerSize', 7);
    for o = 1:numel(model.OutNodes)       % number the outputs = curve numbers in the FRF plot
        text(c(model.OutNodes(o),1), c(model.OutNodes(o),2), c(model.OutNodes(o),3) + 1.2, sprintf(' %d', o), ...
             'FontWeight', 'bold', 'FontSize', 12, 'Color', [0 0.45 0]);
    end
    xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
    legend([h1 h2 h3], {'Fixed', 'Load', 'Output'}, 'Location', 'bestoutside');
    title(sprintf('Design: %.0f%% of free bricks kept, %d elements', 100 * mean(X), nnz(act)));
end
