function [X, hist] = idt_polish_bricks(model, X, goal, C, cleanOpt, opt)
% IDT_POLISH_BRICKS  Close the last gap to the goal by adding / removing boundary bricks (real FEA, printable).
%
%   [X, hist] = idt_polish_bricks(model, X, goal, C, cleanOpt, opt)
%
%   model    : from idt_build_model
%   X        : starting layout (nVar x 1 logical), normally the output of an optimizer
%   goal     : struct with Objective ('TargetF1' | 'MaximizeF1'), TargetF1 [Hz], VolMax (0..1 or [])
%   C        : from idt_clean_setup            cleanOpt: options of idt_clean_bricks ([] = no cleaning)
%   opt      : MaxSteps (12), Tol (0.5 Hz, 'TargetF1' stops inside it), UseParallel (true), Verbose (true)
%
% Why: an optimizer works with a smooth or approximate model, and making the layout printable (cleaning, whole
% bricks) shifts f1 away from the optimum. This closes that gap with the REAL analysis. One step:
%   1. candidates = every brick on the boundary of the layout, toggled (an absent brick next to a present one is added,
%      a present brick next to an absent one is removed); each candidate is cleaned again so it stays printable
%   2. all candidates are analysed with idt_analyze (in parallel)
%   3. the best one is accepted if it improves the goal; stop when nothing improves
% Goal: 'TargetF1' minimizes |f1 - TargetF1|, 'MaximizeF1' maximizes f1; VolMax (volume fraction of the design
% domain) is respected if given. The result is a local optimum of single-brick changes.
%
% OUTPUT X (polished layout), hist (struct: f1, nBricks, vol per accepted step, including the start)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 6, opt = struct(); end
    opt = idt_fill_defaults(opt, struct('MaxSteps', 12, 'Tol', 0.5, 'UseParallel', true, 'Verbose', true));
    isTarget = strcmp(goal.Objective, 'TargetF1');
    ev = model.ElemVar;
    volBrick = accumarray(ev(ev > 0), model.Vol(ev > 0), [model.NumVars, 1]);
    volTot = sum(volBrick);
    N = C.N;

    useP = opt.UseParallel && license('test', 'Distrib_Computing_Toolbox') && ~isempty(ver('parallel'));
    if useP
        try
            if isempty(gcp('nocreate')), parpool('Processes'); end
            pctRunOnAll('warning(''off'', ''all'')');
        catch
            useP = false;
        end
    end

    X = X(:) > 0;
    [f1, ok] = evaluate(model, X', false);
    cur = score(f1, ok, X, goal, isTarget, volBrick, volTot);
    hist = struct('f1', f1, 'nBricks', nnz(X), 'vol', sum(volBrick(X)) / volTot);
    if opt.Verbose, fprintf('Polish: start f1 = %.2f Hz, %d bricks\n', f1, nnz(X)); end

    for step = 1:opt.MaxSteps
        if isTarget && ok && abs(f1 - goal.TargetF1) < opt.Tol, break; end
        cand = boundary_toggles(C, X, N);
        if ~isempty(cleanOpt), cand = idt_clean_bricks(C, cand, cleanOpt); end
        cand = cand(any(cand, 2), :);
        cand = unique(cand, 'rows');
        cand = cand(~ismember(cand, X', 'rows'), :);
        if isempty(cand), break; end
        [fc, okc] = evaluate(model, cand, useP);
        sc = nan(size(fc));
        for q = 1:size(cand, 1)
            sc(q) = score(fc(q), okc(q), cand(q, :)', goal, isTarget, volBrick, volTot);
        end
        [best, ib] = min(sc);
        if ~(best < cur), break; end                         % nothing improves: local optimum
        X = cand(ib, :)';  f1 = fc(ib);  ok = okc(ib);  cur = best;
        hist(end + 1) = struct('f1', f1, 'nBricks', nnz(X), 'vol', sum(volBrick(X)) / volTot); %#ok<AGROW>
        if opt.Verbose
            fprintf('Polish step %d: %d candidates -> f1 = %.2f Hz, %d bricks\n', step, size(cand, 1), f1, nnz(X));
        end
    end
end

function cand = boundary_toggles(C, X, N)
% one layout per boundary brick, with that brick toggled
    A = false(N);  A(C.varBricks) = X;
    face = cat(3, [0 0 0; 0 1 0; 0 0 0], [0 1 0; 1 0 1; 0 1 0], [0 0 0; 0 1 0; 0 0 0]);
    nbPresent = convn(double(A | ~C.present), face, 'same') > 0;        % has a solid face neighbour
    nbAbsent  = convn(double(~A & C.isVar), face, 'same') > 0;          % has an absent design face neighbour
    anchor = false(N);  anchor(C.varBricks) = C.touchSupport | C.touchLoad;   % touches the supports or the holder
    addable = C.isVar & ~A & (nbPresent | anchor);
    removable = A & nbAbsent;
    idx = find(addable | removable);
    v = C.lin2var(idx);
    cand = repmat(X', numel(v), 1);
    for q = 1:numel(v), cand(q, v(q)) = ~cand(q, v(q)); end
end

function [f1, ok] = evaluate(model, Xrows, useP)
    n = size(Xrows, 1);
    f1 = nan(n, 1);  ok = false(n, 1);
    if useP
        parfor i = 1:n
            [~, m] = idt_analyze(model, Xrows(i, :)');
            if m.Valid, f1(i) = m.f1; end
        end
    else
        for i = 1:n
            [~, m] = idt_analyze(model, Xrows(i, :)');
            if m.Valid, f1(i) = m.f1; end
        end
    end
    ok = isfinite(f1) & f1 > 1;
end

function s = score(f1, ok, X, goal, isTarget, volBrick, volTot)
% lower is better; Inf = not usable or over the volume limit
    s = Inf;
    if ~ok, return; end
    vol = sum(volBrick(X > 0)) / volTot;
    if ~isempty(goal.VolMax) && vol > goal.VolMax * 1.0000001, return; end
    if isTarget, s = abs(f1 - goal.TargetF1); else, s = -f1; end
end
