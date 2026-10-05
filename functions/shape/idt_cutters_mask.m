function [X, volFrac] = idt_cutters_mask(S, cut)
% IDT_CUTTERS_MASK  Design vector for a cutter list: which removable elements survive.
%
%   [X, volFrac] = idt_cutters_mask(S, cut)
%
%   X        S-model design vector (smodel.NumVars x 1 logical): 1 = element kept, 0 = inside a cutter
%   volFrac  fraction of the design part's volume that is left (1 = no cutter)
%
% Use with the model from idt_shape_setup:   [res, met] = idt_analyze(smodel, X)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    X = ~idt_cutters_inside(cut, S.Centers(:, 1:2), 0);
    volFrac = 1 - sum(S.Vol(~X)) / S.VolTotal;
end
