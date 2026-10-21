function T = idt_export_dataset(model, n, name, varargin)
% IDT_EXPORT_DATASET  Analyse n random brick layouts and save layouts + results as a CSV file for machine learning.
%
%   T = idt_export_dataset(model, n, 'beam_data')
%   T = idt_export_dataset(model, n, 'beam_data', 'Seed', 1, 'VolFracRange', [0.3 0.7], 'FieldRadius', 10e-3)
%
% Writes (in results/):
%   <name>.csv            one row per layout: brick_1 ... brick_N (1 = present, 0 = removed), vol_frac, valid, then the results
%   <name>_bricks.csv     what brick_k is: grid index (i, j, k) and center position (x, y, z) in mm
%   <name>_README.txt     the columns in words, how the data was made, which problem it belongs to
% Results per layout (NaN where the layout is not valid, i.e. cut off from the supports):
%   static    : compliance_mJ, tip_defl_um (output 1 along the load), max_disp_um, max_vonMises_MPa, mass_g
%   harmonic  : f1_Hz, f2_Hz, mass_g
% Use the file in MATLAB (Regression Learner app, readtable) or in any other tool (Python, Excel). Layouts are random smooth
% shapes (idt_random_layouts), so a model trained on them has only seen layouts of that kind.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'Seed', 1);
    addParameter(p, 'VolFracRange', [0.3 0.7]);
    addParameter(p, 'FieldRadius', 10e-3);
    parse(p, varargin{:});
    o = p.Results;
    assert(model.NumVars > 0, 'idt_export_dataset:NoDesign', 'The model has no design bricks.');
    isStatic = strcmp(model.Params.Analysis.Type, 'Static');
    if isStatic
        cols = {'compliance_mJ', 'tip_defl_um', 'max_disp_um', 'max_vonMises_MPa', 'mass_g'};
        d = model.BC.LoadDirection(:)' / norm(model.BC.LoadDirection);
    else
        cols = {'f1_Hz', 'f2_Hz', 'mass_g'};
        d = [];
    end

    rs = RandStream('twister', 'Seed', o.Seed);
    X = idt_random_layouts(model, n, o.VolFracRange, o.FieldRadius, rs);
    ev = model.ElemVar;
    volBrick = accumarray(ev(ev > 0), model.Vol(ev > 0), [model.NumVars, 1]);
    Y = nan(n, numel(cols));  valid = false(n, 1);
    fprintf('Dataset: analysing %d layouts...\n', n);
    t0 = tic;
    parfor i = 1:n
        [~, m] = idt_analyze(model, X(i, :)');
        r = nan(1, numel(cols));
        if m.Valid
            if isStatic
                r = [m.Compliance * 1e3, abs(m.OutDefl(1, :) * d') * 1e6, m.MaxDisp * 1e6, m.MaxVonMises * 1e-6, m.Mass * 1e3];
            else
                r = [m.f1, m.f2, m.Mass * 1e3];
            end
        end
        Y(i, :) = r;  valid(i) = m.Valid;
    end
    fprintf('  done in %.1f s (%.2f s per layout)\n', toc(t0), toc(t0) / n);

    names = compose('brick_%d', 1:model.NumVars);
    T = [array2table(double(X), 'VariableNames', names), ...
         table((double(X) * volBrick) / sum(volBrick), double(valid), 'VariableNames', {'vol_frac', 'valid'}), ...
         array2table(Y, 'VariableNames', cols)];

    dirOut = fullfile(idt_root(), 'results');
    if ~isfolder(dirOut), mkdir(dirOut); end
    writetable(T, fullfile(dirOut, [name '.csv']));
    g = model.Bricks.Grid;
    [bi, bj, bk] = ind2sub(g.N, model.VarBricks);
    ctr = (g.Min + ([bi bj bk] - 0.5) .* g.Size) * 1e3;
    B = table((1:model.NumVars)', bi, bj, bk, ctr(:,1), ctr(:,2), ctr(:,3), ...
              'VariableNames', {'brick', 'i', 'j', 'k', 'x_mm', 'y_mm', 'z_mm'});
    writetable(B, fullfile(dirOut, [name '_bricks.csv']));

    fid = fopen(fullfile(dirOut, [name '_README.txt']), 'w');
    fprintf(fid, 'Dataset %s - made with idt_export_dataset (InverseDesignToolbox, Dr. Osman Sayginer)\n\n', name);
    fprintf(fid, 'Problem     : %s analysis, %d design bricks on a %d x %d x %d grid\n', model.Params.Analysis.Type, model.NumVars, g.N);
    fprintf(fid, 'Layouts     : %d random smooth layouts, volume fraction %.2f - %.2f, field radius %.1f mm, seed %d\n', n, o.VolFracRange, o.FieldRadius * 1e3, o.Seed);
    fprintf(fid, 'Mesh        : Hmax %.2f mm, %s elements\n', model.Params.Mesh.Hmax * 1e3, model.Params.Mesh.Order);
    if isStatic, fprintf(fid, 'Load        : %.4g N along [%g %g %g]\n', model.BC.LoadAmplitude, model.BC.LoadDirection); end
    fprintf(fid, '\nColumns of %s.csv\n', name);
    fprintf(fid, '  brick_1 ... brick_%d : 1 = brick present, 0 = removed (positions: %s_bricks.csv)\n', model.NumVars, name);
    fprintf(fid, '  vol_frac            : volume of the present bricks / volume of all design bricks\n');
    fprintf(fid, '  valid               : 1 = the layout connects the load to the supports; 0 = cut off (results are empty)\n');
    fprintf(fid, '  %s\n', strjoin(cols, ', '));
    fprintf(fid, '\nUnits: mJ, um, MPa, g, Hz as in the column names. Machine-learning hint: use only valid = 1 rows.\n');
    fclose(fid);
    fprintf('Saved results/%s.csv (%d rows), %s_bricks.csv and %s_README.txt\n', name, n, name, name);
end
