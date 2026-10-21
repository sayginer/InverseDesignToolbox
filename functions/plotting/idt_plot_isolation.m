function fig = idt_plot_isolation(res, I, titleText)
% IDT_PLOT_ISOLATION  Transmissibility of the protected outputs with the isolation band marked.
%
%   fig = idt_plot_isolation(res, I)
%   fig = idt_plot_isolation(res, I, titleText)
%
%   res : analysis result with transmissibility (res.TAmp, res.Freq, res.NaturalFreqs)
%   I   : isolation settings (idt_isolation_options)
%
% One curve per output point and direction pair (log scale; T = 0.1 is -20 dB). The shaded area is the
% band that must be blocked (blue), the optional flat passband with its tolerance (green box), the dotted line is T = 1 (below it the vibration is reduced), dashed vertical lines are the natural
% frequencies. The marker is the largest T inside the band, the number the optimizer minimized.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    [peakT, info] = idt_isolation_metric(res, I);
    assert(~isnan(peakT), 'idt_plot_isolation:NoT', 'The result has no transmissibility (set P.Analysis.Transmissibility = true).');
    lbl = 'xyz';  f = res.Freq(:);
    fig = figure('Name', 'Isolation', 'Color', 'w', 'Position', [100 100 820 460]);
    hold on; grid on;
    yl = [min(0.01, 0.5 * min(res.TAmp(:))), 2 * max(2, max(res.TAmp(I.Output, :, :, :), [], 'all'))];
    patch([I.Band(1) I.Band(2) I.Band(2) I.Band(1)], [yl(1) yl(1) yl(2) yl(2)], [0.85 0.93 1], 'EdgeColor', 'none', 'FaceAlpha', 0.7, ...
          'HandleVisibility', 'off');
    if ~isempty(I.Pass)                              % flat passband: green, with the tolerance lines
        lo = 10^(-I.PassTol / 20);  hi = 10^(I.PassTol / 20);
        patch([I.Pass(1) I.Pass(2) I.Pass(2) I.Pass(1)], [lo lo hi hi], [0.8 0.95 0.8], 'EdgeColor', [0.2 0.6 0.2], 'FaceAlpha', 0.8, 'HandleVisibility', 'off');
    end
    names = {};
    for o = I.Output(:)'
        for k = 1:size(I.Pairs, 1)
            plot(f, squeeze(res.TAmp(o, I.Pairs(k, 1), I.Pairs(k, 2), :)), 'LineWidth', 1.6);
            names{end + 1} = sprintf('output %d, base %s -> response %s', o, lbl(I.Pairs(k, 2)), lbl(I.Pairs(k, 1))); %#ok<AGROW>
        end
    end
    yline(1, 'k:', 'T = 1', 'HandleVisibility', 'off');
    for fn = res.NaturalFreqs(:)'
        if fn >= f(1) && fn <= f(end), xline(fn, 'k--', 'Alpha', 0.3, 'HandleVisibility', 'off'); end
    end
    w = info.Worst;
    plot(w.PeakFreq, w.PeakT, 'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 8, 'HandleVisibility', 'off');
    set(gca, 'YScale', 'log'); ylim(yl); xlim([f(1) f(end)]);
    xlabel('Frequency (Hz)'); ylabel('|T| (response / base motion)');
    legend(names, 'Location', 'best');
    if nargin < 3, titleText = ''; end
    title(sprintf('%sband %g-%g Hz: peak T = %.3g (%.1f dB) at %.0f Hz | f_1 = %.0f Hz', titleText, I.Band, peakT, 20 * log10(peakT), ...
          w.PeakFreq, res.NaturalFreqs(1)));
end
