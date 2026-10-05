function A = nn_encode(sur, X)
% NN_ENCODE  Turn brick layouts into the input array of the network.
%
%   A = nn_encode(sur, X)        X: n x nVar logical (one layout per row)
%
%   'cnn': 5-D array [nx ny nz 2 n]: channel 1 = brick present, channel 2 = this grid cell is a design brick
%   'mlp': n x nVar single matrix
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    X = single(X);
    if strcmp(sur.kind, 'mlp'), A = X; return; end
    n = size(X, 1);
    A = zeros([sur.gridN 2 n], 'single');
    mask = zeros(sur.gridN, 'single');  mask(sur.varBricks) = 1;
    for s = 1:n
        c1 = zeros(sur.gridN, 'single');  c1(sur.varBricks) = X(s, :);
        A(:, :, :, 1, s) = c1;
        A(:, :, :, 2, s) = mask;
    end
end
