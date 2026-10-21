function out = static_simp_optimize(model, S)
% STATIC_SIMP_OPTIMIZE  SIMP topology optimization of the brick layout for static stiffness. No figures.
%
%   out = static_simp_optimize(model, S)       model: from idt_build_model (P.Analysis.Type = 'Static')
%                                              S: from static_options ([] = defaults)
%
% Minimizes the compliance c = F'u  (= maximizes the stiffness) for a volume limit:
%   min c(rho)   s.t.  K(rho) u = F,   sum(rho_b V_b) <= VolMax * sum(V_b),   0 <= rho <= 1
% One density rho per design brick. A brick scales the stiffness of its elements by Emin + (1-Emin) rho^p.
% Densities are smoothed by a distance filter on the brick grid (no checkerboards) and updated with the
% optimality-criteria rule (bisection on the volume). Gradients are analytic (self-adjoint problem):
%   dc/drho_b = - p rho^(p-1) (1-Emin) * sum over the brick's elements of  u_e' K_e u_e
% Bricks locked by supports / load / outputs and all non-design elements stay solid.
%
% At the end the densities are thresholded so the volume limit holds, optionally cleaned, and the result is
% analysed with the REAL analysis (removed bricks are deleted from the mesh).
%
% OUTPUT out: .X (0/1 layout, one entry per design brick), .M (brick matrix for idt_plot_brick_selection),
%   .Rho (final filtered densities), .met, .res (idt_analyze of X), .History (.Compliance, .Volume, .Change),
%   .Iterations, .TotalTime, .Grayness (share of bricks with 0.1 < rho < 0.9), .S
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    S = static_options(S);
    tAll = tic;
    nVar = model.NumVars;
    assert(nVar > 0, 'static_simp_optimize:NoDesign', 'The model has no design bricks.');
    assert(strcmp(model.Params.Analysis.Type, 'Static'), 'static_simp_optimize:Type', ...
        'Set P.Analysis.Type = ''Static'' before building the model.');
    assert(strcmp(S.Objective, 'MinCompliance'), 'static_simp_optimize:Objective', ...
        'SIMP minimizes the compliance; use static_ga_optimize for ''MinMass''.');
    npe = model.Npe; nd = 3 * npe; Ne = model.NumElems;
    ev = model.ElemVar;  isDes = ev > 0;
    volBrick = accumarray(ev(isDes), model.Vol(isDes), [nVar, 1]);
    volTot = sum(volBrick);

    % ---- filter on the brick grid -------------------------------------------------------------
    g = model.Bricks.Grid;
    R = S.FilterRadius;  if isempty(R), R = 1.5 * median(g.Size); end   % median: ignores a single thick layer direction
    [i, j, k] = ind2sub(g.N, model.VarBricks);
    ctr = g.Min + ([i j k] - 0.5) .* g.Size;
    D2 = (ctr(:,1) - ctr(:,1)').^2 + (ctr(:,2) - ctr(:,2)').^2 + (ctr(:,3) - ctr(:,3)').^2;
    Fm = sparse(max(0, R - sqrt(D2)));
    Fm = spdiags(1 ./ sum(Fm, 2), 0, nVar, nVar) * Fm;

    % ---- system: all elements present, constraints, load -----------------------------------------
    used = unique(model.Elem(:));
    loc = zeros(model.NumNodes, 1); loc(used) = 1:numel(used);
    n = 3 * numel(used);
    lc = loc(model.Elem);
    ed = reshape(permute(reshape([3*lc-2, 3*lc-1, 3*lc], [], npe, 3), [1 3 2]), [], nd)';   % nd x Ne
    iK = reshape(repmat(ed, nd, 1), [], 1);
    jK = reshape(repelem(ed, nd, 1), [], 1);
    fixedDof = reshape((3 * (loc(model.FixedNodes) - 1) + (1:3))', [], 1);
    isFree = true(n, 1); isFree(fixedDof) = false;
    d = model.BC.LoadDirection(:) / norm(model.BC.LoadDirection);
    F = zeros(n, 1);
    for q = 1:numel(model.LoadNodes)
        idx = 3 * (loc(model.LoadNodes(q)) - 1) + (1:3);
        F(idx) = F(idx) + model.BC.LoadAmplitude / numel(model.LoadNodes) * d;
    end
    Ke3 = reshape(model.sK, nd, nd, Ne);

    % ---- optimality-criteria loop -------------------------------------------------------------------
    x = S.VolMax * ones(nVar, 1);
    p = S.Penal;
    hist = struct('Compliance', [], 'Volume', [], 'Change', []);
    if S.Verbose, fprintf('SIMP: %d design bricks, filter radius %.1f mm, volume limit %.0f %%\n', nVar, R * 1e3, 100 * S.VolMax); end
    beta = 1;                                                      % Heaviside projection sharpness, doubled during the run
    proj  = @(t, b) (tanh(b / 2) + tanh(b * (t - 0.5))) / (2 * tanh(b / 2));
    dproj = @(t, b) b * (1 - tanh(b * (t - 0.5)) .^ 2) / (2 * tanh(b / 2));
    for it = 1:S.MaxIter
        if it > 1 && mod(it, S.BetaEvery) == 1 && beta < S.BetaMax, beta = 2 * beta; end
        rt  = Fm * x;
        rho = proj(rt, beta);
        sc = ones(Ne, 1);
        sc(isDes) = S.Emin + (1 - S.Emin) * rho(ev(isDes)) .^ p;
        K = sparse(iK, jK, reshape(model.sK .* sc', [], 1), n, n);
        u = zeros(n, 1);
        u(isFree) = K(isFree, isFree) \ F(isFree);
        c = F' * u;

        Ue = reshape(u(ed), nd, 1, Ne);
        ce = squeeze(sum(Ue .* pagemtimes(Ke3, Ue), 1));          % u_e' K_e u_e  (Ne x 1)
        dcdrho = zeros(nVar, 1);
        dcdrho = accumarray(ev(isDes), -p * (1 - S.Emin) * rho(ev(isDes)) .^ (p - 1) .* ce(isDes), [nVar, 1]);
        dp = dproj(rt, beta);
        dc = Fm' * (dcdrho .* dp);
        dv = Fm' * (volBrick .* dp) / volTot;

        move = S.MoveLimit / max(1, beta / 2);                     % smaller steps while the projection is sharp (no flip-flopping)
        lo = 0; hi = 1e9;                                        % bisection for the Lagrange multiplier
        while (hi - lo) / (hi + lo) > 1e-4
            mid = 0.5 * (lo + hi);
            xn = max(max(0, x - move), min(min(1, x + move), x .* sqrt(max(-dc, 0) ./ max(dv, eps) / mid)));
            if proj(Fm * xn, beta)' * volBrick / volTot > S.VolMax, lo = mid; else, hi = mid; end
        end
        change = max(abs(xn - x));
        x = xn;
        hist.Compliance(end+1) = c;  hist.Volume(end+1) = rho' * volBrick / volTot;  hist.Change(end+1) = change;
        if S.Verbose && (it == 1 || mod(it, 10) == 0)
            fprintf('  iteration %3d: compliance %.4g mJ, volume %.3f, beta %g, change %.3f\n', it, c * 1e3, hist.Volume(end), beta, change);
        end
        if change < S.Tol && beta >= S.BetaMax && it > 5, break; end
    end
    rho = proj(Fm * x, beta);
    gray = mean(rho > 0.1 & rho < 0.9);

    % ---- threshold to a 0/1 layout, clean, analyse ------------------------------------------------------
    [~, ord] = sort(rho, 'descend');
    nk = find(cumsum(volBrick(ord)) / volTot > S.VolMax, 1) - 1;
    if isempty(nk), nk = nVar; end
    X = false(nVar, 1);  X(ord(1:max(nk, 1))) = true;
    if ~isempty(S.Clean)
        Cs = idt_clean_setup(model);
        Xc = idt_clean_bricks(Cs, X, S.Clean);
        [~, mc] = idt_analyze(model, Xc);
        if mc.Valid, X = Xc; end
    end
    [res, met] = idt_analyze(model, X);
    M = nan(model.Bricks.Grid.N);
    M(model.Bricks.Present) = 1;
    M(model.VarBricks) = double(X);
    out = struct('Method', 'SIMP', 'X', X, 'M', M, 'Rho', rho, 'met', met, 'res', res, 'History', hist, ...
                 'Iterations', it, 'NumEvaluations', it, 'TotalTime', toc(tAll), 'Grayness', gray, 'S', S);
    if S.Verbose
        fprintf('SIMP finished: %d iterations, %.0f s, %d of %d bricks kept, compliance %.4g mJ, %.0f %% gray bricks\n', ...
            it, out.TotalTime, nnz(X), nVar, met.Compliance * 1e3, 100 * gray);
    end
end
