function fig = genetic_plot_live(hist, name, logY)
% GENETIC_PLOT_LIVE  Convergence figure that is redrawn while a genetic algorithm runs.
%
%   genetic_plot_live(hist, name)         hist.best, hist.mean: cost per generation so far; name: shown in the title
%   genetic_plot_live(hist, name, true)   logarithmic cost axis (cost goals that go towards zero)
%
% Used by genetic_optimize, shape_optimize and static_ga_optimize when LivePlot is true. The figure is
% created once and then only redrawn in place (explicit axes, no figure() call), so it never jumps in
% front of the other windows. Afterwards genetic_plot_history / static_plot_history draw the final plot.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 3, logY = false; end
    fig = findobj('Type', 'figure', 'Tag', 'ga_live');
    if isempty(fig)
        fig = figure('Name', 'GA convergence (live)', 'Tag', 'ga_live', 'Color', 'w', 'Position', [100 100 700 420]);
        fig.UserData = struct('ax', axes(fig));
    end
    fig = fig(1);
    ax = fig.UserData.ax;
    cla(ax); hold(ax, 'on'); grid(ax, 'on');
    k = 0:numel(hist.best) - 1;
    plot(ax, k, hist.mean, 'c-', 'LineWidth', 1.4);
    plot(ax, k, hist.best, 'b-o', 'LineWidth', 1.8, 'MarkerSize', 4, 'MarkerFaceColor', 'b');
    if logY, set(ax, 'YScale', 'log'); else, set(ax, 'YScale', 'linear'); end
    xlabel(ax, 'Generation'); ylabel(ax, 'Cost');
    legend(ax, {'population mean', 'best'}, 'Location', 'northeast');
    title(ax, sprintf('%s: generation %d, best cost %.4g', name, k(end), hist.best(end)));
    drawnow limitrate;
end
