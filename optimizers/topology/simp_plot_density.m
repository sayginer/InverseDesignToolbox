function fig = simp_plot_density(model, rho_b, X)
% SIMP_PLOT_DENSITY  Layer-by-layer map of the brick densities (top) and the final solid layout (bottom).
%
%   fig = simp_plot_density(model, rho_b, X)
%
%   rho_b : model.NumVars x 1 brick densities (post.rho_b)      X : model.NumVars x 1 logical (post.X)
%   One column per z layer (layer 1 = bottom). Grey = not a design brick (always solid). Dark = solid.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    N = model.Bricks.Grid.N;
    A = nan(N);  A(model.VarBricks) = rho_b;
    B = nan(N);  B(model.VarBricks) = double(X(:));
    fig = figure('Name', 'SIMP brick layers', 'Color', 'w', 'Position', [100 100 max(260 * N(3), 520) + 60 560]);
    tiledlayout(2, N(3), 'TileSpacing', 'compact');
    for r = 1:2
        for k = 1:N(3)
            nexttile;
            if r == 1, L = A(:, :, k)'; lbl = 'density'; else, L = B(:, :, k)'; lbl = 'solid'; end
            imagesc(L, 'AlphaData', ~isnan(L));
            set(gca, 'YDir', 'normal', 'Color', [0.85 0.85 0.85]);
            axis equal tight; colormap(gca, flipud(gray)); clim([0 1]);
            title(sprintf('%s, layer %d', lbl, k));
        end
    end
    colorbar;
end
