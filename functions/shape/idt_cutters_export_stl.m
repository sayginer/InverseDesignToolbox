function info = idt_cutters_export_stl(geom2, file, opt)
% IDT_CUTTERS_EXPORT_STL  Save the exact cut geometry (all parts fused, cutters subtracted) as an STL file and preview it.
%
%   info = idt_cutters_export_stl(geom2, 'results/my_shape')
%   info = idt_cutters_export_stl(geom2, file, opt)
%
%   geom2 : from idt_cutters_geometry(model, cut)
%   file  : output name (with or without .stl). A name without a folder goes to the results/ folder.
%   opt   : struct with  Units ('mm' default or 'm'),  Preview (true default)
%
% The file is read back and checked (idt_stl_check): closed surface, number of solid pieces, volume, size. Because the cutters
% are real CAD cuts, round holes are smooth and flat faces are single large triangles; no brick staircase.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 3, opt = struct(); end
    opt = idt_fill_defaults(opt, struct('Units', 'mm', 'Preview', true));
    [folder, name] = fileparts(char(file));
    if isempty(folder), folder = fullfile(idt_root(), 'results'); end
    if ~isfolder(folder), mkdir(folder); end
    stl = fullfile(folder, [name '.stl']);

    T = triangulation(geom2.Assembly);
    F = T.ConnectivityList;  V = T.Points * (1e3 * strcmpi(opt.Units, 'mm') + 1 * strcmpi(opt.Units, 'm'));
    a = V(F(:, 1), :);  b = V(F(:, 2), :);  c = V(F(:, 3), :);
    if sum(dot(a, cross(b, c, 2), 2)) < 0, F = F(:, [1 3 2]); end          % triangles point outward
    stlwrite(triangulation(F, V), stl);
    info = idt_stl_check(stl, opt.Units, opt.Preview, 'cad');
end
