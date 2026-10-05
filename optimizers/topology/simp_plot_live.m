function fig = simp_plot_live(Hst, k, ft)
% SIMP_PLOT_LIVE  Convergence figure: f1 / f2, volume fraction and grey fraction per function evaluation.
%
%   simp_plot_live(History, k, TargetF1)     k = number of evaluations to show; TargetF1 may be [] / NaN
%
% Called by simp_optimize while it runs (H.LivePlot = true); also usable afterwards on out.History:
%   simp_plot_live(out.History, out.Iterations, out.H.TargetF1)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    fig = findobj('Type', 'figure', 'Tag', 'simp_live');
    if isempty(fig)
        fig = figure('Name', 'SIMP convergence', 'Tag', 'simp_live', 'Color', 'w', 'Position', [120 120 720 520]);
    end
    figure(fig); clf(fig);
    i = 1:k;
    subplot(2, 1, 1); hold on; grid on;
    plot(i, Hst.f1(i), 'b-o', 'LineWidth', 1.6, 'MarkerSize', 4, 'MarkerFaceColor', 'b');
    plot(i, Hst.f2(i), 'c-s', 'LineWidth', 1.0, 'MarkerSize', 3);
    if ~isempty(ft) && isfinite(ft), yline(ft, 'r--', 'LineWidth', 1.5, 'Label', sprintf('target %.1f Hz', ft)); end
    set(gca, 'YScale', 'log');
    ylabel('Natural frequency (Hz)'); legend('f_1', 'f_2', 'Location', 'best');
    title(sprintf('SIMP evaluation %d: f_1 = %.2f Hz, beta = %.0f', k, Hst.f1(k), Hst.Beta(k)));
    subplot(2, 1, 2); hold on; grid on;
    plot(i, Hst.Vol(i) * 100, 'g-', 'LineWidth', 1.6);
    plot(i, Hst.Grey(i) * 100, 'm-', 'LineWidth', 1.2);
    ylabel('% of design domain'); xlabel('Function evaluation'); legend('volume', 'grey (0.1 < rho < 0.9)', 'Location', 'best');
    drawnow;
end
