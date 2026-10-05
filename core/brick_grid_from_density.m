function grid = brick_grid_from_density(designBBox, varargin)
% BRICK_GRID_FROM_DENSITY  Bricks ("pixels") sized from a density out of 100.
%
%   grid = brick_grid_from_density(designBBox, 'MinPrintSize', 1e-3, 'Density', 25)
%   grid = brick_grid_from_density(designBBox, 'MinPrintSize', 1e-3, 'Density', 60, 'Layers', [0 0 1])
%
% INPUTS
%   designBBox    [xmin xmax ymin ymax zmin zmax] of the domain to brick (meters)
%   'MinPrintSize' smallest printable feature along x, y, z (scalar or [x y z], meters).
%   'Density'     0..100.  100 = finest (edge = minimum printable size),
%                 0 = coarsest (edge = thinnest free dimension of the domain).
%                 Linear in bricks per mm:  rho = rho_min + d/100 (rho_max - rho_min).
%   'Layers'      [nx ny nz] HARD layer counts, 0 = automatic. A constrained axis gets exactly
%                 that many layers (edge = length / layers). All free axes share ONE edge that
%                 follows Density, so density still controls the free directions.
%                 Example: [0 0 1] on a plate = one layer through the thickness with square
%                 x-y pixels sized by Density. Bricks are cubic only if the free-axis edge
%                 happens to equal the constrained edge. Errors if a constrained edge is below
%                 the minimum printable size.
%   'Size'        (optional) force the free-axis edge length in meters instead of a density.
%   'Verbose'     print a report (default true)
%
% FITTING. The free-axis edge is tuned within +-10% of the density's target to minimize
% the overhang (how far the last brick sticks out past the domain). The grid is centered
% on the domain; overhang is split equally between both ends. Overhanging bricks simply
% contain less material (the mesh is independent of the bricks).
%
% OUTPUT grid: .Size [sx sy sz], .N [nx ny nz], .Min (grid corner), .Overhang (m),
%   .EdgeTarget, .Density, .NumBricks, .Fabricable, .IsCubic
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'MinPrintSize', 1e-3);
    addParameter(p, 'Density', 50);
    addParameter(p, 'Size', []);
    addParameter(p, 'Layers', [0 0 0]);
    addParameter(p, 'Verbose', true);
    parse(p, varargin{:});
    r = p.Results;

    L  = [diff(designBBox(1:2)), diff(designBBox(3:4)), diff(designBBox(5:6))];
    mp = r.MinPrintSize(:)'; if isscalar(mp), mp = [mp mp mp]; end
    layers = r.Layers(:)'; if isscalar(layers), layers = [layers layers layers]; end
    hard = layers > 0;
    free = ~hard;

    % constrained axes: edge fixed by the layer count
    e = zeros(1, 3);
    e(hard) = L(hard) ./ layers(hard);
    bad = hard & (e < mp - 1e-12);
    if any(bad)
        ax = 'xyz';
        error('brick_grid_from_density:LayerTooThin', ...
            ['%s layers [%s] give a %.3f mm brick, below the minimum printable size (%.3f mm). ' ...
             'Use fewer layers.'], ax(find(bad, 1)), num2str(layers), e(find(bad, 1)) * 1e3, mp(find(bad, 1)) * 1e3);
    end

    s0 = NaN; dens = NaN; s = NaN;
    if any(free)
        smin = max(mp(free));             % free axes share one edge; it must be printable on all
        smax = min(L(free));              % coarsest: one brick across the thinnest free dimension
        if smin > smax
            error('brick_grid_from_density:TooThin', ...
                ['Minimum printable size (%.3f mm) is larger than the thinnest free domain ' ...
                 'dimension (%.3f mm); no brick fits.'], smin * 1e3, smax * 1e3);
        end
        if ~isempty(r.Size)
            s0 = r.Size;
        else
            dens = min(max(r.Density, 0), 100);
            s0 = 1 / (1/smax + dens/100 * (1/smin - 1/smax));
        end
        % fit: tune the free edge to minimize overhang, keeping it printable
        cand = unique([s0, linspace(0.9 * s0, 1.1 * s0, 401)]);
        cand = cand(cand >= smin - 1e-12 & cand <= smax + 1e-12);
        if isempty(cand), cand = min(max(s0, smin), smax); end
        best = inf;
        for c = cand
            ov = ceil(L(free) / c - 1e-6) * c - L(free);
            score = sum(ov / c) + 0.3 * abs(c - s0) / s0;
            if score < best - 1e-12, best = score; s = c; end
        end
        e(free) = s;
    end

    n  = ceil(L ./ e - 1e-6);
    n(hard) = layers(hard);
    ov = n .* e - L;
    ov(hard) = 0;
    gmin = designBBox([1 3 5]) - ov / 2;                   % centered on the domain

    grid = struct();
    grid.Size       = e;
    grid.N          = n;
    grid.Min        = gmin;
    grid.Overhang   = ov;
    grid.EdgeTarget = s0;
    grid.Density    = dens;
    grid.NumBricks  = prod(n);
    grid.MinPrintSize = mp;
    grid.Fabricable = all(e >= mp - 1e-12);
    grid.IsCubic    = max(e) - min(e) < 1e-9 * max(e);

    if r.Verbose
        fprintf('--- Brick grid ---\n');
        fprintf('  Domain:            %.2f x %.2f x %.2f mm\n', L * 1e3);
        fprintf('  Min printable:     x %.3f, y %.3f, z %.3f mm\n', mp * 1e3);
        if any(hard), fprintf('  Layers (hard):     [%s]  (0 = auto)\n', num2str(layers)); end
        if any(free) && ~isnan(dens)
            fprintf('  Density:           %.0f / 100  (target free-axis edge %.3f mm)\n', dens, s0 * 1e3);
        end
        fprintf('  Brick size (fit):  %.3f x %.3f x %.3f mm%s\n', e * 1e3, ternary(grid.IsCubic, ' (cubic)', ''));
        fprintf('  Bricks:            %d x %d x %d = %d\n', n, prod(n));
        if all(ov < 1e-9 * max(L))
            fprintf('  Fit:               exact, no overhang\n');
        else
            fprintf('  Fit:               overhang %.3f / %.3f / %.3f mm (x/y/z, split over both ends)\n', ov * 1e3);
        end
    end
end

function o = ternary(c, a, b)
    if c, o = a; else, o = b; end
end
