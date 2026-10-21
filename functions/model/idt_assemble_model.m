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
    model.Damper = [];
    if isfield(P.Design, 'Damper') && ~isempty(P.Design.Damper) && strcmpi(P.Design.Type, 'bricks')
        dm = get_material_properties(P.Design.Damper);                    % damper grade
        sm = get_material_properties(geom.Parts(P.Design.Part).Material);  % structural grade (the design part's own material)
        if abs(dm.nu - sm.nu) > 1e-9
            warning('idt_assemble_model:DamperNu', 'Damper nu (%.2f) differs from the structure (%.2f): the damper stiffness is scaled by E only.', dm.nu, sm.nu);
        end
        eta = dm.LossFactor;  assert(isfinite(eta) && eta >= 0, 'idt_assemble_model:DamperEta', 'P.Design.Damper needs a LossFactor.');
        model.Damper = struct('KScale', dm.E / sm.E, 'RhoScale', dm.rho / sm.rho, 'Eta', eta, 'Material', dm);
        fprintf('  Damper material: a brick is void (X = 0), structure (X = 1) or damper (X = 2): E ratio %.3g, density ratio %.3g, loss factor %.2f\n', ...
            model.Damper.KScale, model.Damper.RhoScale, eta);
    end

    if strcmp(A.Type, 'Static')
        fprintf('  Static load: %.4g N along [%g %g %g]\n', P.BC.LoadAmplitude, P.BC.LoadDirection);
    else
        nPts = numel(A.FreqStart : A.FreqStep : A.FreqEnd);
        fprintf('  Harmonic sweep: %.1f - %.1f Hz, step %.2f Hz (%d points), zeta = %.3f, %d modes\n', ...
            A.FreqStart, A.FreqEnd, A.FreqStep, nPts, A.Zeta, A.NModes);
    end
    fprintf('  Design variables: %d\n\n', model.NumVars);
end
