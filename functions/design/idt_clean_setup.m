function C = idt_clean_setup(model, minSharedNodes)
% IDT_CLEAN_SETUP  Precompute what idt_clean_bricks needs (once per model).
%
%   C = idt_clean_setup(model)
%   C = idt_clean_setup(model, minSharedNodes)       default 4
%
% Finds, for every design brick, whether it is ANCHORED to the supports (it shares a face patch of at least
% minSharedNodes mesh nodes with the permanent material that holds the clamped nodes) and whether it is anchored
% to the load side (same test against the piece holding the load and output points). A face contact shares many
% nodes, an edge or corner contact only one or two, so the threshold separates real attachment from hinges.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 2, minSharedNodes = 4; end
    nVar = model.NumVars;
    el = model.Elem;  npe = model.Npe;  Nn = model.NumNodes;
    ev = model.ElemVar;

    cn = el(ev == 0, :);
    G = graph(repmat(cn(:,1), npe - 1, 1), reshape(cn(:, 2:end), [], 1), [], Nn);
    comp = conncomp(G);
    used = false(Nn, 1);  used(cn(:)) = true;
    ids = unique(comp(used));
    nComp = numel(ids);
    map = zeros(1, max(comp));  map(ids) = 1:nComp;
    pieceOfNode = zeros(Nn, 1);  pieceOfNode(used) = map(comp(used));
    fixedPiece = unique(pieceOfNode(model.FixedNodes))';
    needPiece  = unique(pieceOfNode([model.LoadNodes(:); model.OutNodes(:)]))';

    de = find(ev > 0);
    nodeList = el(de, :);
    Bn = sparse(nodeList(:), repmat(ev(de), npe, 1), 1, Nn, nVar) > 0;      % node x brick
    Pn = sparse(find(used), pieceOfNode(used), 1, Nn, nComp) > 0;           % node x piece
    cnt = double(Bn)' * double(Pn);                                         % brick x piece: shared nodes

    g = model.Bricks.Grid;
    isVar = false(g.N);  isVar(model.VarBricks) = true;
    lin2var = zeros(g.N);  lin2var(model.VarBricks) = 1:nVar;
    C = struct('N', g.N, 'varBricks', model.VarBricks, 'nVar', nVar, 'present', model.Bricks.Present, ...
               'isVar', isVar, 'lin2var', lin2var, ...
               'touchSupport', any(cnt(:, fixedPiece) >= minSharedNodes, 2), ...
               'touchLoad',    any(cnt(:, needPiece)  >= minSharedNodes, 2), ...
               'minSharedNodes', minSharedNodes);
end
