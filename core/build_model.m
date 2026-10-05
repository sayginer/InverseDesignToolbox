function model = build_model(geom, bricks, bc, mesh, varargin)
% BUILD_MODEL  Link geometry, bricks, boundary conditions and mesh; precompute all
% element matrices once. After this, solve_frf(model, X) only assembles and solves.
%
%   model = build_model(geom, bricks, bc, mesh, 'Freq', struct('Start',500,'End',10000, ...
%               'N',1000,'Zeta',0.02,'NModes',20))
%
% How bricks act on the mesh: every tetrahedron of the design domain belongs to the
% brick that contains its centroid. X(k) = 0 removes all elements of brick k.
% Bricks holding a fixed / load / output node are locked solid and are not variables.
% Bricks that contain no element centroid (mesh coarser than the brick) cannot be
% switched and are reported.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'Freq', struct('Start', 100, 'End', 5000, 'N', 500, 'Zeta', 0.02, 'NModes', 20));
    addParameter(p, 'StoreModes', 6);
    parse(p, varargin{:});
    fr = p.Results.Freq;

    nodes = mesh.Nodes;                 % Nn x 3
    el    = mesh.Elements;              % Ne x npe
    [Ne, npe] = size(el);
    Nn = size(nodes, 1);
    cen = (nodes(el(:,1),:) + nodes(el(:,2),:) + nodes(el(:,3),:) + nodes(el(:,4),:)) / 4;

    % ---- which CAD part does every element belong to ------------------------
    P = numel(geom.Parts);
    tag = zeros(Ne, 1);
    for ip = 1:P
        TR = triangulation(geom.Parts(ip).Tets, geom.Parts(ip).Nodes);
        inside = ~isnan(pointLocation(TR, cen)) & tag == 0;
        tag(inside) = ip;
    end
    if any(tag == 0)                    % boundary slivers: nearest part
        allN = cat(1, geom.Parts.Nodes);
        owner = repelem(1:P, arrayfun(@(q) size(q.Nodes, 1), geom.Parts))';
        k = dsearchn(allN, cen(tag == 0, :));
        tag(tag == 0) = owner(k);
    end

    % ---- materials --------------------------------------------------------------
    E = zeros(Ne, 1); nu = E; rho = E; matName = cell(1, P);
    for ip = 1:P
        m = get_material_properties(geom.Parts(ip).Material);
        s = tag == ip; E(s) = m.E; nu(s) = m.nu; rho(s) = m.rho; matName{ip} = m.Name;
    end

    % ---- boundary conditions -------------------------------------------------------
    fixed = [];
    if ~isempty(bc.FixedFaces), fixed = findNodes(mesh.Mesh, 'region', 'Face', bc.FixedFaces)'; end
    if ~isempty(bc.FixedFcn), fixed = union(fixed, find(bc.FixedFcn(nodes(:,1), nodes(:,2), nodes(:,3)))); end
    fixed = fixed(:);
    assert(~isempty(fixed), 'No nodes are fixed. Check FixedFaces / FixedFcn.');

    if ~isempty(bc.LoadFaces)
        loadNodes = findNodes(mesh.Mesh, 'region', 'Face', bc.LoadFaces)';
    else
        loadNodes = nearest(nodes, bc.LoadPoint);
    end
    loadNodes = loadNodes(:);
    outNodes = zeros(size(bc.OutPoints, 1), 1);
    for i = 1:numel(outNodes), outNodes(i) = nearest(nodes, bc.OutPoints(i, :)); end

    % ---- bricks -> elements -------------------------------------------------------
    g = bricks.Grid; N = g.N;
    if strcmp(bricks.Mode, 'part')
        isDesign = tag == bricks.DesignPart;
    else
        b = bricks.Box;
        isDesign = cen(:,1) >= b(1) & cen(:,1) <= b(2) & cen(:,2) >= b(3) & cen(:,2) <= b(4) & ...
                   cen(:,3) >= b(5) & cen(:,3) <= b(6);
    end
    ijk = floor((cen - g.Min) ./ g.Size) + 1;
    ijk = min(max(ijk, 1), N);
    brickOfElem = sub2ind(N, ijk(:,1), ijk(:,2), ijk(:,3));
    isDesign = isDesign & bricks.Present(brickOfElem);   % cells that are not bricks stay solid
    brickOfElem(~isDesign) = 0;

    lockNodes = unique([fixed; loadNodes; outNodes]);
    touchesLock = any(ismember(el, lockNodes), 2);
    lockedBricks = unique(brickOfElem(isDesign & touchesLock));
    usedBricks = unique(brickOfElem(isDesign));
    varBricks = setdiff(usedBricks, lockedBricks);
    varOfBrick = zeros(prod(N), 1); varOfBrick(varBricks) = 1:numel(varBricks);
    elemVar = zeros(Ne, 1);
    elemVar(isDesign) = varOfBrick(brickOfElem(isDesign));
    emptyBricks = nnz(bricks.Present) - numel(usedBricks);

    % ---- extra lumped mass ------------------------------------------------------------
    massNodes = [];
    if bc.ExtraMass > 0
        permNodes = unique(el(elemVar == 0, :));
        c = nodes(permNodes, :);
        massNodes = permNodes(bc.ExtraMassRegion(c(:,1), c(:,2), c(:,3)));
        assert(~isempty(massNodes), 'ExtraMassRegion selected no nodes.');
    end

    % ---- element matrices (the expensive part, done once) ------------------------------
    t0 = tic;
    X3 = zeros(Ne, npe, 3);
    for d = 1:3, X3(:, :, d) = reshape(nodes(el(:), d), Ne, npe); end
    [sK, vol, Mref3] = tet_element_matrices(X3, E, nu);

    model = struct('Geom', geom, 'Bricks', bricks, 'BC', bc, 'Mesh', mesh, 'Freq', fr, ...
        'Nodes', nodes, 'Elem', el, 'NumNodes', Nn, 'NumElems', Ne, 'Npe', npe, ...
        'Tag', tag, 'E', E, 'Rho', rho, 'Vol', vol, 'sK', sK, 'Mref3', Mref3, ...
        'FixedNodes', fixed, 'LoadNodes', loadNodes, 'OutNodes', outNodes, ...
        'MassNodes', massNodes, 'ExtraMass', bc.ExtraMass, ...
        'ElemVar', elemVar, 'ElemBrick', brickOfElem, 'IsDesign', isDesign, ...
        'NumVars', numel(varBricks), 'VarBricks', varBricks, 'LockedBricks', lockedBricks, ...
        'StoreModes', p.Results.StoreModes);

    fprintf('--- Model ---\n');
    for ip = 1:P
        fprintf('  Part %d "%s": %s, %d elements, %.2f g\n', ip, geom.Parts(ip).Name, matName{ip}, ...
            nnz(tag == ip), sum(vol(tag == ip) .* rho(tag == ip)) * 1e3);
    end
    fprintf('  Design elements: %d in %d bricks (%d locked, %d free variables)\n', ...
        nnz(isDesign), numel(usedBricks), numel(lockedBricks), model.NumVars);
    if emptyBricks > 0
        fprintf('  WARNING: %d bricks contain no element centroid (mesh too coarse for this brick size).\n', emptyBricks);
    end
    fprintf('  Fixed nodes: %d | load nodes: %d | outputs: %d | matrices built in %.1f s\n\n', ...
        numel(fixed), numel(loadNodes), numel(outNodes), toc(t0));
end

function n = nearest(nodes, pt)
    [~, n] = min(sum((nodes - pt(:)').^2, 2));
end
