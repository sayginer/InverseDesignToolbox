function info = idt_stl_check(stl, units, preview, content)
% IDT_STL_CHECK  Read an STL file back, check that it is a closed single solid, and preview it.
%
%   info = idt_stl_check(stl, units, preview, content)
%
%   stl      path of the STL file          units  'mm' or 'm' (only for the text)
%   preview  true = show the 3-D and top view of the saved file        content  text for info.Content
%
% info: .File, .Content, .Watertight (every edge belongs to exactly two triangles: slicers need this), .Shells (separate
% solid pieces, 1 = one part), .Volume, .BBox, .NumTriangles, .Units, .Figure
% Used by idt_export_stl (brick designs) and idt_cutters_export_stl (cutter designs).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 2, units = 'mm'; end
    if nargin < 3, preview = true; end
    if nargin < 4, content = ''; end
    [~, name] = fileparts(stl);
    T = stlread(stl);
    F = T.ConnectivityList;  V = T.Points;
    e = sort([F(:, [1 2]); F(:, [2 3]); F(:, [3 1])], 2);
    [~, ~, ic] = unique(e, 'rows');
    cnt = accumarray(ic, 1);
    watertight = all(cnt == 2);
    shells = max(conncomp(graph([F(:, 1); F(:, 2); F(:, 3)], [F(:, 2); F(:, 3); F(:, 1)], [], size(V, 1))));   % separate pieces
    a = V(F(:, 1), :);  b = V(F(:, 2), :);  c = V(F(:, 3), :);
    vol = abs(sum(dot(a, cross(b, c, 2), 2)) / 6);
    bbox = [min(V, [], 1); max(V, [], 1)];

    info = struct('File', stl, 'Content', content, 'Watertight', watertight, 'Shells', shells, 'Volume', vol, ...
                  'BBox', bbox, 'NumTriangles', size(F, 1), 'Units', units);
    if watertight, w = 'watertight (closed surface)'; else, w = 'NOT watertight'; end
    fprintf('STL check: %s | %d triangles | %s | %d separate piece(s) | volume %.0f %s^3 | size %.1f x %.1f x %.1f %s\n', ...
        stl, size(F, 1), w, shells, vol, units, diff(bbox(:, 1)), diff(bbox(:, 2)), diff(bbox(:, 3)), units);
    if ~watertight
        warning('idt_stl_check:NotWatertight', 'The STL is not a closed surface; a slicer may complain.');
    end
    if preview, info.Figure = show(T, info, name); end
end

function fig = show(T, info, name)
    F = T.ConnectivityList;  V = T.Points;
    fig = figure('Name', 'Manufacturable shape (STL)', 'Color', 'w', 'Position', [80 80 1100 520]);
    tiledlayout(1, 2, 'TileSpacing', 'compact');
    fe = featureEdges(T, 25 * pi / 180);                 % crisp outline on sharp edges
    for k = 1:2
        nexttile; hold on;
        patch('Faces', F, 'Vertices', V, 'FaceColor', [0.30 0.55 0.85], 'EdgeColor', 'none', ...
              'FaceLighting', 'flat', 'AmbientStrength', 0.45, 'SpecularStrength', 0.1);
        if ~isempty(fe)
            for q = 1:size(fe, 1)
                plot3(V(fe(q, :), 1), V(fe(q, :), 2), V(fe(q, :), 3), 'k-', 'LineWidth', 0.4);
            end
        end
        axis equal; grid on; camlight headlight; camlight(-30, 30);
        xlabel(['x (' info.Units ')']); ylabel(['y (' info.Units ')']); zlabel(['z (' info.Units ')']);
        if k == 1
            view(35, 28);
            title(sprintf('%s: %d triangles, %.0f %s^3', name, info.NumTriangles, info.Volume, info.Units), 'Interpreter', 'none');
        else
            view(0, 90);
            if info.Watertight, w = 'watertight'; else, w = 'NOT watertight'; end
            title(sprintf('top view: %s, %d piece(s)', w, info.Shells));
        end
    end
end
