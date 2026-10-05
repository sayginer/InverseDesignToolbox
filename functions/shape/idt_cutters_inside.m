function in = idt_cutters_inside(cut, xy, margin)
% IDT_CUTTERS_INSIDE  Which points (x, y) lie inside at least one cutter?
%
%   in = idt_cutters_inside(cut, xy)            xy: n x 2 points [m]       in: n x 1 logical
%   in = idt_cutters_inside(cut, xy, margin)    every cutter made larger by margin [m] on all sides
%
% Cutters go through the whole thickness, so only x and y matter. This single function defines what a cutter
% removes: the analysis (idt_cutters_mask) and the lock-out test (idt_cutters_filter) and the wall check (idt_cutters_wall) all use it.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 3, margin = 0; end
    in = false(size(xy, 1), 1);
    for k = 1:numel(cut)
        c = cut(k);
        dx = xy(:, 1) - c.X;  dy = xy(:, 2) - c.Y;
        switch c.Type
            case 'hole'
                in = in | (dx.^2 + dy.^2 <= (c.A + margin)^2);
            case 'rect'
                t = deg2rad(c.AngleDeg);
                u =  cos(t) * dx + sin(t) * dy;               % coordinates in the rectangle's own frame
                v = -sin(t) * dx + cos(t) * dy;
                in = in | (abs(u) <= c.A / 2 + margin & abs(v) <= c.B / 2 + margin);
        end
    end
end
