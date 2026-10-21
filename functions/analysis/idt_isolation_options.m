function I = idt_isolation_options(I, model)
% IDT_ISOLATION_OPTIONS  Defaults and checks for the vibration-isolation goal (the band that must be blocked).
%
%   I = idt_isolation_options(I, model)       I may be [] or hold only the fields you want to change.
%
% The isolation goal is: base excitation (the clamped faces move as a rigid body) must not reach the protected output
% points. The measure is the TRANSMISSIBILITY T = |absolute response of an output point / base motion| (see
% core/transmissibility.m). T < 1 means the vibration is reduced, T > 1 means it is amplified. The optimizers minimize the
% LARGEST T inside a frequency band, so a design with peak T = 0.2 over the band blocks at least 80 % of the motion there.
%
%  Band      [] -> [100, FreqEnd]   [f_low f_high] Hz that must be blocked. The sweep (P.Analysis.FreqStart/FreqEnd) must
%                                   contain it; the optimizer runs make sure that the transmissibility is computed.
%  Output    1                      output point(s) that must be protected: a number, a list, or 'all' (worst of all)
%  Pairs     [3 3]                  [response base] direction pairs, 1 = x, 2 = y, 3 = z. [3 3] = vertical motion of the base
%                                   to vertical motion of the output. Several rows: the worst of them counts, e.g.
%                                   [3 3; 1 1; 2 2] blocks vertical and both lateral directions.
%  TargetT   []                     optional: stop as soon as the peak T in the band is below this (for example 0.3). Ignored when a
%                                   passband (Pass) is set: the cost then also contains the passband, so the search runs to its limits
%  Pass      []                     optional FLAT PASSBAND [f_low f_high] Hz below the stop band, for example [2 60]: there the response
%                                   should follow the base (T = 1, no resonance peak). The largest deviation 20*log10(T) in the
%                                   passband is limited to PassTol; frequencies between Pass and Band are left free (transition).
%  PassTol   3                      allowed deviation in the passband [dB] (3 dB = T between 0.71 and 1.41)
%  PassWeight 1                     cost of 1 dB passband violation relative to 1 dB of stop-band peak (see idt_isolation_cost)
%
% Why a band and not a single frequency: a flexible structure has several resonances; any resonance inside the band puts a peak
% above 1 there. The peak over the band sees all of them.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    D = struct('Band', [], 'Output', 1, 'Pairs', [3 3], 'TargetT', [], 'Pass', [], 'PassTol', 3, 'PassWeight', 1);
    if nargin < 1 || isempty(I), I = struct(); end
    I = idt_fill_defaults(I, D);
    A = model.Params.Analysis;
    if isempty(I.Band), I.Band = [100, A.FreqEnd]; end
    if ischar(I.Output) || isstring(I.Output)
        assert(strcmpi(I.Output, 'all'), 'idt_isolation_options:Output', 'Output must be numbers or ''all''.');
        I.Output = 1:numel(model.OutNodes);
    end
    assert(numel(I.Band) == 2 && I.Band(1) < I.Band(2), 'idt_isolation_options:Band', 'Band must be [f_low f_high] in Hz.');
    assert(I.Band(1) >= A.FreqStart && I.Band(2) <= A.FreqEnd, 'idt_isolation_options:Sweep', ...
        'Band %g-%g Hz must lie inside the sweep %g-%g Hz (P.Analysis.FreqStart / FreqEnd).', I.Band, A.FreqStart, A.FreqEnd);
    assert(all(I.Output >= 1 & I.Output <= numel(model.OutNodes)), 'idt_isolation_options:Output', ...
        'Output must be between 1 and %d (number of output points).', numel(model.OutNodes));
    assert(size(I.Pairs, 2) == 2 && all(I.Pairs(:) >= 1 & I.Pairs(:) <= 3), 'idt_isolation_options:Pairs', ...
        'Pairs must be rows [response base] with entries 1, 2 or 3.');
    assert(isempty(I.TargetT) || I.TargetT > 0, 'TargetT must be positive.');
    if ~isempty(I.Pass)
        assert(numel(I.Pass) == 2 && I.Pass(1) < I.Pass(2) && I.Pass(1) >= A.FreqStart && I.Pass(2) <= I.Band(1), 'idt_isolation_options:Pass', ...
            'Pass must be [f_low f_high] inside the sweep and below the stop band (Pass(2) <= Band(1) = %g Hz).', I.Band(1));
        assert(I.PassTol >= 0 && I.PassWeight >= 0, 'PassTol and PassWeight must be >= 0.');
    end
end
