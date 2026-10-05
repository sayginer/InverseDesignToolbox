function M = brick_matrix(model, M)
% BRICK_MATRIX  Selection matrix over the brick grid: edit it by hand, then pass it to
% select_bricks(model, 'Matrix', M).
%
%   M = brick_matrix(model);       % template: 1 = brick present, NaN = grid cell that is not a brick
%   M(5:8, :, :) = 0;              % set bricks to 0 to remove them (indices: M(ix, iy, iz))
%   brick_matrix(model, M);        % print the layer maps to check your edits
%   X = select_bricks(model, 'Matrix', M);
%
% M has size [nx ny nz] of the brick grid; ix, iy, iz count along x, y, z from the minimum
% corner. Only cells that are real bricks (value 1/0) matter; NaN cells are ignored.
% Printed maps: '#' present, '.' removed, ' ' not a brick. Rows = y (top = max y), columns = x.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 2
        M = nan(model.Bricks.Grid.N);
        M(model.VarBricks) = 1;
        return;
    end

    N = size(M, 3);
    for k = 1:N
        fprintf('Layer z = %d of %d\n', k, N);
        L = M(:, :, k)';                          % rows = y, columns = x
        for row = size(L, 1):-1:1
            s = repmat(' ', 1, size(L, 2));
            s(L(row, :) > 0.5) = '#';
            s(L(row, :) <= 0.5) = '.';
            s(isnan(L(row, :))) = ' ';
            fprintf('  %s\n', s);
        end
    end
end
