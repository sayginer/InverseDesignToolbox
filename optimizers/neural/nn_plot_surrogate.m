function fig = nn_plot_surrogate(out)
% NN_PLOT_SURROGATE  How good is the network? Predicted vs true f1, and progress over the rounds.
%
%   fig = nn_plot_surrogate(out)          out: result of nn_optimize
%
%   left : held-back layouts (not used for fitting) - predicted f1 against the real FEA f1, ideal = diagonal
%   right: per round - error of the network on the candidates the search proposed, before and after the
%          calibration pass (bars), and the f1 of the best verified candidate (line) against the target
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    sur = out.sur;  H = out.H;
    fig = figure('Name', 'Neural network surrogate', 'Color', 'w', 'Position', [100 100 1000 420]);
    tiledlayout(1, 2, 'TileSpacing', 'compact');

    nexttile; hold on; grid on;
    plot(sur.val.f1True, sur.val.f1Pred, 'b.', 'MarkerSize', 12);
    lim = [min([sur.val.f1True; sur.val.f1Pred]) * 0.8, max([sur.val.f1True; sur.val.f1Pred]) * 1.2];
    plot(lim, lim, 'k--');
    set(gca, 'XScale', 'log', 'YScale', 'log'); xlim(lim); ylim(lim); axis square;
    xlabel('f_1 from the FEA (Hz)'); ylabel('f_1 predicted by the network (Hz)');
    title(sprintf('Held-back layouts: R^2 = %.2f, mean error %.0f %%', sur.metrics.R2, sur.metrics.MAPE));

    nexttile; hold on; grid on;
    R = out.Rounds;  k = 1:numel(R);
    yyaxis left;  hb = bar(k, [[R.errFirst]' [R.errLast]'], 0.7);  ylabel('surrogate error on its proposals (%)');
    yyaxis right; plot(k, [R.candBest], 'o-', 'LineWidth', 1.8, 'MarkerFaceColor', 'auto');
    if strcmp(H.Objective, 'TargetF1'), yline(H.TargetF1, 'r--', 'Label', 'target'); end
    legend(hb, {'error before calibration', 'error after calibration'}, 'Location', 'northwest');
    ylabel('f_1 of the best verified candidate (Hz)');
    xlabel('Round'); xticks(k);
    title('Search on the surrogate, verified by FEA');
end
