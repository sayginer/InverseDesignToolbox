function fig = plot_transmissibility(model, tr, varargin)
% PLOT_TRANSMISSIBILITY  |T| versus frequency for every output point.
%
%   plot_transmissibility(model, tr)                     one panel per base direction, same-direction response
%   plot_transmissibility(model, tr, 'Base', [3])        only base motion along z
%   plot_transmissibility(model, tr, 'ShowCross', true)  also the cross-axis responses (dashed)
%
% Solid lines: response in the SAME direction as the base motion. Dashed (optional): the other two
% response directions (cross-axis transmission). The dotted line marks T = 1; above sqrt(2) x the
% resonance the structure isolates (T < 1).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)
    p = inputParser;
    addParameter(p, 'Base', 1:3);
    addParameter(p, 'ShowCross', false);
    parse(p, varargin{:});
    dirs = p.Results.Base; lbl = 'xyz';
    nOut = size(tr.Amp, 1);
    col = lines(max(nOut, 1));

    fig = figure('Name', 'Transmissibility', 'Color', 'w', 'Position', [80 70 780 200 * numel(dirs) + 120]);
    for k = 1:numel(dirs)
        b = dirs(k);
        subplot(numel(dirs), 1, k); hold on; grid on;
        for o = 1:nOut
            plot(tr.Freq, squeeze(tr.Amp(o, b, b, :)), '-', 'Color', col(o, :), 'LineWidth', 1.6);
        end
        if p.Results.ShowCross
            for o = 1:nOut
                for c = setdiff(1:3, b)
                    plot(tr.Freq, squeeze(tr.Amp(o, c, b, :)), '--', 'Color', col(o, :), 'LineWidth', 0.8);
                end
            end
        end
        yline(1, 'k:');
        set(gca, 'YScale', 'log');
        for f = tr.NaturalFreqs(:)'
            if f >= tr.Freq(1) && f <= tr.Freq(end), xline(f, 'k:', 'Alpha', 0.4); end
        end
        ylabel(sprintf('|T|, base %s', lbl(b)));
        if k == 1
            title(sprintf('Transmissibility (base excitation) | f_1 = %.0f Hz', tr.NaturalFreqs(1)));
            legend(arrayfun(@(o) sprintf('Output %d (%s)', o, lbl(b)), 1:nOut, 'UniformOutput', false), ...
                   'Location', 'best');
        end
    end
    xlabel('Frequency (Hz)');
end
