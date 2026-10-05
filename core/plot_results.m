function figs = plot_results(model, res)
% PLOT_RESULTS  STEP 5 view - displacement FRF (x, y, z at each output point) and mode shapes.
%
%   figs = plot_results(model, res)
%
%   model : from build_model / idt_build_model
%   res   : result of solve_frf (needs res.Valid, .Amp, .Freq, .NaturalFreqs, .Modes, .Active)
%   figs  : [FRF figure, mode-shape figure]
%
% FRF figure: one panel per direction (x, y, z), one curve per output point, natural frequencies as dotted lines.
% Mode figure: the first four mode shapes, deformation exaggerated and colored by displacement magnitude.
% idt_plot_analysis is the usual entry point; it calls this function.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)
    if ~res.Valid, error('plot_results:Invalid', 'Design is not valid (load/output cut off from supports).'); end
    nOut = size(res.Amp, 1); lbl = {'x', 'y', 'z'};
    f1 = figure('Name', 'FRF', 'Color', 'w', 'Position', [60 60 760 620]);
    for c = 1:3
        subplot(3, 1, c); hold on; grid on;
        for o = 1:nOut, plot(res.Freq, squeeze(res.Amp(o, c, :)) * 1e6, 'LineWidth', 1.5); end
        set(gca, 'YScale', 'log');
        for f = res.NaturalFreqs(:)'
            if f >= res.Freq(1) && f <= res.Freq(end), xline(f, 'k:'); end
        end
        ylabel(sprintf('|u_%s| (\\mum)', lbl{c}));
        if c == 1
            title(sprintf('Displacement FRF, F_0 = %.1f N | f_1 = %.0f Hz | modal coverage %.1fx', ...
                model.BC.LoadAmplitude, res.NaturalFreqs(1), res.ModalCoverage));
        end
    end
    xlabel('Frequency (Hz)');
    legend(arrayfun(@(o) sprintf('Output %d', o), 1:nOut, 'UniformOutput', false), 'Location', 'best');

    nMode = min(4, size(res.Modes, 3));
    f2 = figure('Name', 'Mode shapes', 'Color', 'w', 'Position', [120 80 900 700]);
    tiledlayout(2, 2, 'TileSpacing', 'compact');
    F = boundary_faces(model.Elem(res.Active, :));
    diag_len = norm(max(model.Nodes) - min(model.Nodes));
    for k = 1:nMode
        nexttile;
        U = res.Modes(:, :, k); mag = sqrt(sum(U.^2, 2));
        V = model.Nodes + 0.08 * diag_len * U / max(mag);
        patch('Faces', F, 'Vertices', V * 1e3, 'FaceVertexCData', mag / max(mag), 'FaceColor', 'interp', ...
              'EdgeColor', 'none');
        colormap(turbo); clim([0 1]); axis equal; grid on; view(35, 28);
        title(sprintf('Mode %d: %.0f Hz', k, res.NaturalFreqs(k)));
    end
    colorbar;
    figs = [f1 f2];
end
