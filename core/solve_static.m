function res = solve_static(model, X)
% SOLVE_STATIC  Linear static deflection and stress of one brick layout under a constant load.
%
%   res = solve_static(model)        all bricks present
%   res = solve_static(model, X)     X: model.NumVars entries, 1 = brick kept, 0 = removed
%
% Same element matrices, same brick -> element rule and same "drop floating pieces" rule as
% solve_frf, but the load is a constant force (bc.LoadAmplitude [N] along bc.LoadDirection,
% shared equally by the load nodes) and the equation is  K u = F.  No eigenproblem, no damping.
%
% OUTPUT res
%   .Valid        false if the load / output points are cut off from every support, or if the layout is a mechanism
%   .Mechanism    true if K is singular: pieces joined only along an edge or at a corner can rotate freely
%   .U            [NumNodes x 3] displacement (m), zero at nodes of removed or dropped elements
%   .UMag         [NumNodes x 1] displacement magnitude (m)
%   .VonMises     [NumElems x 1] von Mises stress (Pa) at the element centroid, NaN where inactive
%   .Stress       [NumElems x 6] centroid stress sxx syy szz sxy syz sxz (Pa)
%   .OutU         [nOut x 3] displacement at the output points (m)
%   .Compliance   F'u  (J): force times the movement it causes, twice the strain energy; smaller = stiffer
%   .Reaction     [1 x 3] sum of the support reactions (N); equals -F, a check of the solve
%   .Mass, .DroppedElems, .Active, .NumDOFs, .SolveTime
%
% For TET10 meshes the stress is evaluated at the element centroid with the quadratic shape
% functions; for TET4 it is the (constant) element stress.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    t0 = tic;
    if nargin < 2 || isempty(X), X = true(model.NumVars, 1); end
    Xraw = X(:);  X = Xraw > 0.5;
    assert(numel(X) == model.NumVars, 'X must have %d entries.', model.NumVars);
    npe = model.Npe; nd = 3 * npe; bc = model.BC;

    res = struct('Valid', false, 'U', [], 'UMag', [], 'VonMises', [], 'Stress', [], 'OutU', [], ...
                 'Compliance', NaN, 'Reaction', nan(1, 3), 'Mass', NaN, 'DroppedElems', 0, 'Mechanism', false, ...
                 'Active', [], 'NumDOFs', 0, 'SolveTime', 0);

    % ---- active elements; remove floating pieces -----------------------------------
    ev = model.ElemVar;
    act = ev == 0;
    act(ev > 0) = X(ev(ev > 0));
    nAct = nnz(act);
    cn = model.Elem(act, :);
    G = graph(repmat(cn(:,1), npe - 1, 1), reshape(cn(:, 2:end), [], 1), [], model.NumNodes);
    comp = conncomp(G);
    fixedAct = model.FixedNodes(ismember(model.FixedNodes, cn(:)));
    if isempty(fixedAct), res.SolveTime = toc(t0); return; end
    keepComp = unique(comp(fixedAct));
    keepE = ismember(comp(cn(:,1)), keepComp);
    if ~all(ismember(comp([model.LoadNodes; model.OutNodes]), keepComp))
        res.SolveTime = toc(t0); return;
    end
    eid = find(act); eid = eid(keepE);
    res.DroppedElems = nAct - numel(eid);
    res.Active = false(model.NumElems, 1); res.Active(eid) = true;

    % ---- assembly ---------------------------------------------------------------------
    conn = model.Elem(eid, :);
    used = unique(conn(:));
    loc = zeros(model.NumNodes, 1); loc(used) = 1:numel(used);
    n = 3 * numel(used);
    lc = loc(conn);
    ed = reshape(permute(reshape([3*lc-2, 3*lc-1, 3*lc], [], npe, 3), [1 3 2]), [], nd)';   % nd x Ne
    iK = reshape(repmat(ed, nd, 1), [], 1);
    jK = reshape(repelem(ed, nd, 1), [], 1);
    K = sparse(iK, jK, reshape(model.sK(:, eid), [], 1), n, n);
    res.Mass = sum(model.Rho(eid) .* model.Vol(eid));

    % ---- supports and load -------------------------------------------------------------
    fixedDof = reshape((3 * (loc(fixedAct) - 1) + (1:3))', [], 1);
    isFree = true(n, 1); isFree(fixedDof) = false;
    d = bc.LoadDirection(:) / norm(bc.LoadDirection);
    F = zeros(n, 1);
    share = bc.LoadAmplitude / numel(model.LoadNodes);
    for k = 1:numel(model.LoadNodes)
        idx = 3 * (loc(model.LoadNodes(k)) - 1) + (1:3);
        F(idx) = F(idx) + share * d;
    end
    res.NumDOFs = nnz(isFree);

    % ---- solve ----------------------------------------------------------------------------
    u = zeros(n, 1);
    % A layout whose pieces touch only along an edge or at a corner is a MECHANISM (it can rotate about the contact): K is
    % singular and the "answer" is meaningless. MATLAB's singularity warnings are turned into errors here to catch it.
    ws = [warning('error', 'MATLAB:nearlySingularMatrix'), warning('error', 'MATLAB:singularMatrix')];
    cleanup = onCleanup(@() warning(ws));
    try
        u(isFree) = K(isFree, isFree) \ F(isFree);
    catch ME
        if contains(ME.identifier, 'ingularMatrix')
            res.Mechanism = true;  res.SolveTime = toc(t0);
            return;                                           % res.Valid stays false
        end
        rethrow(ME);
    end
    clear cleanup;
    res.Compliance = F' * u;
    r = K * u - F;                                         % residual force = support reaction at the fixed dofs
    res.Reaction = [sum(r(1:3:end)), sum(r(2:3:end)), sum(r(3:3:end))];

    U = zeros(model.NumNodes, 3);
    U(used, :) = reshape(u, 3, [])';
    res.U = U;
    res.UMag = sqrt(sum(U.^2, 2));
    res.OutU = U(model.OutNodes, :);

    % ---- stress at the element centroids -------------------------------------------------
    S = nan(model.NumElems, 6);
    S(eid, :) = centroid_stress(model, eid, U);
    res.Stress = S;
    res.VonMises = sqrt(0.5 * ((S(:,1) - S(:,2)).^2 + (S(:,2) - S(:,3)).^2 + (S(:,3) - S(:,1)).^2) ...
                        + 3 * (S(:,4).^2 + S(:,5).^2 + S(:,6).^2));

    res.Valid = true;
    res.SolveTime = toc(t0);
end

function S = centroid_stress(model, eid, U)
% Isotropic linear-elastic stress at the centroid of the elements eid, from the nodal displacements U.
    npe = model.Npe;
    nodes = model.Nodes; el = model.Elem(eid, :);
    Ne = numel(eid);
    Xe = zeros(Ne, npe, 3); Ue = zeros(Ne, npe, 3);
    for c = 1:3
        Xe(:, :, c) = reshape(nodes(el(:), c), Ne, npe);
        Ue(:, :, c) = reshape(U(el(:), c), Ne, npe);
    end

    % shape-function derivatives w.r.t. the reference coordinates at the centroid (L = 1/4 each)
    dN = centroid_dN(npe);                                 % 3 x npe
    J = zeros(Ne, 3, 3);                                   % J(:,a,b) = d x_b / d xi_a
    for a = 1:3
        for b = 1:3, J(:, a, b) = Xe(:, :, b) * dN(a, :)'; end
    end
    j1 = squeeze(J(:, 1, :)); j2 = squeeze(J(:, 2, :)); j3 = squeeze(J(:, 3, :));
    detJ = sum(j1 .* cross(j2, j3, 2), 2);
    Ji = cat(3, cross(j2, j3, 2), cross(j3, j1, 2), cross(j1, j2, 2)) ./ detJ;   % Ji(:,k,a) = d xi_a / d x_k
    gr = cell(1, 3);                                       % gradients of the shape functions, Ne x npe
    for k = 1:3
        gr{k} = Ji(:, k, 1) * dN(1, :) + Ji(:, k, 2) * dN(2, :) + Ji(:, k, 3) * dN(3, :);
    end
    g = zeros(Ne, 3, 3);                                   % g(:,i,k) = d u_i / d x_k
    for i = 1:3
        for k = 1:3, g(:, i, k) = sum(gr{k} .* Ue(:, :, i), 2); end
    end

    % material of every element: part -> E, nu
    nuPart = zeros(1, numel(model.Geom.Parts));
    for ip = 1:numel(nuPart), nuPart(ip) = get_material_properties(model.Geom.Parts(ip).Material).nu; end
    nu = nuPart(model.Tag(eid))'; E = model.E(eid);
    lam = E .* nu ./ ((1 + nu) .* (1 - 2*nu));
    mu = E ./ (2 * (1 + nu));
    exx = g(:,1,1); eyy = g(:,2,2); ezz = g(:,3,3);
    tr = exx + eyy + ezz;
    S = [lam .* tr + 2*mu .* exx, lam .* tr + 2*mu .* eyy, lam .* tr + 2*mu .* ezz, ...
         mu .* (g(:,1,2) + g(:,2,1)), mu .* (g(:,2,3) + g(:,3,2)), mu .* (g(:,1,3) + g(:,3,1))];
end

function dN = centroid_dN(npe)
% d N_n / d(xi,eta,zeta) at the centroid (volume coordinates 1/4 each); node order as in tet_element_matrices.
    dL = [-1 -1 -1; 1 0 0; 0 1 0; 0 0 1];
    L = [0.25 0.25 0.25 0.25];
    if npe == 4
        dN = dL';
        return;
    end
    pairs = [1 2; 2 3; 1 3; 1 4; 2 4; 3 4];
    dNdL = zeros(10, 4);
    for i = 1:4, dNdL(i, i) = 4*L(i) - 1; end
    for k = 1:6
        a = pairs(k, 1); b = pairs(k, 2);
        dNdL(4+k, a) = 4 * L(b);
        dNdL(4+k, b) = 4 * L(a);
    end
    dN = (dNdL * dL)';
end
