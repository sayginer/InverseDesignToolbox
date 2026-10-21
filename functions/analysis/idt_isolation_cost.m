function [J, info] = idt_isolation_cost(res, I)
% IDT_ISOLATION_COST  Cost of one design for the isolator goal (lower is better).
%
%   [J, info] = idt_isolation_cost(res, I)
%
%   res : analysis result with transmissibility;  I : settings from idt_isolation_options
%
%   Stop band only (I.Pass empty):   J = log10(peakT)            peakT = largest T in I.Band
%   With a flat passband (I.Pass):   J = ( 20*log10(peakT) + I.PassWeight * max(0, dev - I.PassTol) ) / 20
%                                    dev  = largest |20*log10(T)| over I.Pass (how far the passband is from flat, in dB)
% So J = -1 means 20 dB of isolation in the whole stop band and a passband inside the tolerance. A passband violation of 1 dB costs
% as much as 1 dB less isolation (PassWeight = 1). J is NaN when the design cannot be analysed or has no transmissibility.
%
%   info : .PeakT (stop band), .PassDev (dB, NaN without passband), .Table, .Worst (see idt_isolation_metric), .J
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    [peakT, info] = idt_isolation_metric(res, I);
    info.PeakT = peakT;  info.PassDev = NaN;  info.J = NaN;
    J = NaN;
    if ~isfinite(peakT), return; end
    J = log10(peakT);
    if ~isempty(I.Pass)
        f = res.Freq(:);  inPass = f >= I.Pass(1) & f <= I.Pass(2);
        dev = 0;
        for o = I.Output(:)'
            for k = 1:size(I.Pairs, 1)
                a = squeeze(res.TAmp(o, I.Pairs(k, 1), I.Pairs(k, 2), inPass));
                dev = max(dev, max(abs(20 * log10(a))));
            end
        end
        info.PassDev = dev;
        J = (20 * log10(peakT) + I.PassWeight * max(0, dev - I.PassTol)) / 20;
    end
    info.J = J;
end
