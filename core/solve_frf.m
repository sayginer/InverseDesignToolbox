function res = solve_frf(model, X, varargin)
% SOLVE_FRF  STEP 5 - natural frequencies and forced-vibration response of one brick layout.
%
%   res = solve_frf(model)        all bricks present
%   res = solve_frf(model, X)     X: model.NumVars entries, 1 = brick kept, 0 = removed
%   res = solve_frf(model, X, 'Transmissibility', true)   also base-excitation transmissibility
%
% 'Transmissibility' adds res.T (see transmissibility.m): the absolute response at every output
% point (x, y, z) divided by the motion of the clamped base, for base motion along x, y and z.
% It is off by default so optimizer runs pay nothing for it.
%
% Removed bricks are deleted from the mesh. Pieces that are no longer connected to a
% clamped node are dropped (res.DroppedElems). The response is computed by modal
% superposition (modal damping Zeta) with a static correction for truncated modes.
%
% OUTPUT res
%   .Valid           false if the load/output points are cut off from every support
%   .NaturalFreqs    Hz;  .Freq sweep (Hz)
%   .U               complex displacement [nOut x 3 x nFreq]  (x, y, z of each output point)
%   .Amp             abs(U)
%   .Mass, .DroppedElems, .ModalCoverage (highest kept mode / f_end, want > 1.5)
%   .Active          logical, elements present;  .Modes  [Nn x 3 x k] mode shapes (global nodes)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    t0 = tic;
    po = inputParser;
    addParameter(po, 'Transmissibility', false);
    addParameter(po, 'CheckDirect', false);       % self-test: compare against a direct solve (undamped)
    parse(po, varargin{:});
    opt = po.Results;
    if nargin < 2 || isempty(X), X = true(model.NumVars, 1); end
    X = X(:) > 0.5;
    assert(numel(X) == model.NumVars, 'X must have %d entries.', model.NumVars);
    fr = model.Freq; bc = model.BC;
    npe = model.Npe; nd = 3 * npe;
    warning('off', 'MATLAB:nearlySingularMatrix');
    warning('off', 'MATLAB:singularMatrix');
    warning('off', 'MATLAB:illConditionedMatrix');
    warning('off', 'MATLAB:eigs:IllConditionedAminusSigmaB');
    warning('off', 'MATLAB:eigs:SigmaNearExact');

    res = struct('Valid', false, 'NaturalFreqs', [], 'Freq', [], 'U', [], 'Amp', [], ...
                 'Mass', NaN, 'DroppedElems', 0, 'ModalCoverage', NaN, 'Active', [], ...
                 'Modes', [], 'SolveTime', 0, 'NumDOFs', 0);

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

    % ---- assembly -------------------------------------------------------------------------
    conn = model.Elem(eid, :);
    used = unique(conn(:));
    loc = zeros(model.NumNodes, 1); loc(used) = 1:numel(used);
    n = 3 * numel(used);
    lc = loc(conn);
    ed = reshape(permute(reshape([3*lc-2, 3*lc-1, 3*lc], [], npe, 3), [1 3 2]), [], nd)';   % nd x Ne
    iK = reshape(repmat(ed, nd, 1), [], 1);
    jK = reshape(repelem(ed, nd, 1), [], 1);
    K = sparse(iK, jK, reshape(model.sK(:, eid), [], 1), n, n);
    rv = model.Rho(eid) .* model.Vol(eid);
    M = sparse(iK, jK, reshape(model.Mref3(:) * rv', [], 1), n, n);

    mUsed = model.MassNodes(loc(model.MassNodes) > 0);
    extra = 0;
    if ~isempty(mUsed)
        dofs = reshape((3 * (loc(mUsed) - 1) + (1:3))', [], 1);
        M = M + sparse(dofs, dofs, model.ExtraMass / numel(mUsed), n, n);
        extra = model.ExtraMass;
    end
    res.Mass = sum(rv) + extra;

    % ---- constraints, load, outputs ------------------------------------------------------------
    fixedDof = reshape((3 * (loc(fixedAct) - 1) + (1:3))', [], 1);
    isFree = true(n, 1); isFree(fixedDof) = false;
    freeMap = zeros(n, 1); freeMap(isFree) = 1:nnz(isFree);
    Kf = K(isFree, isFree); Mf = M(isFree, isFree);
    nf = size(Kf, 1); res.NumDOFs = nf;

    d = bc.LoadDirection(:) / norm(bc.LoadDirection);
    F = zeros(n, 1);
    share = bc.LoadAmplitude / numel(model.LoadNodes);
    for k = 1:numel(model.LoadNodes)
        F(3 * (loc(model.LoadNodes(k)) - 1) + (1:3)) = F(3 * (loc(model.LoadNodes(k)) - 1) + (1:3)) + share * d;
    end
    Ff = F(isFree);

    nOut = numel(model.OutNodes);
    outDof = reshape((3 * (loc(model.OutNodes) - 1) + (1:3))', [], 1);
    oFree = freeMap(outDof);

    % ---- modal analysis ---------------------------------------------------------------------------------
    nm = min(fr.NModes, nf - 2);
    eigs_opts = struct('tol', 1e-4);
    [Phi, Lam] = eigs(Kf, Mf, nm, 'smallestabs', eigs_opts);
    [lam, ix] = sort(real(diag(Lam))); Phi = Phi(:, ix);
    wn = sqrt(max(lam, 0));
    Phi = Phi ./ sqrt(sum(Phi .* (Mf * Phi), 1));

    % ---- harmonic response ---------------------------------------------------------------------------------
    if isfield(fr, 'Step') && ~isempty(fr.Step) && fr.Step > 0
        freq = fr.Start : fr.Step : fr.End;
        if freq(end) < fr.End - 1e-9
            freq = [freq, fr.End];
        end
    else
        freq = linspace(fr.Start, fr.End, fr.N);
    end
    w = 2 * pi * freq;
    q = Phi' * Ff;
    ustat = Kf \ Ff;
    PhiO = zeros(numel(outDof), nm); uO = zeros(numel(outDof), 1);
    has = oFree > 0;
    PhiO(has, :) = Phi(oFree(has), :); uO(has) = ustat(oFree(has));
    resid = uO - PhiO * (q ./ wn.^2);                      % static correction for truncated modes
    U = PhiO * (q ./ (wn.^2 - w.^2 + 2i * fr.Zeta * wn .* w)) + resid;
    U = permute(reshape(U, 3, nOut, []), [2 1 3]);

    % ---- base-excitation transmissibility (optional) -----------------------------------------------------------
    % All clamped nodes move together as a rigid base with displacement u_b along direction b.
    % In coordinates relative to the base:  (K - w^2 M) u_rel = w^2 g u_b,   g = M(free,:) * r_b,
    % where r_b is a unit rigid translation along b. Absolute response / base motion:
    %   T = delta_cb + u_rel,c / u_b   (displacement, velocity and acceleration ratios are equal).
    if opt.Transmissibility
        Dn = wn.^2 - w.^2 + 2i * fr.Zeta * wn .* w;
        g = zeros(nf, 3);
        for b = 1:3
            rb = zeros(n, 1); rb(b:3:end) = 1;
            g(:, b) = M(isFree, :) * rb;
        end
        Gam = Phi' * g;                                    % modal participation, nm x 3
        us = Kf \ g;                                       % static solutions for the residual correction
        T = zeros(nOut, 3, 3, numel(freq));
        for b = 1:3
            uOb = zeros(numel(outDof), 1); uOb(has) = us(oFree(has), b);
            residb = uOb - PhiO * (Gam(:, b) ./ wn.^2);
            Urel = PhiO * (Gam(:, b) .* w.^2 ./ Dn) + residb .* w.^2;
            Urel = permute(reshape(Urel, 3, nOut, []), [2 1 3]);       % out x comp x freq
            Urel(:, b, :) = Urel(:, b, :) + 1;                         % the base's own motion
            T(:, :, b, :) = Urel;
        end
        res.T = T;                                         % [nOut x 3 (response) x 3 (base direction) x nFreq]
        res.TAmp = abs(T);

        if opt.CheckDirect                                 % undamped modal vs direct solve at 3 frequencies
            fchk = freq(round(linspace(1, numel(freq), 3))); err = 0;
            for fc = fchk
                wc = 2 * pi * fc;
                for b = 1:3
                    u = (Kf - wc^2 * Mf) \ (wc^2 * g(:, b));
                    uo = zeros(numel(outDof), 1); uo(has) = u(oFree(has));
                    Dz = wn.^2 - wc^2;
                    um = PhiO * (Gam(:, b) .* wc^2 ./ Dz) + (uOb_of(us, b, oFree, has, numel(outDof)) - PhiO * (Gam(:, b) ./ wn.^2)) * wc^2;
                    err = max(err, norm(um - uo) / max(norm(uo), eps));
                end
            end
            res.TransmissibilityCheckError = err;
        end
    end

    % ---- mode shapes on global node numbering -----------------------------------------------------------------
    ns = min(model.StoreModes, nm);
    Modes = zeros(model.NumNodes, 3, ns);
    for k = 1:ns
        full = zeros(n, 1); full(isFree) = Phi(:, k);
        Modes(used, :, k) = reshape(full, 3, [])';
    end

    res.Valid = true;
    res.NaturalFreqs = wn / (2 * pi);
    res.Freq = freq; res.U = U; res.Amp = abs(U);
    res.ModalCoverage = res.NaturalFreqs(end) / fr.End;
    res.Modes = Modes;
    res.SolveTime = toc(t0);
end

function uo = uOb_of(us, b, oFree, has, nDof)
% static solution of base direction b at the output dofs
    uo = zeros(nDof, 1); uo(has) = us(oFree(has), b);
end
