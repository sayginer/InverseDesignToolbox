function figs = plot_geometry(geom)
% PLOT_GEOMETRY  STEP 1 view - figure 1: every imported part; figure 2: the fused assembly with FACE NUMBERS.
% In the assembly figure each part (domain) has its own color; the face numbers shown there
% are the ones used for boundary conditions.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)
    n = numel(geom.Parts);
    cmap = lines(max(n, 1));

    % one panel per imported part, same color as in the assembly figure. (Face numbers are NOT shown
    % here: a part's own numbering differs from the assembly numbering used for boundary conditions.)
    f1 = figure('Name', 'Imported parts', 'Color', 'w', 'Position', [60 80 330*n 380]);
    tiledlayout(1, n, 'TileSpacing', 'compact');
    for i = 1:n
        nexttile;
        mName = geom.Parts(i).Material;
        if isstruct(mName) && isfield(mName, 'Name'), mName = mName.Name;
        elseif isstruct(mName), mName = 'Custom'; end
        F = boundary_faces(geom.Parts(i).Tets);
        patch('Faces', F, 'Vertices', geom.Parts(i).Nodes * 1e3, 'FaceColor', cmap(i, :), ...
              'EdgeColor', 'none', 'FaceAlpha', 0.95);
        axis equal; grid on; view(35, 28); camlight headlight; lighting gouraud;
        xlabel('x (mm)'); ylabel('y (mm)'); zlabel('z (mm)');
        b = geom.Parts(i).BBox * 1e3;
        title({sprintf('Part %d: %s (%s)', i, geom.Parts(i).Name, mName), ...
               sprintf('%.1f x %.1f x %.1f mm', b(2) - b(1), b(4) - b(3), b(6) - b(5))}, 'Interpreter', 'none');
    end

    % assembly: color the surface by domain, then overlay the numbered CAD faces
    % (each part's own helper mesh gives exact domain borders)
    f2 = figure('Name', 'Assembly faces', 'Color', 'w', 'Position', [120 100 760 600]);
    hold on;
    h = gobjects(1, n);
    for ip = 1:n
        F = boundary_faces(geom.Parts(ip).Tets);
        h(ip) = patch('Faces', F, 'Vertices', geom.Parts(ip).Nodes, 'FaceColor', cmap(ip, :), ...
                      'EdgeColor', 'none', 'FaceAlpha', 0.9, 'DisplayName', geom.Parts(ip).Name);
    end
    pdegplot(geom.Assembly, 'FaceLabels', 'on', 'FaceAlpha', 0);   % edges + face numbers only
    legend(h, {geom.Parts.Name}, 'Location', 'bestoutside', 'Interpreter', 'none');
    title('Fused assembly: one color per domain, face numbers for boundary conditions');
    view(35, 28); axis equal;
    figs = [f1 f2];
end
