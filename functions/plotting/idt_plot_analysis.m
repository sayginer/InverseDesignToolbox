function figs = idt_plot_analysis(model, X, res, varargin)
% IDT_PLOT_ANALYSIS  Show the result of an eigenfrequency + harmonic analysis.
%
%   figs = idt_plot_analysis(model, X, res)
%   figs = idt_plot_analysis(model, X, res, 'Design', true, 'Modes', true, 'Transmissibility', true)
%
%   1. the 3-D layout (removed bricks are gone), with supports, load and output points   ('Design')
%   2. force FRF: displacement amplitude in x, y, z at every output point, natural frequencies dotted
%   3. mode shapes (first four)                                              ('Modes')
%   4. base-excitation transmissibility, if it was computed                  ('Transmissibility')
%
% X may be [] (all bricks present / no design domain). Figure text uses the model's own units.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'Design', true);                    % false = do not (re)draw the 3-D layout
    addParameter(p, 'Modes', true);
    addParameter(p, 'Transmissibility', true);
    parse(p, varargin{:});
    assert(res.Valid, 'idt_plot_analysis:Invalid', ...
        'Design is not valid (load/output points are cut off from the supports).');

    figs = gobjects(0);
    if p.Results.Design, figs = plot_design(model, X); end
    r = plot_results(model, res);                       % [FRF figure, mode-shape figure]
    figs = [figs, r(1)];
    if p.Results.Modes
        figs = [figs, r(2)];
    else
        close(r(2));
    end
    if p.Results.Transmissibility && isfield(res, 'T')
        tr = struct('Freq', res.Freq, 'NaturalFreqs', res.NaturalFreqs, 'Amp', res.TAmp);
        figs = [figs, plot_transmissibility(model, tr)];
    end
end
