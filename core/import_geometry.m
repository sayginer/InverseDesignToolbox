function geom = import_geometry(files, varargin)
% IMPORT_GEOMETRY  STEP 1 - import one or more CAD files (STEP, STL, IGES ...).
%
%   geom = import_geometry({'a.STEP','b.STEP'}, 'Names', {'Frame','Plate'}, ...
%                          'Materials', {'Aluminum-6061','Structural-Steel'})
%
% NAME-VALUE
%   'Names'      display name per file (default: file name)
%   'Materials'  material per file, see get_material_properties.m
%   'Scale'      factor to convert file units to METERS. Default 1, because STEP/IGES
%                files are converted to meters on import. Use 1e-3 for an STL in mm.
%   'InsideMeshHmax'  size of the coarse helper mesh used only for inside/outside
%                tests (default 1 mm)
%
% The parts are fused (union) into ONE conformal assembly, so they share nodes at
% their interfaces. Face numbers used for boundary conditions refer to
% geom.Assembly (see plot_geometry / list_faces). Order matters: if parts overlap,
% the first one in the list owns the overlap.
%
% OUTPUT geom: .Parts(i) {Name, File, Material, Geometry, BBox, Nodes, Tets},
%              .Assembly (fegeometry, meters), .BBox
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'Names', []);
    addParameter(p, 'Materials', []);
    addParameter(p, 'Scale', 1);
    addParameter(p, 'InsideMeshHmax', 1e-3);
    parse(p, varargin{:});
    r = p.Results;

    if ischar(files) || isstring(files), files = cellstr(files); end
    n = numel(files);
    names = r.Names; if isempty(names), names = cell(1, n); end
    mats  = r.Materials; if isempty(mats), mats = repmat({'Aluminum-6061'}, 1, n); end

    parts = struct('Name', {}, 'File', {}, 'Material', {}, 'Geometry', {}, ...
                   'BBox', {}, 'Nodes', {}, 'Tets', {});
    for i = 1:n
        gm = fegeometry(files{i});
        if r.Scale ~= 1, gm = scale(gm, r.Scale); end
        ext = max(max(gm.Vertices) - min(gm.Vertices));
        if ext > 1
            warning('import_geometry:Units', ['Part "%s" is %.1f units across. If the file is in mm, ' ...
                'pass ''Scale'', 1e-3 so that the model is in meters.'], files{i}, ext);
        end
        % coarse helper mesh (inside tests and brick occupancy only)
        m = generateMesh(femodel(AnalysisType="structuralStatic", Geometry=gm), ...
                         Hmax=r.InsideMeshHmax, GeometricOrder="linear");
        nd = m.Mesh.Nodes';
        nm = names{i}; if isempty(nm), [~, nm] = fileparts(files{i}); end
        parts(i) = struct('Name', nm, 'File', files{i}, 'Material', mats{i}, 'Geometry', gm, ...
            'BBox', [min(nd(:,1)) max(nd(:,1)) min(nd(:,2)) max(nd(:,2)) min(nd(:,3)) max(nd(:,3))], ...
            'Nodes', nd, 'Tets', m.Mesh.Elements');
    end

    asm = parts(1).Geometry;
    for i = 2:n, asm = union(asm, parts(i).Geometry); end

    bb = cat(1, parts.BBox);
    geom = struct('Parts', parts, 'Assembly', asm, ...
        'BBox', [min(bb(:,1)) max(bb(:,2)) min(bb(:,3)) max(bb(:,4)) min(bb(:,5)) max(bb(:,6))]);

    fprintf('--- Geometry imported ---\n');
    for i = 1:n
        mLabel = parts(i).Material;
        if isstruct(mLabel) && isfield(mLabel, 'Name'), mLabel = mLabel.Name;
        elseif isstruct(mLabel), mLabel = 'Custom struct'; end
        b = parts(i).BBox * 1e3;
        fprintf('  Part %d "%s" [%s]: %.1f x %.1f x %.1f mm, %d faces\n', i, parts(i).Name, ...
            mLabel, b(2)-b(1), b(4)-b(3), b(6)-b(5), parts(i).Geometry.NumFaces);
    end
    fprintf('  Assembly: %d faces, %d cell(s)\n\n', asm.NumFaces, asm.NumCells);
end
