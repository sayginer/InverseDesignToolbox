function ok = nn_is_valid(V, X)
% NN_IS_VALID  Fast test whether brick layouts connect the load and outputs to the supports.
%
%   ok = nn_is_valid(V, X)      V from nn_validity_setup;  X: n x nVar logical, one layout per row
%                               ok: n x 1 logical (true = connected; same rule as the solver's Valid flag)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    n = size(X, 1);
    ok = false(n, 1);
    nC = V.nComp;
    for s = 1:n
        x = X(s, :) > 0;
        A = [V.A_bb(x, x),  V.A_bp(x, :); V.A_bp(x, :)', sparse(nC, nC)];   % present bricks + permanent pieces
        c = conncomp(graph(A | A'));                      % component label of every graph node
        cp = c(nnz(x) + (1:nC));                          % ... of each permanent piece
        ok(s) = all(cp([V.needPiece V.fixedPiece]) == cp(V.fixedPiece(1)));
    end
end
