function geom = idt_import_geometry(P)
% IDT_IMPORT_GEOMETRY  MODEL STAGE A - import the CAD files and fuse them into one assembly.
%
%   geom = idt_import_geometry(P)
%
% Uses P.Geometry (Files, Names, Materials, Scale). Relative file names start in the toolbox
% folder. Look at the result with plot_geometry(geom): it shows every part and the assembly
% with the FACE NUMBERS you need for P.BC.FixedFaces.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    P = idt_prepare_params(P);
    files = P.Geometry.Files;
    for i = 1:numel(files)
        if ~isfile(files{i}), files{i} = fullfile(idt_root(), files{i}); end
        assert(isfile(files{i}), 'idt_import_geometry:NoCAD', 'CAD file not found: %s', files{i});
    end
    geom = import_geometry(files, 'Names', P.Geometry.Names, 'Materials', P.Geometry.Materials, ...
                           'Scale', P.Geometry.Scale);
end
