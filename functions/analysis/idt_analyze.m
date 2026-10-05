function [res, met] = idt_analyze(model, X)
% IDT_ANALYZE  Run the analysis selected in model.Params.Analysis.Type on ONE design. No figures.
%
%   [res, met] = idt_analyze(model)        all design bricks present (or no design domain)
%   [res, met] = idt_analyze(model, X)     X: model.NumVars x 1 logical, 1 = brick present
%
%   res : full result of the analysis (raw numbers: mode shapes, curves, ...)
%   met : a few scalar / small-array metrics that optimizers and reports use
%
% This is the ONLY place the rest of the toolbox calls the physics. Every analysis type is one
% function  [res, met] = analysis_<type>(model, X)  and one line in the switch below.
% To add a new analysis (static load, thermal, ...) see docs/99_extending.md.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 2 || isempty(X), X = true(model.NumVars, 1); end
    switch model.Params.Analysis.Type
        case 'ModalHarmonic'
            [res, met] = analysis_modal_harmonic(model, X);
        otherwise
            error('idt_analyze:Type', 'Unknown analysis type "%s". Available: ModalHarmonic.', ...
                  model.Params.Analysis.Type);
    end
end
