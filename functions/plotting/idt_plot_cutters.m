function fig = idt_plot_cutters(smodel, S, cut)
% IDT_PLOT_CUTTERS  Preview of a cutter design: exact cutter outlines on the meshed part that the analysis sees.
%
%   fig = idt_plot_cutters(smodel, S, cut)       smodel, S: from idt_shape_setup       cut: list of cutters
%
% Left: top view. Black outlines are the exact cutters (what will be cut in the CAD part); the colored mesh is what the analysis
% uses (elements whose centroid lies in a cutter are removed, so edges follow the mesh). The dashed box is the region where
% cutter centers may lie. Right: the same in 3-D, with supports (red), load (magenta) and outputs (green).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    [X, vf] = idt_cutters_mask(S, cut);
    ev = smodel.ElemVar;  act = ev == 0;  act(ev > 0) = X(ev(ev > 0));
    [F, own] = boundary_faces(smodel.Elem(act, :));
    ids = find(act);  part = smodel.Tag(ids(own));
    cmap = lines(max(numel(smodel.Geom.Parts), 1));
    V = smodel.Nodes * 1e3;
    zTop = max(V(:, 3)) + 0.2;
    th = linspace(0, 2 * pi, 60);
    [wallOk, wall] = idt_cutters_wall(S, cut);

    fig = figure('Name', 'Cutters', 'Color', 'w', 'Position', [100 100 1150 520]);
    tl = tiledlayout(1, 2, 'TileSpacing', 'compact');
    for k = 1:2
        nexttile; hold on;
        patch('Faces', F, 'Vertices', V, 'FaceVertexCData', cmap(part, :), 'FaceColor', 'flat', ...
              'EdgeColor', 'none', 'FaceLighting', 'flat');
        if ~wallOk                                           % too-thin walls in red
            [r, c] = find(wall.Mask);
            plot3(S.Wall.x(c) * 1e3, S.Wall.y(r) * 1e3, (zTop + 0.05) * ones(size(r)), 's', 'Color', [0.9 0 0], ...
                  'MarkerFaceColor', [0.9 0 0], 'MarkerSize', 2);
        end
        R = S.C.Region * 1e3;
        plot3([R(1) R(2) R(2) R(1) R(1)], [R(3) R(3) R(4) R(4) R(3)], zTop * ones(1, 5), 'k--', 'LineWidth', 0.8);
        for q = 1:numel(cut)
            c = cut(q);
            if strcmp(c.Type, 'hole')
                px = c.X + c.A * cos(th);  py = c.Y + c.A * sin(th);
            else
                t = deg2rad(c.AngleDeg);  cx = [-1 1 1 -1 -1] * c.A / 2;  cy = [-1 -1 1 1 -1] * c.B / 2;
                px = c.X + cos(t) * cx - sin(t) * cy;  py = c.Y + sin(t) * cx + cos(t) * cy;
            end
            plot3(px * 1e3, py * 1e3, zTop * ones(size(px)), 'k-', 'LineWidth', 1.6);
            text(c.X * 1e3, c.Y * 1e3, zTop + 0.1, sprintf('%d', q), 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', 'k');
        end
        c3 = smodel.Nodes * 1e3;
        plot3(c3(smodel.FixedNodes, 1), c3(smodel.FixedNodes, 2), c3(smodel.FixedNodes, 3), 'r^', 'MarkerFaceColor', 'r', 'MarkerSize', 3);
        plot3(c3(smodel.OutNodes, 1), c3(smodel.OutNodes, 2), c3(smodel.OutNodes, 3), 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 7);
        lp = mean(c3(smodel.LoadNodes, :), 1);
        plot3(lp(1), lp(2), lp(3), 'm*', 'MarkerSize', 9, 'LineWidth', 1.5);
        axis equal; grid on; camlight headlight;
        xlabel('x (mm)'); ylabel('y (mm)'); zlabel('z (mm)');
        if k == 1, view(0, 90); title('top view: exact cutters (black) on the analysis mesh');
        else, view(35, 28); title('3-D view'); end
    end
    if wallOk, ws = sprintf('no wall thinner than %.1f mm', S.C.MinWall * 1e3);
    else, ws = sprintf('WALLS THINNER THAN %.1f mm (red): %.1f mm^2', S.C.MinWall * 1e3, wall.Area * 1e6); end
    title(tl, sprintf('%d cutter(s), %.1f %% of the design part left, %s', numel(cut), 100 * vf, ws));
end
