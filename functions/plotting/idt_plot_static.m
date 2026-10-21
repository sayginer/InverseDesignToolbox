function figs = idt_plot_static(model, X, res, varargin)
% IDT_PLOT_STATIC  Show the result of a static analysis: deformed shape and von Mises stress.
%
%   figs = idt_plot_static(model, X, res)
%   figs = idt_plot_static(model, X, res, 'Scale', 50)     'Scale' = deformation magnification
%
%   1. displacement magnitude on the deformed shape (grey outline = undeformed)
%   2. von Mises stress on the deformed shape
%   3. displacement components (u_x, u_y, u_z) at the output points
%
% X may be [] (all bricks present). Lengths in the figures are mm, stress MPa.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'Scale', 0);              % 0 = automatic: largest displacement = 8 % of the largest model size
    parse(p, varargin{:});
    assert(res.Valid, 'idt_plot_static:Invalid', ...
        'Design is not valid (load/output points are cut off from the supports).');

    if nargin < 2 || isempty(X), X = true(model.NumVars, 1); end
    X = X(:) > 0.5;
    ev = model.ElemVar; act = ev == 0; act(ev > 0) = X(ev(ev > 0));
    act = act & res.Active;
    [F, own] = boundary_faces(model.Elem(act, :));
    ids = find(act); owner = ids(own);

    s = p.Results.Scale;
    if s <= 0
        ext = max(max(model.Nodes) - min(model.Nodes));
        s = 0.08 * ext / max(max(res.UMag), eps);
    end
    V0 = model.Nodes * 1e3;
    V1 = (model.Nodes + s * res.U) * 1e3;

    figs = gobjects(1, 3);
    for k = 1:2
        figs(k) = figure('Color', 'w', 'Position', [150 + 40*k 110 + 30*k 780 560]);
        patch('Faces', F, 'Vertices', V0, 'FaceColor', 'none', 'EdgeColor', [0.75 0.75 0.75], 'EdgeAlpha', 0.5);
        hold on;
        if k == 1
            figs(k).Name = 'Static: displacement';
            cd = res.UMag(F) * 1e3;                               % per-vertex, mm
            patch('Faces', F, 'Vertices', V1, 'FaceVertexCData', cd(:), 'FaceColor', 'interp', ...
                  'EdgeColor', 'none');
            cb = colorbar; cb.Label.String = '|u| (mm)';
            title(sprintf('Displacement  (max %.4g mm, deformation x%.0f)', max(res.UMag) * 1e3, s));
        else
            figs(k).Name = 'Static: von Mises stress';
            cf = res.VonMises(owner) * 1e-6;                       % per face (element value), MPa
            patch('Faces', F, 'Vertices', V1, 'FaceVertexCData', cf, 'FaceColor', 'flat', 'EdgeColor', 'none');
            cb = colorbar; cb.Label.String = 'von Mises (MPa)';
            cmax = prctile(cf, 99);                                % clip the single-node hot spots in the colors
            if cmax > 0, clim([0 cmax]); end
            title(sprintf('von Mises stress  (peak %.3g MPa, colors clipped at the 99th percentile)', ...
                          max(res.VonMises, [], 'omitnan') * 1e-6));
        end
        colormap(turbo);
        axis equal tight; grid on; view(25, 22); camlight headlight; lighting gouraud;
        c = V1;
        plot3(c(model.FixedNodes,1), c(model.FixedNodes,2), c(model.FixedNodes,3), 'r^', 'MarkerFaceColor', 'r', 'MarkerSize', 3);
        d = model.BC.LoadDirection(:)' / norm(model.BC.LoadDirection); L = 12;
        lp = mean(c(model.LoadNodes, :), 1);
        quiver3(lp(1)-L*d(1), lp(2)-L*d(2), lp(3)-L*d(3), L*d(1), L*d(2), L*d(3), 0, 'm', 'LineWidth', 2.5, 'MaxHeadSize', 1);
        xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
    end

    % 3. displacement components at the output points (x-y plot: output point vs displacement)
    figs(3) = figure('Name', 'Static: displacement at the output points', 'Color', 'w', 'Position', [230 170 640 420]);
    U = res.OutU * 1e6;                                       % [nOut x 3], um
    n = size(U, 1);
    plot(1:n, U(:, 1), '-o', 1:n, U(:, 2), '-s', 1:n, U(:, 3), '-^', 'LineWidth', 1.6, 'MarkerSize', 7);
    grid on; xlim([0.5 n + 0.5]); xticks(1:n);
    lab = arrayfun(@(i) sprintf('output %d', i), 1:n, 'UniformOutput', false);
    if isfield(model.BC, 'OutPoints') && size(model.BC.OutPoints, 1) == n
        for i = 1:n
            lab{i} = sprintf('output %d\n(%.0f, %.0f, %.0f) mm', i, model.BC.OutPoints(i, :) * 1e3);
        end
    end
    xticklabels(lab);
    xlabel('output point (coordinates in mm)'); ylabel('displacement (\mum)');
    legend({'u_x', 'u_y', 'u_z'}, 'Location', 'best');
    title('Displacement at the output points');
end
