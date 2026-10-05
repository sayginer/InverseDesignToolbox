function post = simp_postprocess(model, S, out, H)
% SIMP_POSTPROCESS  Turn the SIMP density field into a solid brick design and verify it. No figures.
%
%   post = simp_postprocess(model, S, out, H)
%
% The continuous design is only a means; what you build is solid bricks. For every cutoff in H.Thresholds
% the layout  X = (brick density > cutoff)  is made printable (idt_clean_bricks, unless H.Clean = []: no
% checkerboards, no islands, no features thinner than H.Clean.MinWidth bricks), analysed with idt_analyze,
% and the best VALID layout is kept:
%   'TargetF1'   the one whose f1 is closest to the target
%   'MaximizeF1' the one with the highest f1 that respects VolMax (volume-weighted)
% Then (unless H.Polish = []) idt_polish_bricks adds / removes boundary bricks with the real analysis to close the
% gap to the goal that cleaning opened. The winner gets the full analysis (idt_analyze), so post.res / post.met can
% be plotted directly. post.Polish lists f1 and brick count per accepted polish step.
%
% OUTPUT post: .X (logical, one entry per design brick), .M (brick matrix for idt_plot_brick_selection),
%   .rho_b (brick densities), .Threshold, .Sweep (struct array: th, valid, f1, vol, nBricks), .met, .res
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    H = simp_options(H);
    rho_b = out.rho_p;                                   % one density per design brick
    ths = H.Thresholds(:)';
    sweep = repmat(struct('th', 0, 'valid', false, 'f1', NaN, 'vol', NaN, 'nBricks', 0), 1, numel(ths));
    best = Inf;  X = [];  thBest = NaN;
    Cset = [];
    if ~isempty(H.Clean), Cset = idt_clean_setup(model); end
    for k = 1:numel(ths)
        Xc = rho_b > ths(k);
        if ~isempty(Cset), Xc = idt_clean_bricks(Cset, Xc, H.Clean); end     % printable layout
        sweep(k).th = ths(k);  sweep(k).nBricks = nnz(Xc);
        sweep(k).vol = sum(S.volBrick(Xc)) / S.totVol;
        [~, m] = idt_analyze(model, Xc);
        if ~m.Valid || ~isfinite(m.f1) || m.f1 < 1, continue; end
        sweep(k).valid = true;  sweep(k).f1 = m.f1;
        if strcmp(H.Objective, 'TargetF1')
            score = abs(m.f1 - H.TargetF1);
            if ~isempty(H.VolMax) && sweep(k).vol > H.VolMax, score = score + 1e6; end
        else
            if sweep(k).vol > H.VolMax * 1.0000001, continue; end
            score = -m.f1;
        end
        if score < best, best = score; X = Xc; thBest = ths(k); end
    end
    if isempty(X)
        warning('simp_postprocess:NoValid', ...
            'No cutoff gave a valid layout (load / outputs connected to the supports); using the lowest cutoff.');
        thBest = ths(1);  X = rho_b > thBest;
        if ~isempty(Cset), X = idt_clean_bricks(Cset, X, H.Clean); end
    end

    polish = [];
    if ~isempty(H.Polish) && ~isempty(Cset)
        goal = struct('Objective', H.Objective, 'TargetF1', H.TargetF1, 'VolMax', H.VolMax);
        po = H.Polish;  po.Verbose = H.Verbose;
        [X, polish] = idt_polish_bricks(model, X, goal, Cset, H.Clean, po);
    end

    [res, met] = idt_analyze(model, X);
    M = nan(model.Bricks.Grid.N);
    M(model.Bricks.Present) = 1;                         % bricks locked by supports / load stay solid
    M(model.VarBricks) = double(X);
    post = struct('X', X, 'M', M, 'rho_b', rho_b, 'Threshold', thBest, 'Sweep', sweep, 'Polish', polish, ...
                  'met', met, 'res', res);
end
