function info = check_brickization(domain, minPrintSize, density, varargin)
% CHECK_BRICKIZATION  Check how a geometry is filled with cubic bricks, and list every brick.
%
%   info = check_brickization(geom, 1e-3, 25, 'Part', 2)        % brick imported part 2
%   info = check_brickization([xmin xmax ymin ymax zmin zmax], 1e-3, 25)   % or any box
%
% INPUTS
%   domain        geom struct from import_geometry (needs 'Part'), or a 1x6 bounding box (m)
%   minPrintSize  smallest printable size (m), scalar or [x y z]
%   density       0..100 (100 = smallest printable brick)
% NAME-VALUE
%   'Part'   part index when domain is a geom struct
%   'Layers' [nx ny nz] hard layer counts, 0 = auto (e.g. [0 0 5] = exactly 5 layers in z)
%   'Plot'   draw the bricks colored by fill fraction (default true)
%   'WeakFill' bricks with less material than this fraction are flagged (default 0.25)
%
% OUTPUT info
%   .EdgeSize       cubic brick edge (m)
%   .N, .NumBricks  grid size and total bricks;  .NumWithMaterial  bricks that hold material
%   .Overhang       how far the grid sticks out past the domain [x y z] (m)
%   .Bricks         table, one row per brick holding material:
%                   ID, IJK (grid index), Center (m), Size [sx sy sz] (m), Fill (0..1)
%   .NumWeak        bricks with fill below 'WeakFill' (thin slivers: hard to print / weak)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'Part', []);
    addParameter(p, 'Plot', true);
    addParameter(p, 'Layers', [0 0 0]);
    addParameter(p, 'WeakFill', 0.25);
    parse(p, varargin{:});
    r = p.Results;

    if isstruct(domain)
        assert(~isempty(r.Part), 'Give ''Part'' when passing a geom struct.');
        bricks = create_bricks(domain, 'DesignPart', r.Part, 'MinPrintSize', minPrintSize, ...
                               'Density', density, 'Layers', r.Layers);
    else
        g0 = struct('Parts', []);
        bricks = create_bricks(g0, 'Box', domain, 'MinPrintSize', minPrintSize, ...
                               'Density', density, 'Layers', r.Layers);
    end
    g = bricks.Grid; N = g.N;

    idx = find(bricks.Present);
    [i, j, k] = ind2sub(N, idx);
    center = g.Min + ([i j k] - 0.5) .* g.Size;
    sz = repmat(g.Size, numel(idx), 1);
    ID = (1:numel(idx))';
    T = table(ID, [i j k], center, sz, bricks.Fill(idx), ...
              'VariableNames', {'ID', 'IJK', 'Center', 'Size', 'Fill'});

    info = struct('BrickSize', g.Size, 'EdgeSize', g.Size(1), 'N', N, 'NumBricks', g.NumBricks, ...
                  'NumWithMaterial', numel(idx), 'Overhang', g.Overhang, ...
                  'Bricks', T, 'NumWeak', nnz(T.Fill < r.WeakFill), 'Grid', g, 'BrickData', bricks);

    fprintf('--- Brickization check ---\n');
    fprintf('  Brick size:         %.3f x %.3f x %.3f mm%s, printable minimum %.3f mm\n', ...
        g.Size * 1e3, repmat(' (cubic)', 1, g.IsCubic), max(g.MinPrintSize) * 1e3);
    fprintf('  Bricks in grid:     %d (%d x %d x %d), holding material: %d\n', g.NumBricks, N, numel(idx));
    fprintf('  Full bricks (>=99%%): %d | partial: %d | weak (<%.0f%% full): %d\n', ...
        nnz(T.Fill >= 0.99), nnz(T.Fill < 0.99), r.WeakFill * 100, info.NumWeak);
    fprintf('  Overhang past domain: %.3f / %.3f / %.3f mm\n', g.Overhang * 1e3);
    fprintf('  Every brick: %.3f x %.3f x %.3f mm (see info.Bricks)\n\n', g.Size * 1e3);

    if r.Plot
        figure('Name', 'Brickization check', 'Color', 'w', 'Position', [100 90 760 580]);
        s = g.Size / 2;
        cv = [-1 -1 -1; 1 -1 -1; 1 1 -1; -1 1 -1; -1 -1 1; 1 -1 1; 1 1 1; -1 1 1];
        cf = [1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8];
        nb = numel(idx);
        V = reshape(permute(reshape(center, nb, 1, 3) + reshape(cv, 1, 8, 3) .* reshape(s, 1, 1, 3), [2 1 3]), [], 3) * 1e3;
        Fc = reshape((cf + 8 * reshape(0:nb-1, 1, 1, [])), 6, 4, nb);
        Fc = reshape(permute(Fc, [2 1 3]), 4, [])';
        C = repelem(T.Fill, 6);
        patch('Faces', Fc, 'Vertices', V, 'FaceVertexCData', C, 'FaceColor', 'flat', ...
              'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.3, 'FaceAlpha', 0.85);
        colormap(turbo); clim([0 1]); cb = colorbar; ylabel(cb, 'Fill fraction');
        axis equal; grid on; view(35, 28); xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
        title(sprintf('%d bricks of %.2f x %.2f x %.2f mm, colored by fill (%d weak)', nb, g.Size * 1e3, info.NumWeak));
    end
end
