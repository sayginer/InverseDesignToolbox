function [vmodel, res, met] = idt_cutters_verify(model, geom2)
% IDT_CUTTERS_VERIFY  Check a cutter design with the EXACT geometry: new mesh of the cut CAD part, then the analysis.
%
%   [vmodel, res, met] = idt_cutters_verify(model, geom2)
%
%   model : the model you optimized on (idt_build_model, P.Design.Type = 'none')
%   geom2 : from idt_cutters_geometry(model, cut)
%
% The fast analysis removes mesh elements at the cutter edges, so f1 is only accurate to about the mesh size. This function
% re-meshes the cut CAD geometry (the mesh now follows the real hole and rectangle edges) and analyses that, with the same
% parameters model.Params. It takes a few seconds. Support faces are found again by their position, because face numbers
% change when the CAD is cut.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    P = model.Params;
    P.Design.Type = 'none';
    P.BC.FixedFaces = map_faces(model, geom2.Assembly, P.BC.FixedFaces);
    bricks = idt_make_bricks(P, geom2);
    bc     = idt_make_bc(P);
    mesh   = idt_make_mesh(P, geom2);
    vmodel = idt_assemble_model(P, geom2, bricks, bc, mesh);
    [res, met] = idt_analyze(vmodel);
end

function newFaces = map_faces(model, gNew, oldFaces)
% fixed faces of the original assembly -> the faces of the cut assembly at the same place
    % Sample nodes that lie inside the old face (not on an edge shared with another face), ask the new geometry which face is
    % nearest to each, and take the most frequent answer. Edge nodes would also be near the neighbouring faces.
    mesh = model.Mesh.Mesh;
    nF   = max(oldFaces);  nF = max(nF, model.Geom.Assembly.NumFaces);
    onFace = cell(nF, 1);
    for f = 1:nF, onFace{f} = findNodes(mesh, 'region', 'Face', f)'; end
    newFaces = [];
    for f = oldFaces(:)'
        others = unique(vertcat(onFace{setdiff(1:nF, f)}));
        nn = setdiff(onFace{f}, others);
        if numel(nn) < 3, nn = onFace{f}; end                   % tiny face: use every node
        k = unique(round(linspace(1, numel(nn), min(9, numel(nn)))));
        newFaces(end + 1) = mode(nearestFace(gNew, model.Nodes(nn(k), :))); %#ok<AGROW>
    end
    newFaces = unique(newFaces);
end
