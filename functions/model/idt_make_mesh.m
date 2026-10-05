function mesh = idt_make_mesh(P, geom)
% IDT_MAKE_MESH  MODEL STAGE D - free tetrahedral mesh of the real CAD geometry.
%
%   mesh = idt_make_mesh(P, geom)
%
% Uses P.Mesh (Hmax, Order, Refine). The mesh follows the CAD surfaces and is independent of the
% bricks. Look at the result with plot_mesh(mesh): surface and cut-away.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    P = idt_prepare_params(P);
    mesh = generate_mesh(geom, 'Hmax', P.Mesh.Hmax, 'Order', P.Mesh.Order, 'Refine', P.Mesh.Refine);
end
