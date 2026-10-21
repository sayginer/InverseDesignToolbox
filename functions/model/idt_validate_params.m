function ok = idt_validate_params(P, geom)
% IDT_VALIDATE_PARAMS  Check a parameter set BEFORE anything is computed and say in plain words what is wrong.
%
%   idt_validate_params(P)            checks that need only the parameters
%   idt_validate_params(P, geom)      also checks face numbers and points against the imported geometry
%   ok = idt_validate_params(P, geom) ok = false if a problem was found (nothing is thrown)
%
% Typical mistakes it catches: a CAD file that is not there, a face number the assembly does not have, a load of zero
% length, millimeters entered where meters are expected, an output point outside the part. With one output argument the
% problems are only printed; without one, a problem stops the script with an error that lists all of them.
% Also useful as a check of what an AI assistant filled into P.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    P = idt_prepare_params(P);
    err = {};  warn = {};

    %% geometry
    nF = numel(P.Geometry.Files);
    for i = 1:nF
        f = P.Geometry.Files{i};
        if ~isfile(f) && ~isfile(fullfile(idt_root(), f)), err{end+1} = sprintf('CAD file not found: %s (put it in cad/)', f); end %#ok<AGROW>
    end
    if numel(P.Geometry.Materials) ~= nF, err{end+1} = sprintf('P.Geometry.Materials has %d entries but there are %d files (one material per file).', numel(P.Geometry.Materials), nF); end
    if numel(P.Geometry.Names) ~= nF, err{end+1} = sprintf('P.Geometry.Names has %d entries but there are %d files.', numel(P.Geometry.Names), nF); end
    if ~isempty(P.Geometry.Rotate) && (numel(P.Geometry.Rotate) ~= 4 || norm(P.Geometry.Rotate(2:4)) == 0)
        err{end+1} = 'P.Geometry.Rotate must be [angle_deg ax ay az] with a non-zero axis, or [].';
    end

    %% design domain
    if ~any(strcmp(P.Design.Type, {'bricks', 'none'})), err{end+1} = 'P.Design.Type must be ''bricks'' or ''none''.'; end
    if strcmp(P.Design.Type, 'bricks')
        if ~(isscalar(P.Design.Part) && P.Design.Part >= 1 && P.Design.Part <= nF && P.Design.Part == round(P.Design.Part))
            err{end+1} = sprintf('P.Design.Part = %g is not a part number; use 1 to %d (position in P.Geometry.Files).', P.Design.Part(1), nF);
        end
        if P.Design.MinPrintSize <= 0 || P.Design.MinPrintSize > 0.05
            warn{end+1} = sprintf('P.Design.MinPrintSize = %g m (%.3g mm): units are meters, 1e-3 = 1 mm.', P.Design.MinPrintSize, P.Design.MinPrintSize * 1e3); %#ok<AGROW>
        end
    end

    %% boundary conditions
    B = P.BC;
    if isempty(B.FixedFaces) || any(B.FixedFaces < 1) || any(B.FixedFaces ~= round(B.FixedFaces))
        err{end+1} = 'P.BC.FixedFaces must list at least one face number (positive integers; read them in the step-1 figure).';
    end
    if ~isempty(B.LoadFaces) && (any(B.LoadFaces < 1) || any(B.LoadFaces ~= round(B.LoadFaces)))
        err{end+1} = 'P.BC.LoadFaces must be positive integers, or [] to load at P.BC.LoadPoint.';
    end
    if numel(B.LoadDirection) ~= 3 || norm(B.LoadDirection) == 0
        err{end+1} = 'P.BC.LoadDirection must be a non-zero [x y z] vector.';
    end
    if B.LoadAmplitude <= 0, err{end+1} = 'P.BC.LoadAmplitude must be positive (newtons).'; end
    if isempty(B.OutPoints) || size(B.OutPoints, 2) ~= 3, err{end+1} = 'P.BC.OutPoints needs one [x y z] row per output point.'; end
    if ~isempty(B.LoadFaces) && ~isempty(B.FixedFaces) && ~isempty(intersect(B.LoadFaces, B.FixedFaces))
        err{end+1} = 'A face is both fixed and loaded (P.BC.FixedFaces and P.BC.LoadFaces share a face number).';
    end

    %% mesh and analysis
    if P.Mesh.Hmax <= 0, err{end+1} = 'P.Mesh.Hmax must be positive.';
    elseif P.Mesh.Hmax > 0.02, err{end+1} = sprintf('P.Mesh.Hmax = %g m (%.3g mm) is huge: units are meters, 2e-3 = 2 mm.', P.Mesh.Hmax, P.Mesh.Hmax * 1e3);
    end
    if ~any(strcmp(P.Mesh.Order, {'linear', 'quadratic'})), err{end+1} = 'P.Mesh.Order must be ''linear'' or ''quadratic''.'; end
    if ~any(strcmp(P.Analysis.Type, {'ModalHarmonic', 'Static'})), err{end+1} = 'P.Analysis.Type must be ''ModalHarmonic'' or ''Static''.'; end

    %% checks against the imported geometry
    if nargin > 1 && ~isempty(geom)
        nFace = geom.Assembly.NumFaces;
        bad = [B.FixedFaces(B.FixedFaces > nFace), B.LoadFaces(B.LoadFaces > nFace)];
        if ~isempty(bad)
            err{end+1} = sprintf('Face number(s) %s do not exist: this assembly has faces 1 to %d (see list_faces(geom)).', mat2str(unique(bad)), nFace); %#ok<AGROW>
        end
        bb = geom.BBox;  tol = 1e-3;
        pts = B.OutPoints;
        if isempty(B.LoadFaces), pts = [pts; B.LoadPoint(:)']; end
        outside = pts(:,1) < bb(1)-tol | pts(:,1) > bb(2)+tol | pts(:,2) < bb(3)-tol | pts(:,2) > bb(4)+tol | pts(:,3) < bb(5)-tol | pts(:,3) > bb(6)+tol;
        if any(outside)
            warn{end+1} = sprintf('%d output / load point(s) lie outside the geometry (box x %.1f..%.1f, y %.1f..%.1f, z %.1f..%.1f mm); the nearest mesh node is used.', ...
                nnz(outside), bb * 1e3); %#ok<AGROW>
        end
    end

    %% report
    ok = isempty(err);
    for k = 1:numel(warn), fprintf('  [warning] %s\n', warn{k}); end
    if ok
        fprintf('Parameter check: OK%s\n', ternary(isempty(warn), '', sprintf(' (%d warning(s))', numel(warn))));
    elseif nargout == 0
        error('idt_validate_params:Invalid', 'The parameters have %d problem(s):\n  - %s', numel(err), strjoin(err, '\n  - '));
    else
        for k = 1:numel(err), fprintf('  [problem] %s\n', err{k}); end
    end
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
