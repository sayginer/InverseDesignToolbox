function fig = plot_bricks(geom, bricks)
% PLOT_BRICKS  STEP 2 view - the brick grid over the geometry (selection bricks only).
%
%   fig = plot_bricks(geom, bricks)
%
%   geom   : from import_geometry / idt_import_geometry (the CAD assembly is drawn transparent)
%   bricks : from create_bricks / idt_make_bricks (.Grid, .Present, .Name, .NumPresent)
%   fig    : handle of the figure
%
% Only the cells that are real bricks (bricks.Present) are drawn, as the outer surface of the brick set.
% The title gives the brick size, the grid and the number of bricks. Check that they cover the part you want to redesign.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)
    fig = figure('Name', 'Bricks', 'Color', 'w', 'Position', [100 90 760 580]);
    pdegplot(geom.Assembly, 'FaceAlpha', 0.12); hold on;
    g = bricks.Grid; N = g.N; Nn = N + 1;
    [X, Y, Z] = ndgrid(g.Min(1) + (0:N(1)) * g.Size(1), g.Min(2) + (0:N(2)) * g.Size(2), ...
                       g.Min(3) + (0:N(3)) * g.Size(3));
    V = [X(:) Y(:) Z(:)];
    solid = bricks.Present; P = false(N + 2); P(2:end-1, 2:end-1, 2:end-1) = solid;
    nid = @(a, b, c) a + Nn(1) * ((b - 1) + Nn(2) * (c - 1));
    faces = zeros(0, 4);
    for ax = 1:3
        for sgn = [-1 1]
            sh = zeros(1, 3); sh(ax) = sgn;
            nb = P(2+sh(1):end-1+sh(1), 2+sh(2):end-1+sh(2), 2+sh(3):end-1+sh(3));
            [i, j, k] = ind2sub(N, find(solid & ~nb)); o = sgn > 0;
            switch ax
                case 1, a = i + o; F = [nid(a,j,k) nid(a,j+1,k) nid(a,j+1,k+1) nid(a,j,k+1)];
                case 2, a = j + o; F = [nid(i,a,k) nid(i+1,a,k) nid(i+1,a,k+1) nid(i,a,k+1)];
                case 3, a = k + o; F = [nid(i,j,a) nid(i+1,j,a) nid(i+1,j+1,a) nid(i,j+1,a)];
            end
            faces = [faces; F]; %#ok<AGROW>
        end
    end
    patch('Faces', faces, 'Vertices', V, 'FaceColor', [0.2 0.6 1.0], 'FaceAlpha', 0.25, ...
          'EdgeColor', [0.1 0.3 0.6], 'LineWidth', 0.5);
    view(35, 28); axis equal; grid on;
    title(sprintf('Bricks for "%s": %.2f x %.2f x %.2f mm, %d x %d x %d grid, %d bricks', ...
        bricks.Name, g.Size * 1e3, g.N, bricks.NumPresent), 'Interpreter', 'none');
end
