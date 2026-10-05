function [Xc, rep] = idt_clean_bricks(C, X, opt)
% IDT_CLEAN_BRICKS  Make a brick layout printable: no checkerboards, no islands, no thin or hinged features.
%
%   [Xc, rep] = idt_clean_bricks(C, X)            C from idt_clean_setup;  X: nVar x 1 logical (one layout)
%   [Xc, rep] = idt_clean_bricks(C, X, opt)       opt: struct with any of the fields below
%   Xc = idt_clean_bricks(C, Xmat)                Xmat: n x nVar, one layout per row; Xc has the same shape
%
% Steps (Image Processing Toolbox on the brick grid; cells that are not design bricks count as solid material):
%   1. close gaps      imclose with a square of opt.CloseGaps bricks, layer by layer: fills one-brick gaps and holes
%   2. thin features   imopen with a square of opt.MinWidth bricks, layer by layer: removes everything narrower than that
%   3. overhangs       opt.Overhang = true removes bricks that have no solid brick (or non-design material) below them
%   4. connectivity    bwconncomp with FACE connectivity (6-neighbourhood): bricks touching only along an edge or
%                      corner do not count as connected (that is a checkerboard / hinge). Keep the groups per opt.KeepOnly.
%   5. diagonals       two solid bricks meeting only along an edge (a 2x2 checkerboard in any plane) make a non-manifold
%                      edge that STL slicers reject; one void cell of each such pattern is filled. The same for a contact
%                      at a single corner (a non-manifold vertex, which CAD kernels cannot represent): the void cells of
%                      that 2x2x2 window are filled. Steps 4 and 5 repeat until neither changes anything.
%
% opt fields (defaults)
%   MinWidth  2          smallest allowed feature width in bricks (in the layer plane). 1 = no thin-feature removal
%   CloseGaps 2          gaps up to CloseGaps-1 bricks wide are filled. 1 = no gap closing
%   Overhang  false      true: remove bricks without support below (print from the bottom layer up)
%   KeepOnly  'loadpath' 'loadpath': keep only groups that touch BOTH the supports and the load side (no dead ends)
%                        'attached': keep groups touching either one | 'all': only remove checkerboards and thin parts
%
% rep (single layout): .removed, .added (brick counts), .pieces (face-connected groups before / after),
%   .LoadPath (true if a face-connected path joins the supports and the load side). If the cleaning would
%   destroy the load path, the layout is returned as it was and rep.Reverted = true.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 3, opt = struct(); end
    D = struct('MinWidth', 2, 'CloseGaps', 2, 'Overhang', false, 'KeepOnly', 'loadpath');
    opt = idt_fill_defaults(opt, D);

    if size(X, 1) ~= C.nVar || size(X, 2) > 1        % several layouts: one per row
        if size(X, 2) ~= C.nVar, error('idt_clean_bricks:Size', 'X must have %d entries per layout.', C.nVar); end
        Xc = false(size(X));
        for s = 1:size(X, 1), Xc(s, :) = clean_one(C, X(s, :)', opt)'; end
        rep = [];
        return;
    end
    [Xc, rep] = clean_one(C, X(:), opt);
end

function [xc, rep] = clean_one(C, x, opt)
    N = C.N;
    Ad = false(N);  Ad(C.varBricks) = x > 0;
    solidOther = ~C.isVar;                             % holder, permanent and locked bricks: count as solid
    Aorig = Ad;
    nPiecesBefore = bwconncomp(Ad, 6).NumObjects;

    % 1. close gaps, 2. remove thin features (layer by layer; only design bricks can change)
    S = Ad | solidOther;
    if opt.CloseGaps > 1
        se = strel('square', opt.CloseGaps);
        for k = 1:N(3), S(:, :, k) = imclose(S(:, :, k), se); end
        Ad = Ad | (S & C.isVar);
    end
    if opt.MinWidth > 1
        S = Ad | solidOther;
        se = strel('square', opt.MinWidth);
        for k = 1:N(3), S(:, :, k) = imopen(S(:, :, k), se); end
        Ad = Ad & S;
    end

    % 3. overhangs: a brick needs solid material below it
    if opt.Overhang
        for k = 2:N(3)
            below = Ad(:, :, k - 1) | ~C.isVar(:, :, k - 1);
            Ad(:, :, k) = Ad(:, :, k) & below;
        end
    end

    % 4. face connectivity: keep only groups attached as requested; 5. no diagonal-only contacts (non-manifold edges).
    %    Removing a group can create a new diagonal contact, so repeat until both hold.
    for pass = 1:4
        Ad = fix_diagonals(C, Ad);
        Ad = fix_vertices(C, Ad);
        [Ad, loadPath, nPiecesAfter] = keep_groups(C, Ad, opt.KeepOnly);
        if ~has_diagonals(C, Ad) && ~any(bad_windows(C, Ad), 'all'), break; end
    end

    xc = Ad(C.varBricks);
    reverted = false;
    if ~loadPath
        [~, lpOrig] = keep_groups(C, Aorig, 'loadpath');
        if lpOrig                                      % cleaning broke a connection that existed: keep the original
            xc = Aorig(C.varBricks);  reverted = true;  loadPath = true;
        end
    end
    rep = struct('removed', nnz(x & ~xc), 'added', nnz(~x & xc), 'pieces', [nPiecesBefore nPiecesAfter], ...
                 'LoadPath', loadPath, 'Reverted', reverted);
end

function Ad = fix_diagonals(C, Ad)
% Two solid bricks that meet only along an edge (a 2x2 checkerboard in any of the three planes, with void in the other
% two cells) make a non-manifold edge: not a valid solid for slicers. Fill one void cell of every such pattern.
    for it = 1:20
        changed = false;
        for ax = 1:3
            perm = [setdiff(1:3, ax) ax];
            S = permute(Ad | ~C.isVar, perm);  A = permute(Ad, perm);
            P = S(1:end-1, 1:end-1, :);  Q = S(2:end, 1:end-1, :);
            R = S(1:end-1, 2:end, :);    T = S(2:end, 2:end, :);
            pa = find(P & T & ~Q & ~R);                   % solid on one diagonal: fill Q
            pb = find(Q & R & ~P & ~T);                   % solid on the other diagonal: fill P
            sz = size(P);
            for q = 1:numel(pa)
                [i, j, k] = ind2sub(sz, pa(q));  A(i + 1, j, k) = true;  changed = true;
            end
            for q = 1:numel(pb)
                [i, j, k] = ind2sub(sz, pb(q));  A(i, j, k) = true;  changed = true;
            end
            Ad = ipermute(A, perm);
        end
        if ~changed, break; end
    end
end

function Ad = fix_vertices(C, Ad)
% Two solid bricks that meet only at a corner (or a window whose void part is split) make a non-manifold vertex, which
% CAD kernels cannot represent. Every bad 2x2x2 window gets its void cells filled.
    for it = 1:20
        bad = bad_windows(C, Ad);
        if ~any(bad, 'all'), break; end
        S = Ad | ~C.isVar;
        for q = find(bad(:))'
            [i, j, k] = ind2sub(size(bad), q);
            blk = S(i:i + 1, j:j + 1, k:k + 1);
            A = Ad(i:i + 1, j:j + 1, k:k + 1);
            Ad(i:i + 1, j:j + 1, k:k + 1) = A | ~blk;       % the void cells are design bricks: fill them
        end
    end
end

function bad = bad_windows(C, Ad)
% true for every 2x2x2 window of the solid / void grid whose solid part or void part is not face-connected
    persistent lut
    if isempty(lut)
        lut = false(1, 256);
        for code = 1:254
            b = reshape(bitget(code, 1:8), [2 2 2]) > 0;
            lut(code + 1) = bwconncomp(b, 6).NumObjects > 1 || bwconncomp(~b, 6).NumObjects > 1;
        end
    end
    S = Ad | ~C.isVar;
    w = zeros(C.N - 1);
    for dx = 0:1
        for dy = 0:1
            for dz = 0:1
                w = w + double(S(1 + dx:end - 1 + dx, 1 + dy:end - 1 + dy, 1 + dz:end - 1 + dz)) * 2^(dx + 2 * dy + 4 * dz);
            end
        end
    end
    bad = lut(w + 1);
end

function tf = has_diagonals(C, Ad)
    tf = false;
    for ax = 1:3
        perm = [setdiff(1:3, ax) ax];
        S = permute(Ad | ~C.isVar, perm);
        P = S(1:end-1, 1:end-1, :);  Q = S(2:end, 1:end-1, :);
        R = S(1:end-1, 2:end, :);    T = S(2:end, 2:end, :);
        if any(P & T & ~Q & ~R, 'all') || any(Q & R & ~P & ~T, 'all'), tf = true; return; end
    end
end

function [Ad, loadPath, nPieces] = keep_groups(C, Ad, keepOnly)
    cc = bwconncomp(Ad, 6);
    nPieces = cc.NumObjects;
    keep = false(size(Ad));
    loadPath = false;
    for q = 1:cc.NumObjects
        v = C.lin2var(cc.PixelIdxList{q});
        sup = any(C.touchSupport(v));  lod = any(C.touchLoad(v));
        both = sup && lod;
        loadPath = loadPath || both;
        switch keepOnly
            case 'loadpath', ok = both;
            case 'attached', ok = sup || lod;
            otherwise,       ok = true;
        end
        if ok, keep(cc.PixelIdxList{q}) = true; end
    end
    Ad = keep;
    if ~strcmp(keepOnly, 'loadpath') || nPieces == 0, return; end
end
