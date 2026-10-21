function fig = static_plot_history(out)
% STATIC_PLOT_HISTORY  Convergence of a static optimizer run (SIMP or GA).
%
%   fig = static_plot_history(out)       out: result of static_simp_optimize or static_ga_optimize
%
% SIMP: compliance (left) and volume fraction (right) per iteration.
% GA:   best and mean cost per generation (cost 1 = the full, unoptimized beam).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if strcmp(out.Method, 'NN')
        fig = figure('Name', 'NN convergence', 'Color', 'w', 'Position', [100 100 1400 420]);
        tiledlayout(1, 3, 'TileSpacing', 'compact');
        nexttile; hold on; grid on;                                % network quality on layouts it was not trained on
        v = out.sur.val;
        plot(v.f1True, v.f1Pred, 'b.', 'MarkerSize', 12);
        lim = [min([v.f1True; v.f1Pred]) * 0.9, max([v.f1True; v.f1Pred]) * 1.1];
        plot(lim, lim, 'k--'); xlim(lim); ylim(lim); axis square;
        xlabel('relative stiffness from the analysis'); ylabel('predicted by the network');
        title(sprintf('Held-back layouts: R^2 = %.2f, mean error %.0f %%', out.sur.metrics.R2, out.sur.metrics.MAPE));
        nexttile; hold on; grid on;                                % progress per round
        R = out.Rounds;  k = 1:numel(R);
        plot(k, [R.bestCompliance] * 1e3, 'o-', 'LineWidth', 1.8, 'MarkerFaceColor', 'auto');
        xlabel('Round'); xticks(k); ylabel('Best verified compliance F''u (mJ)');
        title('Best layout found, verified by the real analysis');
        nexttile; hold on; grid on;                                % the GA that searches the network
        g = out.GAHistory;  kk = 1:numel(g.best);
        plot(kk, g.mean, 'c-', 'LineWidth', 1.2);  plot(kk, g.best, 'b-', 'LineWidth', 1.8);
        for s = g.start(2:end), xline(s - 0.5, 'k:'); end
        xlabel('Generation (all searches in a row; dotted = new search)'); ylabel('Surrogate cost');
        legend('population mean', 'best', 'Location', 'northeast');
        title('GA on the surrogate: convergence');
        return;
    end
    fig = figure('Name', [out.Method ' convergence'], 'Color', 'w', 'Position', [100 100 700 420]);
    if strcmp(out.Method, 'SIMP')
        h = out.History;  k = 1:numel(h.Compliance);
        yyaxis left;  plot(k, h.Compliance * 1e3, 'b-', 'LineWidth', 1.8); ylabel('Compliance F''u (mJ)');
        yyaxis right; plot(k, h.Volume, 'r--', 'LineWidth', 1.4); ylabel('Volume fraction (mean density)');
        xlabel('Iteration'); grid on;
        title(sprintf('SIMP: %d iterations, final compliance %.4g mJ', out.Iterations, out.met.Compliance * 1e3));
    else
        h = out.History;  k = 0:numel(h.best) - 1;
        hold on; grid on;
        plot(k, h.mean, 'c-', 'LineWidth', 1.4);
        plot(k, h.best, 'b-o', 'LineWidth', 1.8, 'MarkerSize', 4, 'MarkerFaceColor', 'b');
        xlabel('Generation'); ylabel('Cost (1 = full beam)');
        legend('population mean', 'best', 'Location', 'northeast');
        title(sprintf('GA: %d analyses, best cost %.3g', out.NumEvaluations, h.best(end)));
    end
end
