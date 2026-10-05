function model = idt_assemble_model(P, geom, bricks, bc, mesh)
% IDT_ASSEMBLE_MODEL  MODEL STAGE E - link the stages and precompute all element matrices once.
%
%   model = idt_assemble_model(P, geom, bricks, bc, mesh)
%
% Takes the results of stages A-D (idt_import_geometry, idt_make_bricks, idt_make_bc,
% idt_make_mesh), assigns every mesh element to its part and brick, and builds the stiffness
% and mass data. Prints how many design variables there are and warns about bricks that are
% too small for the mesh. The returned model is what idt_analyze and the optimizers use.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    P = idt_prepare_params(P);
    A = P.Analysis;
    fr = struct('Start', A.FreqStart, 'End', A.FreqEnd, 'Step', A.FreqStep, ...
                'N', 120, 'Zeta', A.Zeta, 'NModes', A.NModes);
    model = build_model(geom, bricks, bc, mesh, 'Freq', fr);
    model.Params = P;

    nPts = numel(A.FreqStart : A.FreqStep : A.FreqEnd);
    fprintf('  Harmonic sweep: %.1f - %.1f Hz, step %.2f Hz (%d points), zeta = %.3f, %d modes\n', ...
        A.FreqStart, A.FreqEnd, A.FreqStep, nPts, A.Zeta, A.NModes);
    fprintf('  Design variables: %d\n\n', model.NumVars);
end
