function [cut, dropped] = idt_cutters_filter(S, cut)
% IDT_CUTTERS_FILTER  Remove the cutters that touch the places that must stay solid.
%
%   [cut, dropped] = idt_cutters_filter(S, cut)
%
% A cutter that comes within S.C.Margin of a support, the load point or an output point is dropped (those places always
% stay solid in the analysis, so the real part must keep them too). `dropped` is a logical row, one entry per input
% cutter. idt_cutters_from_vector applies this to optimizer designs; call it yourself on a hand-made list.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    dropped = false(1, numel(cut));
    if ~isempty(S.LockCenters)
        for k = 1:numel(cut)
            dropped(k) = any(idt_cutters_inside(cut(k), S.LockCenters, S.C.Margin));
        end
    end
    cut = cut(~dropped);
end
