function [smodel, S] = idt_shape_setup(model, C)
% IDT_SHAPE_SETUP  Prepare a model for cutter (shape) designs. Once per problem.
%
%   [smodel, S] = idt_shape_setup(model, C)
%
%   model : from idt_build_model with P.Design.Type = 'none' (no bricks: the shape module works on the geometry itself)
%   C     : cutter design space, see idt_shape_options (NumHoles, NumRects, Region, HoleRadius, RectSize, ...)
%
% HOW A CUTTER DESIGN IS ANALYSED (fast): the mesh stays the same. Every element of the design part whose centroid lies
% inside a cutter is removed (idt_cutters_mask), exactly like a removed brick. So a design costs one eigen-analysis and
% no re-meshing, and idt_analyze / the optimizers work unchanged. The result follows the mesh at the cutter edges (about one
% element size), so check the final design with the exact CAD cut (idt_cutters_geometry + idt_cutters_verify).
%
% Elements of the design part that touch a support, the load point or an output point are never removed.
%
% OUTPUT
%   smodel : the model with one on/off variable per removable element (smodel.NumVars of them);
%            use  [res, met] = idt_analyze(smodel, X)  with X = idt_cutters_mask(S, cut)
%   S      : cutter design space: .C (filled options), .NumParams, .LB, .UB, .Names (what each number of the parameter
%            vector p means), .Centers / .Vol of the removable elements, .VolTotal, .LockCenters, .NumHoles, .NumRects
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    assert(model.NumVars == 0, 'idt_shape_setup:Bricks', ...
        ['The model has brick variables. Build it with P.Design.Type = ''none'' for the shape module ' ...
         '(the design is the cutter list, not the bricks).']);
    C  = idt_shape_options(C, model);
    ip = model.Params.Design.Part;

    lockNodes = unique([model.FixedNodes; model.LoadNodes; model.OutNodes]);
    touch     = any(ismember(model.Elem, lockNodes), 2);
    inPart    = model.Tag == ip;
    rem       = find(inPart & ~touch);                       % removable elements
    assert(~isempty(rem), 'idt_shape_setup:NoElements', 'The design part has no removable elements.');

    el  = model.Elem;
    cen = (model.Nodes(el(:,1),:) + model.Nodes(el(:,2),:) + model.Nodes(el(:,3),:) + model.Nodes(el(:,4),:)) / 4;
    lockCen = cen(find(inPart & touch), 1:2); %#ok<FNDSB>

    smodel = model;
    smodel.ElemVar = zeros(model.NumElems, 1);
    smodel.ElemVar(rem) = 1:numel(rem);
    smodel.NumVars = numel(rem);

    % ---- parameter vector p:  [hole 1: x y r | hole 2 ... | rect 1: x y w h angle | rect 2 ...] ---------------------
    R = C.Region;
    holeLB = [R(1) R(3) 0];                holeUB = [R(2) R(4) C.HoleRadius(2)];
    rectLB = [R(1) R(3) 0 0 0];            rectUB = [R(2) R(4) C.RectSize(2) C.RectSize(2) 180];
    LB = [repmat(holeLB, 1, C.NumHoles), repmat(rectLB, 1, C.NumRects)];
    UB = [repmat(holeUB, 1, C.NumHoles), repmat(rectUB, 1, C.NumRects)];
    names = {};
    for k = 1:C.NumHoles, names = [names, arrayfun(@(s) sprintf('hole%d_%s', k, s{1}), {'x', 'y', 'r'}, 'UniformOutput', false)]; end %#ok<AGROW>
    for k = 1:C.NumRects, names = [names, arrayfun(@(s) sprintf('rect%d_%s', k, s{1}), {'x', 'y', 'w', 'h', 'angle'}, 'UniformOutput', false)]; end %#ok<AGROW>

    % ---- top-view raster for the minimum-wall rule (idt_cutters_wall) ----------------------------------------------------
    W = [];
    if C.MinWall > 0
        gb  = model.Geom.BBox;  dx = 0.25e-3;
        xg  = gb(1):dx:gb(2);   yg = gb(3):dx:gb(4);
        [XG, YG] = meshgrid(xg, yg);
        zm  = (model.Geom.Parts(ip).BBox(5) + model.Geom.Parts(ip).BBox(6)) / 2;
        pts = [XG(:), YG(:), zm * ones(numel(XG), 1)];
        inP = false(numel(XG), numel(model.Geom.Parts));
        for q = 1:numel(model.Geom.Parts)
            TR = triangulation(model.Geom.Parts(q).Tets, model.Geom.Parts(q).Nodes);
            inP(:, q) = ~isnan(pointLocation(TR, pts));
        end
        Fall = reshape(any(inP, 2), size(XG));  Fdes = reshape(inP(:, ip), size(XG));
        Fall = imclose(Fall, ones(3));  Fdes = imclose(Fdes, ones(3));   % point-in-mesh tests miss points exactly on part interfaces: close those 1-pixel gaps
        se   = strel('disk', max(1, floor(C.MinWall / 2 / dx)), 0);
        Thin0 = Fall & ~imopen(Fall, se);                      % walls that exist without any cutter
        W = struct('x', xg, 'y', yg, 'Pts', [XG(:) YG(:)], 'Fall', Fall, 'Fdes', Fdes, 'SE', se, 'Thin0', Thin0, 'dx', dx);
    end

    S = struct('C', C, 'Wall', W,'Part', ip, 'NumHoles', C.NumHoles, 'NumRects', C.NumRects, 'NumParams', numel(LB), ...
               'LB', LB, 'UB', UB, 'Names', {names}, 'Elems', rem, 'Centers', cen(rem, :), ...
               'Vol', model.Vol(rem), 'VolTotal', sum(model.Vol(inPart)), 'LockCenters', lockCen);

    fprintf('--- Shape design space ---\n');
    fprintf('  Design part %d "%s": %d removable elements (of %d in the part)\n', ip, model.Geom.Parts(ip).Name, numel(rem), nnz(inPart));
    fprintf('  %d holes (radius %.1f - %.1f mm) + %d rectangles (size %.1f - %.1f mm) = %d numbers\n', ...
        C.NumHoles, C.HoleRadius * 1e3, C.NumRects, C.RectSize * 1e3, S.NumParams);
    fprintf('  Cutter centers inside x %.1f..%.1f mm, y %.1f..%.1f mm; smaller than the minimum = switched off\n\n', R * 1e3);
end
