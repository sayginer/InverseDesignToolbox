function M = idt_select_bricks(bricks, varargin)
% IDT_SELECT_BRICKS  Choose which bricks are present, on the brick grid, BEFORE meshing.
%
%   M = idt_select_bricks(bricks)                                   all bricks present
%   M = idt_select_bricks(bricks, 'KeepFcn',   @(x,y,z) abs(x) < 3e-3 | abs(y) < 3e-3)   keep ONLY these (a cross)
%   M = idt_select_bricks(bricks, 'RemoveFcn', @(x,y,z) x > 0 & y > 0)                   remove by rule
%   M = idt_select_bricks(bricks, 'RemoveBox', [xmin xmax ymin ymax zmin zmax])          remove bricks centered in a box
%   M = idt_select_bricks(bricks, 'RemoveIJK', [i j k; i j k])                           remove by grid index
%   M = idt_select_bricks(bricks, 'Matrix', M0)                                          start from an edited matrix
%
%   bricks : result of idt_make_bricks.   x, y, z are brick-center coordinates [m].
%
% OUTPUT M  [nx ny nz]:  1 = brick present, 0 = brick removed, NaN = grid cell that is not a brick.
% Indices ix, iy, iz count from the minimum corner along x, y, z. You can edit M by hand
% (M(5:8, :, 1) = 0) and pass it back with 'Matrix'. Options can be combined; removals are applied
% after 'KeepFcn'. Print the layer maps with brick_matrix([], M).
%
% Preview with idt_plot_brick_selection(geom, bricks, M). Later, when the model exists,
%   X = select_bricks(model, 'Matrix', M)
% turns M into the design vector (bricks locked by supports / load / outputs stay solid).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'Matrix', []);
    addParameter(p, 'KeepFcn', []);
    addParameter(p, 'RemoveFcn', []);
    addParameter(p, 'RemoveBox', []);
    addParameter(p, 'RemoveIJK', []);
    parse(p, varargin{:});
    r = p.Results;

    g = bricks.Grid;
    present = find(bricks.Present);
    [i, j, k] = ind2sub(g.N, present);
    ijk = [i j k];
    ctr = g.Min + (ijk - 0.5) .* g.Size;

    keep = true(numel(present), 1);
    if ~isempty(r.Matrix)
        assert(isequal(size(r.Matrix, 1:3), g.N), 'idt_select_bricks:MatrixSize', ...
            'Matrix must be %d x %d x %d (see brick_matrix).', g.N);
        keep = keep & ~(r.Matrix(present) <= 0.5);
    end
    if ~isempty(r.KeepFcn),   keep = keep & logical(r.KeepFcn(ctr(:,1), ctr(:,2), ctr(:,3))); end
    if ~isempty(r.RemoveFcn), keep = keep & ~logical(r.RemoveFcn(ctr(:,1), ctr(:,2), ctr(:,3))); end
    if ~isempty(r.RemoveBox)
        b = r.RemoveBox;
        keep = keep & ~(ctr(:,1) >= b(1) & ctr(:,1) <= b(2) & ctr(:,2) >= b(3) & ctr(:,2) <= b(4) & ...
                        ctr(:,3) >= b(5) & ctr(:,3) <= b(6));
    end
    if ~isempty(r.RemoveIJK), keep = keep & ~ismember(ijk, r.RemoveIJK, 'rows'); end

    M = nan(g.N);
    M(present) = double(keep);
    fprintf('Brick selection: %d of %d bricks present, %d removed\n', nnz(keep), numel(keep), nnz(~keep));
end
