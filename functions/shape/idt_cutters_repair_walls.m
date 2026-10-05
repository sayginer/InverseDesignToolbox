function [cut, nSteps] = idt_cutters_repair_walls(S, cut)
% IDT_CUTTERS_REPAIR_WALLS  Make a cutter list satisfy the minimum wall by shrinking the cutters.
%
%   [cut, nSteps] = idt_cutters_repair_walls(S, cut)
%
% While idt_cutters_wall finds a wall thinner than S.C.MinWall, every cutter shrinks by 3 % (at most 40 times). A cutter that
% gets smaller than its minimum size is dropped. A design that already satisfies the rule is returned unchanged (nSteps = 0).
% The change is small when the violation is small, so f1 moves little; analyse the repaired list again.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    C = S.C;  nSteps = 0;
    while nSteps < 40 && ~isempty(cut) && ~idt_cutters_wall(S, cut)
        nSteps = nSteps + 1;
        for k = 1:numel(cut)
            cut(k).A = 0.97 * cut(k).A;
            if strcmp(cut(k).Type, 'hole'), cut(k).B = cut(k).A; else, cut(k).B = 0.97 * cut(k).B; end
        end
        small = false(1, numel(cut));
        for k = 1:numel(cut)
            if strcmp(cut(k).Type, 'hole'), small(k) = cut(k).A < C.HoleRadius(1);
            else, small(k) = cut(k).A < C.RectSize(1) || cut(k).B < C.RectSize(1); end
        end
        cut = cut(~small);
    end
end
