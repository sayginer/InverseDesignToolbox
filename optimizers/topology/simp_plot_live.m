function fig = simp_plot_live(Hst, k, ft)
% SIMP_PLOT_LIVE  Convergence figure: f1 / f2, volume fraction and grey fraction per function evaluation.
%
%   simp_plot_live(History, k, TargetF1)     k = number of evaluations to show; TargetF1 may be [] / NaN
%
% Called by simp_optimize while it runs (H.LivePlot = true); also usable afterwards on out.History:
%   simp_plot_live(out.History, out.Iterations, out.H.TargetF1)
%
% The figure is created once and then only redrawn in place (explicit axes, no figure() / axes() calls),
% so it never jumps in front of the other windows while the optimizer runs.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    fig = findobj('Type', 'figure', 'Tag', 'simp_live');
    if isempty(fig)
        fig = figure('Name', 'SIMP convergence', 'Tag', 'simp_live', 'Color', 'w', 'Position', [120 120 720 520]);
        tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact');
        fig.UserData = struct('ax1', nexttile(tl), 'ax2', nexttile(tl));
    end
    fig = fig(1);
    ax1 = fig.UserData.ax1;  ax2 = fig.UserData.ax2;
    cla(ax1); cla(ax2);
    i = 1:k;
    hold(ax1, 'on'); grid(ax1, 'on');
    plot(ax1, i, Hst.f1(i), 'b-o', 'LineWidth', 1.6, 'MarkerSize', 4, 'MarkerFaceColor', 'b');
    plot(ax1, i, Hst.f2(i), 'c-s', 'LineWidth', 1.0, 'MarkerSize', 3);
    if ~isempty(ft) && isfinite(ft), yline(ax1, ft, 'r--', 'LineWidth', 1.5, 'Label', sprintf('target %.1f Hz', ft)); end
    set(ax1, 'YScale', 'log');
    ylabel(ax1, 'Natural frequency (Hz)'); legend(ax1, {'f_1', 'f_2'}, 'Location', 'best');
    title(ax1, sprintf('SIMP evaluation %d: f_1 = %.2f Hz, beta = %.0f', k, Hst.f1(k), Hst.Beta(k)));
    hold(ax2, 'on'); grid(ax2, 'on');
    plot(ax2, i, Hst.Vol(i) * 100, 'g-', 'LineWidth', 1.6);
    plot(ax2, i, Hst.Grey(i) * 100, 'm-', 'LineWidth', 1.2);
    ylabel(ax2, '% of design domain'); xlabel(ax2, 'Function evaluation');
    legend(ax2, {'volume', 'grey (0.1 < rho < 0.9)'}, 'Location', 'best');
    drawnow limitrate;
end
