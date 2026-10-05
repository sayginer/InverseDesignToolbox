function model = idt_build_model(P)
% IDT_BUILD_MODEL  Build the complete FEA model from the parameters in one call. No figures.
%
%   model = idt_build_model(P)                     P: parameter struct (see SIM_HarmonicMotion.m, steps 1-5)
%   model = idt_build_model('results/name.mat')    P: a saved parameter file (variable P)
%
% This is simply the five model stages in a row. Optimizers use this one-liner; the simulation
% script calls the stages one by one so you can LOOK at each result before anything is computed:
%
%   geom   = idt_import_geometry(P);            plot_geometry(geom)        A. import the CAD files
%   bricks = idt_make_bricks(P, geom);          plot_bricks(geom, bricks)  B. design domain
%   bc     = idt_make_bc(P);                    plot_bc(geom, bc)          C. supports, load, outputs
%   mesh   = idt_make_mesh(P, geom);            plot_mesh(mesh)            D. tetrahedral mesh
%   model  = idt_assemble_model(P, geom, bricks, bc, mesh)                 E. element matrices
%
% The filled-in parameters are stored in model.Params, so a result always knows how it was made.
% model.NumVars is the number of design variables (0 when there is no design domain).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    P      = idt_prepare_params(P);
    geom   = idt_import_geometry(P);
    bricks = idt_make_bricks(P, geom);
    bc     = idt_make_bc(P);
    mesh   = idt_make_mesh(P, geom);
    model  = idt_assemble_model(P, geom, bricks, bc, mesh);
end
