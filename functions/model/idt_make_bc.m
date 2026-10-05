function bc = idt_make_bc(P)
% IDT_MAKE_BC  MODEL STAGE C - boundary conditions: supports, load, output points, extra mass.
%
%   bc = idt_make_bc(P)
%
% Uses P.BC (see docs/01_model_setup.md). Look at the result with plot_bc(geom, bc):
% supports red, load arrow magenta, numbered output points green.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    P = idt_prepare_params(P);
    C = P.BC;
    box = C.ExtraMassBox;
    region = @(x, y, z) x >= box(1) & x <= box(2) & y >= box(3) & y <= box(4) & z >= box(5) & z <= box(6);
    bc = define_bc('FixedFaces', C.FixedFaces, 'LoadPoint', C.LoadPoint, ...
                   'LoadDirection', C.LoadDirection, 'LoadAmplitude', C.LoadAmplitude, ...
                   'OutPoints', C.OutPoints, 'ExtraMass', C.ExtraMass, 'ExtraMassRegion', region);
end
