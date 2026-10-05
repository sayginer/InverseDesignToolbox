function [ok, info] = idt_cutters_wall(S, cut)
% IDT_CUTTERS_WALL  Do the cutters leave walls thinner than S.C.MinWall?
%
%   [ok, info] = idt_cutters_wall(S, cut)
%
% Top view, drawn on a 0.25 mm raster: the solid area is everything that is material in any part, minus the cutters
% (a cutter only removes the design part, other parts stay). A morphological opening with a disk of diameter MinWall
% (Image Processing Toolbox) keeps every wall at least that thick; whatever the opening removes is a too-thin wall, or an
% island too small to print. Thin places that already exist in the uncut part are ignored.
%
%   ok            true when no new thin wall appears (always true when MinWall = 0)
%   info.Area     area of the too-thin places [m^2]
%   info.Fraction that area / area of the design part
%   info.Mask     logical image (rows = y, columns = x; S.Wall.x, S.Wall.y) of the too-thin places, for plotting
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    ok = true;  info = struct('Area', 0, 'Fraction', 0, 'Mask', []);
    W = S.Wall;
    if isempty(W), return; end
    cutMask = reshape(idt_cutters_inside(cut, W.Pts, 0), size(W.Fall)) & W.Fdes;
    solid = W.Fall & ~cutMask;
    thin  = solid & ~imopen(solid, W.SE) & ~W.Thin0;
    % The opening also rounds every convex corner of the solid (e.g. a holder corner that a cutter exposes). That residue is
    % smaller than 1.5 x r^2 pixels (r = opening radius in pixels); a real thin wall is larger, so smaller blobs are ignored.
    r = max(1, floor(S.C.MinWall / 2 / W.dx));
    thin  = bwareaopen(thin, max(6, round(1.5 * r^2)));
    a = nnz(thin) * W.dx^2;
    info = struct('Area', a, 'Fraction', a / (nnz(W.Fdes) * W.dx^2), 'Mask', thin);
    ok = ~any(thin(:));
end
