function bricks = create_bricks(geom, varargin)
% CREATE_BRICKS  STEP 2 - brick ONLY the domain you want to optimize.
%
% Bricks are a SELECTION mechanism: each brick is a switch that keeps or removes
% the mesh elements inside it. They do not define the mesh.
%
%   bricks = create_bricks(geom, 'DesignPart', 2, 'MinPrintSize', 1e-3, 'Density', 25)
%   bricks = create_bricks(geom, 'Box', [xmin xmax ymin ymax zmin zmax], 'MinPrintSize', 1e-3, 'Density', 40)
%
%   'DesignPart'   index of the imported part to brick (its bounding box is gridded)
%   'Box'          alternatively, any box in meters (elements of ALL parts inside it
%                  become switchable)
%   'MinPrintSize' smallest printable size (m);  'Density' 0..100 (100 = smallest brick)
%   'Layers'       optional hard layer counts [nx ny nz], 0 = auto
%   'MinFill'      (part mode) a brick must be at least this full of design material
%                  to be a brick (default 0.5). Thin slivers are not bricks.
%   'MaxOverlap'   (part mode) a brick may overlap other parts (e.g. a holder and its holes)
%                  by at most this fraction of its volume (default 0 = no overlap).
%
% Grid cells that fail MinFill / MaxOverlap are NOT bricks: they are not drawn and not
% optimization variables. The design material inside them stays solid.
% See brick_grid_from_density.m for how density and layers set the brick size.
%
% OUTPUT bricks: .Grid, .Present (logical N: true = a real, switchable brick),
%   .Fill (fraction of design material), .Overlap (fraction inside other parts),
%   .NumPresent, .NumExcluded
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser; p.KeepUnmatched = true;
    addParameter(p, 'DesignPart', []);
    addParameter(p, 'Box', []);
    addParameter(p, 'MinFill', 0.5);
    addParameter(p, 'MaxOverlap', 0);
    parse(p, varargin{:});
    rest = namedargs2cell(p.Unmatched);

    if ~isempty(p.Results.DesignPart)
        mode = 'part'; ip = p.Results.DesignPart;
        bb = geom.Parts(ip).BBox; name = geom.Parts(ip).Name;
    elseif ~isempty(p.Results.Box)
        mode = 'box'; ip = []; bb = p.Results.Box; name = 'user box';
    else
        error('create_bricks:NoDomain', 'Give ''DesignPart'' or ''Box''.');
    end

    grid = brick_grid_from_density(bb, rest{:});
    N = grid.N; bs = grid.Size;

    present = true(N); fill = ones(N); overlap = zeros(N); nExcl = 0;
    if strcmp(mode, 'part')
        S = 4; offs = ((1:S) - 0.5) / S - 0.5;
        [ox, oy, oz] = ndgrid(offs, offs, offs); O = [ox(:) oy(:) oz(:)];
        [I, J, K] = ndgrid(1:N(1), 1:N(2), 1:N(3));
        C = grid.Min + ([I(:) J(:) K(:)] - 0.5) .* bs;

        inside = @(part) sampleFraction(part, C, O, bs);
        fill = reshape(inside(geom.Parts(ip)), N);            % design material in each cell
        ov = zeros(size(C, 1), 1);
        for q = setdiff(1:numel(geom.Parts), ip)              % material of the OTHER parts
            ov = max(ov, inside(geom.Parts(q)));
        end
        overlap = reshape(ov, N);

        hasMat = fill > 0;
        present = fill >= p.Results.MinFill & overlap <= p.Results.MaxOverlap + 1e-9;
        nExcl = nnz(hasMat & ~present);
    end

    bricks = struct('Mode', mode, 'DesignPart', ip, 'Box', bb, 'Name', name, ...
                    'Grid', grid, 'Present', present, 'Fill', fill, 'Overlap', overlap, ...
                    'NumPresent', nnz(present), 'NumExcluded', nExcl);
    fprintf('  Bricks: %d (cells with design material excluded for sliver/overlap: %d)\n\n', ...
        bricks.NumPresent, nExcl);
end

function f = sampleFraction(part, C, O, bs)
% fraction of each cell's sample points that lie inside the part's solid
    TR = triangulation(part.Tets, part.Nodes);
    f = zeros(size(C, 1), 1);
    for s = 1:size(O, 1), f = f + ~isnan(pointLocation(TR, C + O(s, :) .* bs)); end
    f = f / size(O, 1);
end
