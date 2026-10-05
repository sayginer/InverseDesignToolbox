function out = simp_optimize(model, S, H)
% SIMP_OPTIMIZE  SIMP topology optimization of the first natural frequency (uses fmincon).
%
%   out = simp_optimize(model, S, H)
%
%   model : from idt_build_model        S : from simp_precompute        H : from simp_options
%
% Design variable: one density rho in [RhoFloor, 1] per BRICK. One function evaluation:
%   1. filter            rho_t = Hf * rho                         (no islands, no checkerboard)
%   2. projection        rho_p = Heaviside(rho_t; beta, eta)      (pushes the field to 0 / 1)
%   3. interpolation     E_e = E0 (RhoMin + (1-RhoMin) rho_p^p),  m_e = m0 rho_p^q   (element e in brick b)
%   4. eigenproblem      K phi = lambda M phi,   f1 = sqrt(lambda_1) / 2 pi
%   5. adjoint gradient  d lambda/d rho_p,e = phi_e' (dK_e - lambda dM_e) phi_e   (ONE eigenvector gives
%                        the gradient for ALL elements; summed over the elements of each brick)
%   6. chain rule        d f1/d rho = Hf' * ( d f1/d rho_p .* d rho_p / d rho_t )
%
% Objective (H.Objective)
%   'TargetF1'   minimize ((f1 - TargetF1)/TargetF1)^2                      (VolMax optional upper bound)
%   'MaximizeF1' minimize -f1/f1_ref  subject to  volume fraction <= VolMax
% Beta continuation: fmincon is called once per stage with beta = BetaStart, 2*BetaStart, ... BetaMax,
% each stage starting from the previous result. Without the projection (BetaMax = 1) the optimizer fills
% the domain with grey material that cannot be built.
%
% OUTPUT out: .rho (design variables), .rho_t (filtered), .rho_p (projected = physical density),
%   .History (f1, f2, Vol, Grey, Beta, J, Time per evaluation), .Iterations (= evaluations),
%   .Converged, .TotalTime, .H. No figures unless H.LivePlot is true.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    H = simp_options(H);
    betas = H.BetaStart * 2.^(0:ceil(log2(H.BetaMax / H.BetaStart)));
    betas = unique(min(betas, H.BetaMax));
    isTarget = strcmp(H.Objective, 'TargetF1');
    ft = H.TargetF1;
    hasVol = ~isempty(H.VolMax);

    if S.nVar > 1000 && strcmp(H.Algorithm, 'sqp')
        warning('simp_optimize:ManyVariables', ['%d design bricks with Algorithm ''sqp'' will be very slow ' ...
            '(dense Hessian). Use bigger bricks (lower P.Design.Density) or H.Algorithm = ''interior-point''.'], S.nVar);
    end
    Hst = struct('f1', [], 'f2', [], 'Vol', [], 'Grey', [], 'Beta', [], 'J', [], 'Time', []);
    fref = [];                                        % f1 of the first evaluation (scales 'MaximizeF1')
    lastf1 = NaN;
    if H.Verbose
        fprintf('\n%-5s | %-6s | %-9s | %-9s | %-8s | %-8s | %-6s | %-6s\n', 'Eval', 'beta', 'f1 (Hz)', 'f2 (Hz)', 'Target', 'Volume', 'Grey', 'Time');
        fprintf('%s\n', repmat('-', 1, 76));
    end

    if isTarget, rho = H.VolFracInit * ones(S.nVar, 1); else, rho = H.VolMax * ones(S.nVar, 1); end
    rho = max(rho, H.RhoFloor);
    if H.CheckGradients      % testing aid: adjoint gradient vs finite differences (Optimization Toolbox)
        valid = checkGradients(@(x) objective(x, betas(1)), rho, 'Tolerance', 1e-3, 'Display', 'on');
        fprintf('Gradient check (beta = %g): %s\n', betas(1), ternary(valid, 'PASSED', 'FAILED'));
        Hst = structfun(@(v) [], Hst, 'UniformOutput', false);  fref = [];    % forget the check evaluations
    end
    converged = false;
    tAll = tic;
    for b = 1:numel(betas)
        bStage = betas(b);
        lb = H.RhoFloor * ones(S.nVar, 1);  ub = ones(S.nVar, 1);
        if ~isempty(H.MoveLimit)                      % trust region around the stage start
            lb = max(lb, rho - H.MoveLimit);  ub = min(ub, rho + H.MoveLimit);
        end
        opts = optimoptions('fmincon', 'Algorithm', H.Algorithm, 'SpecifyObjectiveGradient', true, ...
            'SpecifyConstraintGradient', hasVol, 'MaxIterations', H.StageIter, 'Display', 'off', ...
            'OptimalityTolerance', 1e-8, 'StepTolerance', 1e-8, 'OutputFcn', @stopFcn);
        if strcmp(H.Algorithm, 'interior-point'), opts.HessianApproximation = 'lbfgs'; end
        nl = [];  if hasVol, nl = @(x) volumeConstraint(x, bStage); end
        rho = fmincon(@(x) objective(x, bStage), rho, [], [], [], [], lb, ub, nl, opts);
    end
    if isTarget && abs(lastf1 - ft) < H.FreqTol, converged = true; end

    rt = S.Hf * rho;  rp = project(rt, betas(end), H.Eta);
    out = struct('rho', rho, 'rho_t', rt, 'rho_p', rp, 'History', Hst, 'Iterations', numel(Hst.f1), ...
                 'Converged', converged, 'TotalTime', toc(tAll), 'H', H);
    if H.Verbose
        fprintf('SIMP finished: %d evaluations, %.1f s, f1 = %.2f Hz\n', out.Iterations, out.TotalTime, Hst.f1(end));
    end

    %% ---- nested helpers (share Hst, fref, lastf1, S, H) ----------------------------------
    function [J, dJ] = objective(x, beta)
        t0 = tic;
        [rp_, drp] = project(S.Hf * x, beta, H.Eta);
        re = rp_(S.ev);
        [f, lam, Phi] = forward(S, H, re);
        f1 = f(1);  lastf1 = f1;
        if isempty(fref), fref = f1; end
        if isTarget
            J = ((f1 - ft) / ft)^2;  scale = 2 * (f1 - ft) / ft^2;
        else
            J = -f1 / fref;          scale = -1 / fref;
        end
        if nargout > 1
            df1b = accumarray(S.ev, element_sensitivity(S, H, re, Phi(:, 1), lam(1)), [S.nVar, 1]);
            dJ   = scale * (S.Hf' * (df1b .* drp));
        end
        k = numel(Hst.f1) + 1;
        Hst.f1(k, 1) = f1;  Hst.f2(k, 1) = f(min(2, numel(f)));  Hst.Beta(k, 1) = beta;
        Hst.Vol(k, 1)  = sum(rp_ .* S.volBrick) / S.totVol;
        Hst.Grey(k, 1) = sum(S.volBrick .* (rp_ > 0.1 & rp_ < 0.9)) / S.totVol;
        Hst.J(k, 1) = J;  Hst.Time(k, 1) = toc(t0);
        if H.Verbose
            tgt = ft;  if ~isTarget, tgt = NaN; end
            fprintf('%-5d | %-6.1f | %-9.2f | %-9.2f | %-8.2f | %-8.3f | %-6.3f | %-6.2f\n', k, beta, f1, ...
                Hst.f2(k), tgt, Hst.Vol(k), Hst.Grey(k), Hst.Time(k));
        end
        if H.LivePlot, simp_plot_live(Hst, k, ft); end
    end

    function [c, ceq, gc, gceq] = volumeConstraint(x, beta)
        [rp_, drp] = project(S.Hf * x, beta, H.Eta);
        c = sum(rp_ .* S.volBrick) / S.totVol - H.VolMax;
        ceq = [];  gceq = [];
        gc = S.Hf' * (S.volBrick .* drp) / S.totVol;
    end

    function stop = stopFcn(~, ~, ~)
        % 'TargetF1': end the LAST stage as soon as the frequency target is met
        stop = isTarget && ~isempty(Hst.Beta) && Hst.Beta(end) >= H.BetaMax && abs(lastf1 - ft) < H.FreqTol;
    end
end

function o = ternary(c, a, b)
    if c, o = a; else, o = b; end
end

function [rp, drp] = project(x, beta, eta)
% smooth Heaviside projection and its derivative
    den = tanh(beta * eta) + tanh(beta * (1 - eta));
    rp  = (tanh(beta * eta) + tanh(beta * (x - eta))) / den;
    drp = beta * (1 - tanh(beta * (x - eta)).^2) / den;
end

function [f, lam, Phi] = forward(S, H, re)
% penalized K, M -> lowest two modes (mass-normalized, on the FULL dof vector); re = design element densities
    rho_e = ones(S.Ne, 1);  rho_e(S.desElems) = re;
    pen = H.RhoMin + (1 - H.RhoMin) * rho_e.^H.PenalStiff;
    sK  = S.sK0;  sK(:, S.desElems) = S.sK0(:, S.desElems) .* pen(S.desElems)';
    K   = sparse(S.iK, S.jK, reshape(sK, [], 1), S.n, S.n);
    rv  = S.rv0;  rv(S.desElems) = S.rv0(S.desElems) .* rho_e(S.desElems).^H.PenalMass;
    M   = sparse(S.iK, S.jK, reshape(S.mRef * rv', [], 1), S.n, S.n) + S.Msensor;
    Kf  = K(S.isFree, S.isFree);  Mf = M(S.isFree, S.isFree);
    [V, L] = eigs(Kf, Mf, 2, 'smallestabs', struct('tol', H.EigTol));
    [lam, ix] = sort(real(diag(L)));  V = V(:, ix);
    V = V ./ sqrt(sum(V .* (Mf * V), 1));
    Phi = zeros(S.n, numel(lam));  Phi(S.isFree, :) = V;
    f = sqrt(max(lam, 0)) / (2 * pi);
end

function df1e = element_sensitivity(S, H, re, phi1, lam1)
% d f1 / d rho_e for every design element (adjoint: one eigenvector gives all of them)
    nd = S.nd;  nDes = S.nDes;  p = H.PenalStiff;  q = H.PenalMass;
    ed_des = S.ed(:, S.desElems);  sK_des = S.sK0(:, S.desElems);  rv_des = S.rv0(S.desElems);
    UKU = zeros(nDes, 1);  UMU = zeros(nDes, 1);
    blk = 4000;
    for a = 1:blk:nDes
        ix = a : min(a + blk - 1, nDes);
        ue = phi1(ed_des(:, ix));
        UU = reshape(reshape(ue, nd, 1, []) .* reshape(ue, 1, nd, []), nd * nd, []);
        UKU(ix) = sum(UU .* sK_des(:, ix), 1)';
        UMU(ix) = (S.mRef' * UU)' .* rv_des(ix);
    end
    dK = p * (1 - H.RhoMin) * re.^(p - 1) .* UKU;
    dM = q * re.^(q - 1) .* UMU;
    df1e = (dK - lam1 * dM) / (4 * pi * sqrt(max(lam1, eps)));
end
