function D = nn_make_dataset(model, H, X)
% NN_MAKE_DATASET  Analyse brick layouts with the real FEA to get training data. No figures.
%
%   D = nn_make_dataset(model, H)        H.NumSamples random smooth layouts (see below)
%   D = nn_make_dataset(model, H, X)     analyse the given layouts X (n x model.NumVars logical) instead
%
% Random layouts: a random field is smoothed over the bricks (cone filter, radius H.FieldRadius) and
% thresholded so that a random fraction in H.VolFracRange of the design volume is kept. Smooth layouts
% look like real designs; independent random bricks would almost never be a usable structure.
%
% Every layout is analysed with idt_analyze (in parallel if H.UseParallel and a pool can be started).
%
% Layouts that do not connect the load to the supports are skipped without FEA (nn_validity_setup, exact).
% A layout is USABLE if it is connected AND f1 > 1 Hz. About one in five connected random layouts is hinge-like
% (pieces joined only along an edge or corner, f1 close to 0); they are analysed but flagged unusable and are
% not used for training.
%
% OUTPUT D: .X (n x nVar logical), .f1 [Hz] (NaN if not usable), .usable (n x 1 logical), .vol (volume
%   fraction of the design domain), .mass [kg], .w (training weight, 1 here), .time (seconds spent in the FEA),
%   .fit (used for training: usable layouts here; nn_optimize also adds verified hinge layouts), .f1fit (the f1
%   used as training label: the real f1, or 1 Hz for a verified hinge layout)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    H = nn_options(H);
    nVar = model.NumVars;
    assert(nVar > 0, 'nn_make_dataset:NoDesign', 'The model has no design bricks.');
    volBrick = nn_brick_volumes(model);

    V = nn_validity_setup(model);
    Cs = [];  if ~isempty(H.Clean), Cs = idt_clean_setup(model); end
    if nargin < 3 || isempty(X)
        rng(H.Seed);
        X = random_layouts(model, H, volBrick);
        X = clean_rows(Cs, X, H.Clean);                   % printable layouts only (empty and duplicate ones dropped)
        ok = nn_is_valid(V, X);                           % skip layouts that are cut off: no FEA needed for them
        if H.Verbose
            fprintf('NN dataset: %d of %d random layouts connect the load to the supports\n', nnz(ok), numel(ok));
        end
        X = X(ok, :);
        X = X(1:min(H.NumSamples, size(X, 1)), :);
    else
        X = clean_rows(Cs, X, H.Clean);
        X = X(nn_is_valid(V, X), :);
    end
    n = size(X, 1);

    f1 = nan(n, 1);  mass = nan(n, 1);
    t0 = tic;
    useP = H.UseParallel && license('test', 'Distrib_Computing_Toolbox') && ~isempty(ver('parallel'));
    if useP
        try
            if isempty(gcp('nocreate')), parpool('Processes'); end
            pctRunOnAll('warning(''off'', ''all'')');       % hinge-like layouts make eigs warn on every worker
        catch
            useP = false;
        end
    end
    if H.Verbose
        if useP, mode = 'parallel'; else, mode = 'serial'; end
        fprintf('NN dataset: analysing %d layouts (%s)...\n', n, mode);
    end
    if useP
        parfor i = 1:n
            [~, m] = idt_analyze(model, X(i, :)');
            if m.Valid, f1(i) = m.f1; mass(i) = m.Mass; end
        end
    else
        for i = 1:n
            [~, m] = idt_analyze(model, X(i, :)');
            if m.Valid, f1(i) = m.f1; mass(i) = m.Mass; end
        end
    end
    usable = isfinite(f1) & f1 > 1;
    f1(~usable) = NaN;
    D = struct('X', logical(X), 'f1', f1, 'usable', usable, 'vol', (double(X) * volBrick) / sum(volBrick), ...
               'mass', mass, 'w', ones(n, 1), 'fit', usable, 'f1fit', f1, 'time', toc(t0));
    if H.Verbose
        fprintf('  done in %.1f s: %d of %d layouts usable (%.0f %%), f1 range %.1f - %.1f Hz\n', D.time, nnz(usable), n, ...
            100 * mean(usable), min(f1(usable)), max(f1(usable)));
    end
end

function X = clean_rows(Cs, X, cleanOpt)
% printable layouts only: clean every row, drop empty and duplicate layouts (order kept)
    if isempty(Cs), return; end
    X = idt_clean_bricks(Cs, X, cleanOpt);
    X = X(any(X, 2), :);
    [~, iu] = unique(X, 'rows', 'stable');
    X = X(iu, :);
end

function X = random_layouts(model, H, volBrick)
    g = model.Bricks.Grid;
    [i, j, k] = ind2sub(g.N, model.VarBricks);
    ctr = g.Min + ([i j k] - 0.5) .* g.Size;
    nVar = model.NumVars;
    D2 = (ctr(:,1) - ctr(:,1)').^2 + (ctr(:,2) - ctr(:,2)').^2 + (ctr(:,3) - ctr(:,3)').^2;
    Hf = sparse(max(0, H.FieldRadius - sqrt(D2)));
    Hf = spdiags(1 ./ sum(Hf, 2), 0, nVar, nVar) * Hf;
    n = ceil(2 * H.NumSamples);                           % some are cut off, empty or duplicates after cleaning and are skipped
    X = false(n, nVar);
    vf = H.VolFracRange(1) + diff(H.VolFracRange) * rand(n, 1);
    tot = sum(volBrick);
    for s = 1:n
        fld = Hf * randn(nVar, 1);
        [~, ord] = sort(fld, 'descend');
        cv = cumsum(volBrick(ord)) / tot;                 % keep the highest values until the volume is reached
        nk = find(cv >= vf(s), 1);
        if isempty(nk), nk = nVar; end
        X(s, ord(1:nk)) = true;
    end
end
