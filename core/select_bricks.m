function [X, info] = select_bricks(model, varargin)
% SELECT_BRICKS  Manually choose which bricks are present (1) or removed (0).
% Returns the vector X that solve_frf / plot_design / the optimizer use.
%
%   X = select_bricks(model)                                   all bricks present
%   X = select_bricks(model, 'Matrix', M)                      from an edited brick_matrix(model) (3-D, or a 2-D map for all layers)
%   X = select_bricks(model, 'RemoveFcn', @(x,y,z) x > 0 & y > 0)    remove by brick-center rule (m)
%   X = select_bricks(model, 'RemoveBox', [xmin xmax ymin ymax zmin zmax])  remove bricks whose center is in a box
%   X = select_bricks(model, 'RemoveIJK', [i j k; i j k])      remove bricks by grid index
%   X = select_bricks(model, 'RemoveIDs', [3 17 42])           remove by variable number (position in X)
%   X = select_bricks(model, 'KeepFcn', @(x,y,z) abs(x) < 3e-3 | abs(y) < 3e-3)   keep ONLY these (cross)
%
% Options can be combined; removals are applied after 'KeepFcn'. Bricks locked by boundary
% conditions (fixed/load/output) are never variables, so they cannot be removed.
%
% OUTPUT X (model.NumVars x 1 logical) and info: .Center (m), .IJK for every variable brick,
% .NumRemoved.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'Matrix', []);
    addParameter(p, 'RemoveFcn', []);
    addParameter(p, 'RemoveBox', []);
    addParameter(p, 'RemoveIJK', []);
    addParameter(p, 'RemoveIDs', []);
    addParameter(p, 'KeepFcn', []);
    addParameter(p, 'Verbose', true);
    parse(p, varargin{:});
    r = p.Results;

    g = model.Bricks.Grid;
    [i, j, k] = ind2sub(g.N, model.VarBricks);
    ijk = [i j k];
    ctr = g.Min + (ijk - 0.5) .* g.Size;

    X = true(model.NumVars, 1);
    if ~isempty(r.Matrix)
        M = r.Matrix;
        if ~isequal(size(M, 1:3), g.N)
            if ismatrix(M) && isequal(size(M), g.N(1:2)), M = repmat(M, 1, 1, g.N(3));   % 2-D map for all layers
            else, error('select_bricks:MatrixSize', 'Matrix must be %d x %d x %d (see brick_matrix).', g.N);
            end
        end
        v = M(model.VarBricks);
        X = X & ~(v <= 0.5);                       % 0 removes; 1 (or NaN) keeps
    end
    if ~isempty(r.KeepFcn),   X = X & logical(r.KeepFcn(ctr(:,1), ctr(:,2), ctr(:,3))); end
    if ~isempty(r.RemoveFcn), X = X & ~logical(r.RemoveFcn(ctr(:,1), ctr(:,2), ctr(:,3))); end
    if ~isempty(r.RemoveBox)
        b = r.RemoveBox;
        X = X & ~(ctr(:,1) >= b(1) & ctr(:,1) <= b(2) & ctr(:,2) >= b(3) & ctr(:,2) <= b(4) & ...
                  ctr(:,3) >= b(5) & ctr(:,3) <= b(6));
    end
    if ~isempty(r.RemoveIJK)
        X = X & ~ismember(ijk, r.RemoveIJK, 'rows');
    end
    if ~isempty(r.RemoveIDs), X(r.RemoveIDs) = false; end

    info = struct('Center', ctr, 'IJK', ijk, 'NumRemoved', nnz(~X));
    if r.Verbose
        fprintf('Brick selection: %d of %d bricks present, %d removed\n', nnz(X), numel(X), nnz(~X));
    end
end
