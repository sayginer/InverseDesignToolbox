function geom2 = idt_cutters_geometry(model, cut)
% IDT_CUTTERS_GEOMETRY  The EXACT CAD geometry with the cutters subtracted from the design part.
%
%   geom2 = idt_cutters_geometry(model, cut)
%
%   model : from idt_build_model (P.Design.Type = 'none')       cut : list of cutters (idt_cutter)
%
% Every cutter becomes a solid cylinder (hole) or box (rectangle) that is as tall as the design part plus a margin, and is
% subtracted from the design part only (fegeometry subtract, PDE Toolbox). The other parts are untouched. The parts are then
% fused again into one assembly, like in idt_import_geometry. The result has the same fields as model.Geom, so
% it can be meshed and analysed (idt_cutters_verify) or exported (idt_cutters_export_stl). Round holes stay round.
%
% The CAD boolean can be sensitive to the order of the cuts: the order as given, the reversed one and a few shuffled ones
% are tried (fixed seed, reproducible).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    geom = model.Geom;
    ip   = model.Params.Design.Part;
    geom2 = geom;
    if isempty(cut), geom2.Cutters = cut; return; end

    bb  = geom.Parts(ip).BBox;
    mar = max(1e-3, 0.5 * (bb(6) - bb(5)));             % tools stick out of the part, so no faces coincide
    h   = bb(6) - bb(5) + 2 * mar;
    z0  = bb(5) - mar;

    rs = RandStream('twister', 'Seed', 1);
    n  = numel(cut);
    orders = {1:n, n:-1:1};
    for q = 1:10, orders{end + 1} = randperm(rs, n); end %#ok<AGROW>
    D = [];
    for oi = 1:numel(orders)
        D = geom.Parts(ip).Geometry;
        ok = true;
        for k = orders{oi}
            try
                D = subtract(D, make_tool(cut(k), h, z0));
            catch
                ok = false;  break;
            end
        end
        if ok, break; end
    end
    if ~ok, error('idt_cutters_geometry:CutFailed', 'The CAD subtraction failed in %d cut orders. Move or resize the cutters.', numel(orders)); end

    % cut design part: new helper mesh (inside tests), then fuse the parts again
    m = generateMesh(femodel(AnalysisType="structuralStatic", Geometry=D), Hmax=1e-3, GeometricOrder="linear");
    nd = m.Mesh.Nodes';
    geom2.Parts(ip).Geometry = D;
    geom2.Parts(ip).Nodes = nd;
    geom2.Parts(ip).Tets  = m.Mesh.Elements';
    geom2.Parts(ip).BBox  = [min(nd(:,1)) max(nd(:,1)) min(nd(:,2)) max(nd(:,2)) min(nd(:,3)) max(nd(:,3))];
    asm = geom2.Parts(1).Geometry;
    for i = 2:numel(geom2.Parts), asm = union(asm, geom2.Parts(i).Geometry); end
    geom2.Assembly = asm;
    geom2.Cutters  = cut;
    fprintf('Exact CAD geometry: %d cutter(s) subtracted from part %d "%s"; assembly has %d faces.\n', n, ip, geom.Parts(ip).Name, asm.NumFaces);
end

function tool = make_tool(c, h, z0)
% cylinder / box, centered in x and y, base at z = 0; rotate about z, then move to the cutter position
    if strcmp(c.Type, 'hole')
        tool = fegeometry(multicylinder(c.A, h));
    else
        tool = fegeometry(multicuboid(c.A, c.B, h));
        if c.AngleDeg ~= 0, tool = rotate(tool, c.AngleDeg, [0 0 0], [0 0 1]); end
    end
    tool = translate(tool, [c.X, c.Y, z0]);
end
