function fig = genetic_plot_history(out)
% GENETIC_PLOT_HISTORY  Convergence of the genetic algorithm: best and mean cost per generation.
%
%   fig = genetic_plot_history(out)          out: result of genetic_optimize
%
% The cost is the goal (smaller is better): for 'TargetF1' ((f1 - target)/target)^2, so 1e-4 means f1 is 1 % off;
% 50 means the individual could not be analysed. The gap between best and mean shows how diverse the population still is.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    h = out.History;  k = 0:numel(h.best) - 1;
    fig = figure('Name', 'Genetic algorithm', 'Color', 'w', 'Position', [100 100 700 420]);
    hold on; grid on;
    plot(k, h.mean, 'c-', 'LineWidth', 1.4);
    plot(k, h.best, 'b-o', 'LineWidth', 1.8, 'MarkerSize', 4, 'MarkerFaceColor', 'b');
    if strcmp(out.H.Objective, 'TargetF1'), set(gca, 'YScale', 'log'); end
    xlabel('Generation'); ylabel('Cost');
    legend('population mean', 'best', 'Location', 'northeast');
    title(sprintf('GA: %d analyses, best cost %.2g, final f_1 = %.2f Hz', out.NumEvaluations, h.best(end), out.met.f1));
end
