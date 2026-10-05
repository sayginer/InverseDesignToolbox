function [cut, nOff] = idt_cutters_from_vector(S, p)
% IDT_CUTTERS_FROM_VECTOR  Turn the optimizer's number vector into a list of cutters.
%
%   [cut, nOff] = idt_cutters_from_vector(S, p)       S: from idt_shape_setup       p: 1 x S.NumParams
%
% p is  [hole 1: x y r | ... | rect 1: x y w h angle(deg) | ...]  (S.Names lists them). A cutter is switched OFF, and
% left out of the list, when
%   * it is smaller than the minimum size (radius < rmin, or width or height < smin), or
%   * it comes within S.C.Margin of a support, the load point or an output point (those places stay solid).
% Walls thinner than S.C.MinWall are NOT repaired here: the optimizer penalizes them (idt_cutters_wall) and the final design is
% repaired once by idt_cutters_repair_walls.
% nOff is the number of switched-off cutters. The result is exactly what the analysis and the exact CAD cut use.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = p(:)';
    assert(numel(p) == S.NumParams, 'idt_cutters_from_vector:Size', 'p must have %d numbers.', S.NumParams);
    C = S.C;
    cut = idt_cutter([]);
    i = 0;
    for k = 1:S.NumHoles
        v = p(i + (1:3));  i = i + 3;
        if v(3) >= C.HoleRadius(1), cut(end + 1) = idt_cutter('hole', v(1), v(2), v(3)); end %#ok<AGROW>
    end
    for k = 1:S.NumRects
        v = p(i + (1:5));  i = i + 5;
        if ~C.AllowRotation, v(5) = 0; end
        if v(3) >= C.RectSize(1) && v(4) >= C.RectSize(1)
            cut(end + 1) = idt_cutter('rect', v(1), v(2), v(3), v(4), v(5)); %#ok<AGROW>
        end
    end
    cut  = idt_cutters_filter(S, cut);
    nOff = S.NumHoles + S.NumRects - numel(cut);
end

