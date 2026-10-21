function [peakT, info] = idt_isolation_metric(res, I)
% IDT_ISOLATION_METRIC  Largest transmissibility inside the isolation band.
%
%   [peakT, info] = idt_isolation_metric(res, I)
%
%   res : result of idt_analyze / solve_frf computed WITH transmissibility (res.TAmp)
%   I   : isolation settings from idt_isolation_options (Band, Output, Pairs)
%
%   peakT : the largest |T| over the band, over the selected output points and over the selected [response base] pairs
%           (NaN if the result has no transmissibility or the design is not valid)
%   info  : .Table  one row per output and pair: Output, Response, Base, PeakT, PeakFreq [Hz]
%           .Worst  the row with the largest peak;  .Band
%
% T < 1 means the vibration is reduced. A design "blocks" the band when peakT is below 1; below 0.1 is 20 dB of isolation.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    peakT = NaN;
    info = struct('Table', table(), 'Worst', [], 'Band', I.Band);
    if ~isfield(res, 'TAmp') || ~res.Valid, return; end
    f = res.Freq(:);
    inBand = f >= I.Band(1) & f <= I.Band(2);
    n = numel(I.Output) * size(I.Pairs, 1);
    out = zeros(n, 1); rsp = out; bse = out; pk = out; fp = out;
    q = 0;
    for o = I.Output(:)'
        for k = 1:size(I.Pairs, 1)
            q = q + 1;
            a = squeeze(res.TAmp(o, I.Pairs(k, 1), I.Pairs(k, 2), inBand));
            [m, i] = max(a);
            fb = f(inBand);
            out(q) = o; rsp(q) = I.Pairs(k, 1); bse(q) = I.Pairs(k, 2); pk(q) = m; fp(q) = fb(i);
        end
    end
    info.Table = table(out, rsp, bse, pk, fp, 'VariableNames', {'Output', 'Response', 'Base', 'PeakT', 'PeakFreq'});
    [peakT, iw] = max(pk);
    info.Worst = info.Table(iw, :);
end
