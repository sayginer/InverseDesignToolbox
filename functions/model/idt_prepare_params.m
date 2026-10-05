function P = idt_prepare_params(P)
% IDT_PREPARE_PARAMS  Load (if a file name is given) and complete the parameter struct.
%
%   P = idt_prepare_params(P)                       P: struct, or the path of a saved parameter file
%
% Missing fields are filled from idt_default_params, so the stage functions
% (idt_import_geometry, idt_make_bricks, idt_make_bc, idt_make_mesh, idt_assemble_model)
% can be called with an incomplete struct.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if ischar(P) || isstring(P)
        f = char(P);
        if ~isfile(f), f = fullfile(idt_root(), f); end
        assert(isfile(f), 'idt_prepare_params:NoFile', 'Parameter file not found: %s', char(P));
        S = load(f, 'P');
        P = S.P;
    end
    P = idt_fill_defaults(P, idt_default_params());
end
