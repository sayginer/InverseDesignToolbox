function X = idt_random_layouts(model, n, volRange, fieldRadius, rs)
% IDT_RANDOM_LAYOUTS  Random SMOOTH brick layouts (starting populations, training data).
%
%   X = idt_random_layouts(model, n, volRange, fieldRadius)
%   X = idt_random_layouts(model, n, volRange, fieldRadius, rs)      rs: RandStream (default: the global stream)
%
%   n            number of layouts           volRange   [low high] volume fraction of the design domain (random per layout)
%   fieldRadius  smoothness [m] of the random field (about 2 brick edges); bigger = blobbier
%
% A random field is smoothed over the bricks (cone filter) and thresholded so that a random fraction in volRange of the
% design volume is kept. Smooth layouts resemble real designs; independent random bricks would almost never be a usable
% structure. The layouts are NOT cleaned: pass them through idt_clean_bricks for printable ones.
%
% OUTPUT X  (n x model.NumVars logical, one layout per row)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 5, rs = RandStream.getGlobalStream; end
    nVar = model.NumVars;
    g = model.Bricks.Grid;
    [i, j, k] = ind2sub(g.N, model.VarBricks);
    ctr = g.Min + ([i j k] - 0.5) .* g.Size;
    D2 = (ctr(:,1) - ctr(:,1)').^2 + (ctr(:,2) - ctr(:,2)').^2 + (ctr(:,3) - ctr(:,3)').^2;
    Hf = sparse(max(0, fieldRadius - sqrt(D2)));
    Hf = spdiags(1 ./ sum(Hf, 2), 0, nVar, nVar) * Hf;

    ev = model.ElemVar;
    volBrick = accumarray(ev(ev > 0), model.Vol(ev > 0), [nVar, 1]);
    tot = sum(volBrick);
    vf = volRange(1) + diff(volRange) * rand(rs, n, 1);
    X = false(n, nVar);
    for s = 1:n
        fld = Hf * randn(rs, nVar, 1);
        [~, ord] = sort(fld, 'descend');
        cv = cumsum(volBrick(ord)) / tot;                  % keep the highest values until the volume is reached
        nk = find(cv >= vf(s), 1);
        if isempty(nk), nk = nVar; end
        X(s, ord(1:nk)) = true;
    end
end
