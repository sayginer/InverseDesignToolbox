function fig = idt_plot_brick_selection(geom, bricks, M)
% IDT_PLOT_BRICK_SELECTION  Preview the brick selection as clean boxes (before meshing).
%
%   fig = idt_plot_brick_selection(geom, bricks, M)
%
%   M : brick matrix from idt_select_bricks (1 = present, 0 = removed, NaN = not a brick)
%
% Kept bricks are drawn as solid blue boxes, removed bricks as a faint grey ghost, and the CAD
% assembly as a transparent shell for orientation. This is the layout the optimizer sees; the
% jagged tetrahedral surface of the analysis mesh is a different thing (see docs/01_model_setup.md).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    g = bricks.Grid;
    keep    = bricks.Present & (M > 0.5);
    removed = bricks.Present & ~keep;

    fig = figure('Name', 'Brick selection', 'Color', 'w', 'Position', [100 90 760 580]);
    pdegplot(geom.Assembly, 'FaceAlpha', 0.05); hold on;
    if any(removed(:)), draw_surface(g, removed, [0.6 0.6 0.6], 0.06, [0.88 0.88 0.88]); end
    if any(keep(:)),    draw_surface(g, keep,    [0.2 0.6 1.0], 0.85, [0.1 0.3 0.6]);    end
    view(35, 28); axis equal; grid on;
    title(sprintf('Brick selection: %d of %d bricks kept (%.2f x %.2f x %.2f mm, %d x %d x %d grid)', ...
        nnz(keep), nnz(bricks.Present), g.Size * 1e3, g.N));
end

function draw_surface(g, solid, color, alpha, edgeColor)
% outer faces of a set of grid cells (faces shared by two selected cells are not drawn)
    N = g.N; Nn = N + 1;
    [X, Y, Z] = ndgrid(g.Min(1) + (0:N(1)) * g.Size(1), g.Min(2) + (0:N(2)) * g.Size(2), ...
                       g.Min(3) + (0:N(3)) * g.Size(3));
    V = [X(:) Y(:) Z(:)];
    P = false(N + 2); P(2:end-1, 2:end-1, 2:end-1) = solid;
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
    patch('Faces', faces, 'Vertices', V, 'FaceColor', color, 'FaceAlpha', alpha, ...
          'EdgeColor', edgeColor, 'LineWidth', 0.5);
end
