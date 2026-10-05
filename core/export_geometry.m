function info = export_geometry(model, X, filename, varargin)
% EXPORT_GEOMETRY  Write the final geometry of a brick layout X to an STL file.
%
%   export_geometry(model, X, 'final_design')                        clean CAD geometry with the removed bricks cut out
%   export_geometry(model, X, 'final_design', 'Content', 'bricks')   only the kept bricks, merged, as flat-faced boxes
%   export_geometry(model, X, 'final_design', 'Content', 'structure') meshed skin of the final structure (analysis mesh)
%   export_geometry(model, X, 'final_design', 'Content', 'design')    meshed skin of the design part only
%
% NAME-VALUE
%   'Content'  'cad' (default): the imported CAD assembly with every removed brick subtracted as a
%                  box-shaped pocket. Exact round holes, large flat triangles, brick-shaped cuts -
%                  no mesh triangles. Falls back to 'structure' if the CAD boolean fails.
%              'bricks':    only the present bricks (the units you fabricate), flat-faced boxes.
%              'structure': every part as the skin of the analysis mesh (faceted, meshy).
%              'design':    skin of the analysis mesh for the design part only.
%   'Units'    'mm' (default) or 'm' - STL has no units, so the numbers are scaled accordingly.
%   'Result'   res from solve_frf ('structure'/'design' only): drop pieces found floating.
%   'SaveSelection'  also write <filename>_bricks.csv and <filename>_selection.mat (default true):
%              brick table (grid index, center, present flag) and X / selection matrix.
%
% STL is a surface format: import it into CAD/slicer software. STEP cannot be written from MATLAB.
% Note: 'cad' cuts whole bricks, exactly as defined by the brick grid.
%
% OUTPUT info: .File, .NumTriangles, .Volume (m^3), .Content, .NumCutBoxes (for 'cad')
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'Content', 'cad');
    addParameter(p, 'Units', 'mm');
    addParameter(p, 'Result', []);
    addParameter(p, 'SaveSelection', true);
    parse(p, varargin{:});
    r = p.Results;

    if nargin < 2 || isempty(X), X = true(model.NumVars, 1); end
    X = X(:) > 0.5;
    scale = 1e3 * strcmpi(r.Units, 'mm') + 1 * strcmpi(r.Units, 'm');
    [folder, name, ~] = fileparts(filename);
    base = fullfile(folder, name);
    content = lower(r.Content);
    nBox = 0;

    g = model.Bricks.Grid; N = g.N;
    on = false(N);
    on(model.VarBricks(X)) = true;
    on(model.LockedBricks) = true;

    if strcmp(content, 'cad')
        try
            [F, V, nBox] = cad_geometry(model, on);
        catch err
            warning('export_geometry:CadFailed', ...
                ['CAD boolean failed (%s). This usually means kept bricks touch only along an edge or corner ' ...
                 '(checkerboard-like layouts), which is not a valid solid. Falling back to the meshed skin ' ...
                 '(Content = ''structure''); use Content = ''bricks'' for a clean export of the bricks only.'], err.message);
            content = 'structure';
        end
    end

    switch content
        case 'cad'
            % F, V from cad_geometry
        case {'structure', 'design'}
            ev = model.ElemVar; act = ev == 0; act(ev > 0) = X(ev(ev > 0));
            if ~isempty(r.Result) && r.Result.Valid, act = r.Result.Active; end
            sel = act;
            if strcmp(content, 'design')
                sel = sel & (model.Tag == model.Bricks.DesignPart);
                assert(any(sel), 'No design elements are present.');
            end
            el = model.Elem(sel, :);
            [F, own] = boundary_faces(el);
            V = model.Nodes;
            p1 = V(F(:,1), :); p2 = V(F(:,2), :); p3 = V(F(:,3), :);      % orient outward
            nrm = cross(p2 - p1, p3 - p1, 2);
            ec = (V(el(own,1),:) + V(el(own,2),:) + V(el(own,3),:) + V(el(own,4),:)) / 4;
            flip = sum(nrm .* ((p1 + p2 + p3) / 3 - ec), 2) < 0;
            F(flip, [2 3]) = F(flip, [3 2]);
            used = unique(F(:)); map = zeros(size(V, 1), 1); map(used) = 1:numel(used);
            F = map(F); V = V(used, :);
        case 'bricks'
            [F, V] = brick_surface(on, g);
        otherwise
            error('export_geometry:Content', 'Content must be ''cad'', ''bricks'', ''structure'' or ''design''.');
    end

    V = V * scale;
    a = V(F(:,1),:); b = V(F(:,2),:); c = V(F(:,3),:);
    sv = sum(dot(a, cross(b, c, 2), 2)) / 6;
    if sv < 0, F = F(:, [1 3 2]); end                  % make the triangles point outward
    vol = abs(sv) / scale^3;

    file = [base '.stl'];
    stlwrite(triangulation(F, V), file);
    info = struct('File', file, 'NumTriangles', size(F, 1), 'Volume', vol, 'Content', content, 'NumCutBoxes', nBox);
    fprintf('Exported %s geometry: %s (%d triangles, volume %.1f mm^3, units %s)\n', ...
        content, file, size(F, 1), vol * 1e9, r.Units);

    if r.SaveSelection
        [i, j, k] = ind2sub(N, model.VarBricks);
        ctr = g.Min + ([i j k] - 0.5) .* g.Size;
        T = table((1:model.NumVars)', i, j, k, ctr(:,1)*scale, ctr(:,2)*scale, ctr(:,3)*scale, double(X), ...
                  'VariableNames', {'BrickID', 'ix', 'iy', 'iz', ['x_' r.Units], ['y_' r.Units], ['z_' r.Units], 'Present'});
        writetable(T, [base '_bricks.csv']);
        M = nan(N); M(model.VarBricks) = double(X);            %#ok<NASGU>
        BrickSize = g.Size * scale; GridMin = g.Min * scale; Units = r.Units; %#ok<NASGU>
        save([base '_selection.mat'], 'X', 'M', 'BrickSize', 'GridMin', 'Units');
        fprintf('  Brick table: %s_bricks.csv | selection: %s_selection.mat\n', base, base);
    end
end

% -------------------------------------------------------------------------------------------
function [F, V, nBox] = cad_geometry(model, on)
% Imported CAD assembly minus every removed brick, cut as merged box pockets.
    g = model.Bricks.Grid; N = g.N;
    removed = model.Bricks.Present & ~on;
    boxes = merge_boxes(removed);
    nBox = size(boxes, 1);
    mar = 0.5 * min(g.Size);
    open = open_sides(model, g);                       % grid sides with no material just outside

    % The CAD boolean is sensitive to the ORDER of the cuts: one order can fail where another cuts every pocket
    % (and after the first failure the later cuts fail too). Try the original order, the reversed one and then
    % shuffled orders (fixed seed, so the result is reproducible) and stop at the first one that works.
    rs = RandStream('twister', 'Seed', 1);
    orders = {1:nBox, nBox:-1:1};
    for q = 1:15, orders{end + 1} = randperm(rs, nBox); end %#ok<AGROW>
    ok = false;
    for oi = 1:numel(orders)
        C = model.Geom.Assembly;
        ok = true;
        for b = orders{oi}
            lo = g.Min + (boxes(b, 1:3) - 1) .* g.Size;
            hi = g.Min + boxes(b, 4:6) .* g.Size;
            for ax = 1:3                               % avoid coincident faces on free outer surfaces
                if boxes(b, ax) == 1 && open(ax, 1),      lo(ax) = lo(ax) - mar; end
                if boxes(b, 3 + ax) == N(ax) && open(ax, 2), hi(ax) = hi(ax) + mar; end
            end
            w = hi - lo;
            blk = fegeometry(multicuboid(w(1), w(2), w(3)));
            blk = translate(blk, [(lo(1) + hi(1)) / 2, (lo(2) + hi(2)) / 2, lo(3)]);
            try
                C = subtract(C, blk);
            catch
                ok = false;  break;
            end
        end
        if ok, break; end
    end
    if ~ok, error('export_geometry:CutOrders', 'Unable to subtract the removed bricks in any of %d cut orders.', numel(orders)); end
    T = triangulation(C);
    F = T.ConnectivityList; V = T.Points;
end

function boxes = merge_boxes(R)
% Greedy merge of removed cells into few axis-aligned boxes: rows [i j k i2 j2 k2].
    N = size(R, 1:3); seen = false(N); boxes = zeros(0, 6);
    for k = 1:N(3)
        for j = 1:N(2)
            for i = 1:N(1)
                if ~R(i,j,k) || seen(i,j,k), continue; end
                i2 = i; while i2 < N(1) && R(i2+1,j,k) && ~seen(i2+1,j,k), i2 = i2 + 1; end
                j2 = j; while j2 < N(2) && all(R(i:i2,j2+1,k)) && ~any(seen(i:i2,j2+1,k)), j2 = j2 + 1; end
                k2 = k; while k2 < N(3) && all(R(i:i2,j:j2,k2+1), 'all') && ~any(seen(i:i2,j:j2,k2+1), 'all'), k2 = k2 + 1; end
                seen(i:i2, j:j2, k:k2) = true;
                boxes(end+1, :) = [i j k i2 j2 k2]; %#ok<AGROW>
            end
        end
    end
end

function open = open_sides(model, g)
% open(ax, 1) / open(ax, 2): true if no part has material just outside the low / high grid face.
    open = true(3, 2);
    L = g.N .* g.Size; lo = g.Min; hi = g.Min + L;
    t = linspace(0.1, 0.9, 7);
    for ax = 1:3
        oth = setdiff(1:3, ax);
        [A, B] = ndgrid(t, t);
        for side = 1:2
            P = zeros(numel(A), 3);
            P(:, oth(1)) = lo(oth(1)) + A(:) * L(oth(1));
            P(:, oth(2)) = lo(oth(2)) + B(:) * L(oth(2));
            P(:, ax) = (side == 1) * (lo(ax) - 0.3 * g.Size(ax)) + (side == 2) * (hi(ax) + 0.3 * g.Size(ax));
            for q = 1:numel(model.Geom.Parts)
                TR = triangulation(model.Geom.Parts(q).Tets, model.Geom.Parts(q).Nodes);
                if any(~isnan(pointLocation(TR, P))), open(ax, side) = false; break; end
            end
        end
    end
end

function [F, V] = brick_surface(on, g)
% Exposed quad faces of the brick set, split into outward-oriented triangles.
    N = g.N; Nn = N + 1;
    [X, Y, Z] = ndgrid(g.Min(1) + (0:N(1)) * g.Size(1), g.Min(2) + (0:N(2)) * g.Size(2), ...
                       g.Min(3) + (0:N(3)) * g.Size(3));
    V = [X(:) Y(:) Z(:)];
    P = false(N + 2); P(2:end-1, 2:end-1, 2:end-1) = on;
    nid = @(a, b, c) a + Nn(1) * ((b - 1) + Nn(2) * (c - 1));
    Q = zeros(0, 4);
    for ax = 1:3
        for sgn = [-1 1]
            sh = zeros(1, 3); sh(ax) = sgn;
            nb = P(2+sh(1):end-1+sh(1), 2+sh(2):end-1+sh(2), 2+sh(3):end-1+sh(3));
            [i, j, k] = ind2sub(N, find(on & ~nb)); o = sgn > 0;
            switch ax
                case 1, a = i + o; q = [nid(a,j,k) nid(a,j+1,k) nid(a,j+1,k+1) nid(a,j,k+1)];
                case 2, a = j + o; q = [nid(i,a,k) nid(i+1,a,k) nid(i+1,a,k+1) nid(i,a,k+1)];
                case 3, a = k + o; q = [nid(i,j,a) nid(i+1,j,a) nid(i+1,j+1,a) nid(i,j+1,a)];
            end
            n = cross(V(q(:,2),:) - V(q(:,1),:), V(q(:,3),:) - V(q(:,1),:), 2);
            bad = n(:, ax) * sgn < 0;
            q(bad, :) = q(bad, [1 4 3 2]);
            Q = [Q; q]; %#ok<AGROW>
        end
    end
    F = [Q(:, [1 2 3]); Q(:, [1 3 4])];
    used = unique(F(:)); map = zeros(size(V, 1), 1); map(used) = 1:numel(used);
    F = map(F); V = V(used, :);
end
