function S = simp_precompute(model, FilterRadius)
% SIMP_PRECOMPUTE  Everything SIMP needs that does NOT change between iterations.
%
%   S = simp_precompute(model, H)              H: the SIMP options (uses H.FilterRadius and H.Clean.MinWidth)
%   S = simp_precompute(model, FilterRadius)   a number [m]
%
%   model        : from idt_build_model
%   FilterRadius : density-filter radius R_min [m] between brick centers, or the options struct H whose
%                  FilterRadius may be 'auto' (see simp_options): 1.3 x MinWidth x brick edge, so the optimizer builds
%                  features at least as wide as the printable minimum and the clean-up has little left to remove.
%
% DESIGN VARIABLE = ONE DENSITY PER BRICK (model.NumVars of them). Every mesh element of a brick takes
% its brick's density, so the continuous SIMP design and the final solid brick layout live in the same
% space and no re-mapping is needed.
%
% Computed once:
%   - global stiffness / mass sparsity pattern (iK, jK) and the element DOF table (ed)
%   - free-DOF mask (clamped nodes removed)
%   - design elements (those whose brick is a variable): volumes, brick index ev; brick volumes
%   - the sparse, row-normalized cone filter over the bricks:  rho_t = Hf * rho
%   - the lumped extra-mass matrix
% Elements that are not design elements (holder, fixed frame, bricks locked by supports) stay solid.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    assert(model.NumVars > 0, 'simp_precompute:NoDesign', ...
        'The model has no design bricks (P.Design.Type must be ''bricks'').');
    H = [];
    if isstruct(FilterRadius), H = simp_options(FilterRadius); FilterRadius = H.FilterRadius; end
    if ischar(FilterRadius) || isstring(FilterRadius)
        FilterRadius = auto_radius(model, H);
    end
    npe = model.Npe;  nd = 3 * npe;
    Ne  = model.NumElems;  Nn = model.NumNodes;  n = 3 * Nn;

    %% global assembly pattern
    conn = model.Elem;
    ed   = reshape(permute(reshape([3*conn-2, 3*conn-1, 3*conn], [], npe, 3), [1 3 2]), [], nd)';  % nd x Ne
    iK   = reshape(repmat(ed, nd, 1), [], 1);
    jK   = reshape(repelem(ed, nd, 1), [], 1);

    %% supports
    fixedDof = reshape((3 * (model.FixedNodes - 1) + (1:3))', [], 1);
    isFree   = true(n, 1);  isFree(fixedDof) = false;

    %% design elements and their bricks
    desElems = find(model.ElemVar > 0);
    ev       = model.ElemVar(desElems);                 % brick (variable) number of each design element
    nVar     = model.NumVars;
    volDes   = model.Vol(desElems);
    volBrick = accumarray(ev, volDes, [nVar, 1]);

    %% density filter on the bricks (cone weights)
    g = model.Bricks.Grid;
    [i, j, k] = ind2sub(g.N, model.VarBricks);
    ctr = g.Min + ([i j k] - 0.5) .* g.Size;
    D2  = (ctr(:,1) - ctr(:,1)').^2 + (ctr(:,2) - ctr(:,2)').^2 + (ctr(:,3) - ctr(:,3)').^2;
    Hf  = sparse(max(0, FilterRadius - sqrt(D2)));
    Hf  = spdiags(1 ./ sum(Hf, 2), 0, nVar, nVar) * Hf;          % rows sum to 1

    %% reference matrices
    mn = model.MassNodes;
    dofsMass = reshape((3 * (mn - 1) + (1:3))', [], 1);
    Msensor  = sparse(dofsMass, dofsMass, model.ExtraMass / numel(mn), n, n);

    S = struct('npe', npe, 'nd', nd, 'Ne', Ne, 'Nn', Nn, 'n', n, 'ed', ed, 'iK', iK, 'jK', jK, ...
               'isFree', isFree, 'desElems', desElems, 'nDes', numel(desElems), 'ev', ev, ...
               'nVar', nVar, 'volDes', volDes, 'volBrick', volBrick, 'totVol', sum(volDes), ...
               'BrickCenters', ctr, 'Hf', Hf, 'FilterRadius', FilterRadius, ...
               'sK0', model.sK, 'rv0', model.Rho .* model.Vol, 'mRef', model.Mref3(:), 'Msensor', Msensor);

    fprintf('SIMP precompute: %d brick variables (%d design elements), %d free DOFs\n', nVar, S.nDes, nnz(isFree));
    fprintf('                 filter radius %.2f mm = %.2f brick edges, %.1f neighbours per brick\n', ...
        FilterRadius * 1e3, FilterRadius / min(g.Size), nnz(Hf) / nVar);
end

function R = auto_radius(model, H)
% 'auto': 1.3 x (minimum printable width in bricks) x brick edge. Measured on the example (maximize f1): 6.5 mm lost almost
% the whole result in the clean-up, 7 mm lost 30 Hz, 7.5 mm and above lost 1 to 2 Hz. Without the clean-up: 1.5 brick edges.
    edge = mean(model.Bricks.Grid.Size(1:2));          % the minimum width is measured in the layer plane (x, y), not in z
    if isempty(H) || isempty(H.Clean)
        R = 1.5 * edge;
    else
        mw = 2;
        if isfield(H.Clean, 'MinWidth'), mw = H.Clean.MinWidth; end
        R = max(1.5, 1.3 * mw) * edge;
    end
end
