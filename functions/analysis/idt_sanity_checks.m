function chk = idt_sanity_checks(model, res, met)
% IDT_SANITY_CHECKS  Print the checks every simulation result should pass before you believe it.
%
%   idt_sanity_checks(model, res, met)        after  [res, met] = idt_analyze(model, X)
%   chk = idt_sanity_checks(...)              chk.Ok = true if every check passed; chk.Lines = the printed lines
%
% Static:    support reactions add up to the load | no floating pieces | mesh clearly finer than the bricks
% Harmonic:  enough modes kept for the sweep (modal coverage > 1.5) | no floating pieces | mesh finer than the bricks
% A [CHECK] line is not always an error, it is a reason to look closer (a finer mesh, more modes, the figure).
% It does NOT replace thinking: compare the result with a hand estimate and ask whether the model is the one you meant.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    lines = {};  ok = true;
    function add(pass, txt)
        if pass, lines{end+1} = ['  [ok]    ' txt]; else, lines{end+1} = ['  [CHECK] ' txt]; ok = false; end %#ok<AGROW>
    end

    P = model.Params;
    if ~met.Valid
        add(false, 'the design is not valid: the load / output points are cut off from every support');
    else
        if strcmp(P.Analysis.Type, 'Static')
            F = P.BC.LoadAmplitude;
            d = P.BC.LoadDirection(:)' / norm(P.BC.LoadDirection);
            err = norm(res.Reaction + F * d) / F;
            add(err < 1e-6, sprintf('support reactions add up to minus the load (relative error %.1e)', err));
        else
            add(res.ModalCoverage > 1.5, sprintf('modal coverage %.2fx (the highest kept mode should be above 1.5 x the sweep end)', res.ModalCoverage));
        end
        add(met.Dropped == 0, sprintf('%d mesh elements float free of the supports (a piece of the design is not connected)', met.Dropped));
    end

    if strcmp(P.Design.Type, 'bricks')
        g = model.Bricks.Grid;
        edge = min(g.Size(g.N > 1));                 % thinnest brick edge in a direction with more than one brick
        h = P.Mesh.Hmax;
        add(h <= 0.7 * edge, sprintf('mesh size %.2f mm vs smallest brick edge %.2f mm (want mesh <= 0.7 x brick; otherwise some bricks cannot be switched)', ...
            h * 1e3, edge * 1e3));
    end
    if strcmp(P.Mesh.Order, 'linear')
        lines{end+1} = '  [note]  linear (TET4) elements are too stiff in bending; use P.Mesh.Order = ''quadratic'' for final numbers';
    end

    fprintf('Sanity checks:\n%s\n', strjoin(lines, newline));
    chk = struct('Ok', ok, 'Lines', {lines});
end
