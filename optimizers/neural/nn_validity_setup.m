function V = nn_validity_setup(model)
% NN_VALIDITY_SETUP  Precompute a fast, exact test for "is the load connected to the supports?".
%
%   V = nn_validity_setup(model)            then            ok = nn_is_valid(V, X)
%
% A layout is CONNECTED when the load point and the output points are linked to the clamped faces through
% material; otherwise idt_analyze reports Valid = false. That is a graph property, so it needs no
% finite-element solve: about 0.1 ms per layout instead of a second. The test follows exactly the
% connectivity rule of core/solve_frf.m (elements sharing a mesh node are connected), on a small graph:
%   - the permanent material (holder, fixed frame, locked bricks) forms a few connected pieces
%   - two design bricks are connected if their elements share a node; a brick is connected to a permanent
%     piece if it shares a node with it
%   - connected <=> the piece holding the clamped nodes and every piece holding the load or an output point
%     end up in ONE connected component once the removed bricks are deleted
%
% What it does NOT detect: HINGES. About one in five connected random layouts has parts joined only at a mesh
% node or along an edge (zero-stiffness rotation, f1 close to 0). That happens inside bricks when the mesh is not
% much finer than the bricks, so it cannot be predicted from the brick layout. The real analysis flags them
% (idt_analyze gives f1 < 1 Hz) and nn_make_dataset marks them unusable.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    nVar = model.NumVars;
    el = model.Elem;  npe = model.Npe;  Nn = model.NumNodes;
    ev = model.ElemVar;

    %% connected pieces of permanent material
    cn = el(ev == 0, :);
    G = graph(repmat(cn(:,1), npe - 1, 1), reshape(cn(:, 2:end), [], 1), [], Nn);
    comp = conncomp(G);
    used = false(Nn, 1);  used(cn(:)) = true;
    ids = unique(comp(used));
    nComp = numel(ids);
    map = zeros(1, max(comp));  map(ids) = 1:nComp;
    pieceOfNode = zeros(Nn, 1);  pieceOfNode(used) = map(comp(used));

    keyNodes = [model.FixedNodes(:); model.LoadNodes(:); model.OutNodes(:)];
    assert(all(used(keyNodes)), 'nn_validity_setup:KeyNodes', ...
        'A support / load / output node lies in a design brick; this model is not supported.');
    fixedPiece = unique(pieceOfNode(model.FixedNodes))';
    needPiece  = unique(pieceOfNode([model.LoadNodes(:); model.OutNodes(:)]))';

    %% design brick <-> node incidence (the node list is column-major, so the brick index is repeated per column)
    de = find(ev > 0);
    nodeList = el(de, :);
    Bn = sparse(nodeList(:), repmat(ev(de), npe, 1), 1, Nn, nVar) > 0;      % node x brick
    Pn = sparse(find(used), pieceOfNode(used), 1, Nn, nComp) > 0;           % node x piece

    A_bb = (double(Bn)' * double(Bn)) > 0;                                  % bricks sharing a node
    A_bb(1:nVar + 1:end) = false;
    A_bp = (double(Bn)' * double(Pn)) > 0;                                  % brick x piece

    V = struct('nVar', nVar, 'nComp', nComp, 'A_bb', A_bb, 'A_bp', A_bp, ...
               'fixedPiece', fixedPiece, 'needPiece', needPiece);
end
