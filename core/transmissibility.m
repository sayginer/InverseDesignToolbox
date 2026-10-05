function tr = transmissibility(model, X, varargin)
% TRANSMISSIBILITY  Base-excitation transmissibility of a brick layout, next to the force FRF.
%
%   tr = transmissibility(model, X)                 all three base directions, plot included
%   tr = transmissibility(model, X, 'Base', 'z')    base motion along z only ('x','y','z', 'all' or [1 3])
%   tr = transmissibility(model, X, 'Plot', false)
%
% DEFINITION. The clamped (fixed) faces form the base. They move together as a rigid body with a
% harmonic displacement u_b along x, y or z (the structure is NOT loaded by the force F0 here).
% The transmissibility is the ABSOLUTE response of an output point divided by the base motion:
%
%       T(w) = u_out,abs(w) / u_base(w)
%
% Displacement, velocity and acceleration ratios are identical. T = 1 at low frequency (the
% structure moves with the base), T peaks at resonance, and T < 1 above sqrt(2) times the resonance
% (isolation). It is dimensionless and independent of the force amplitude. Modal damping Zeta from
% the model is used, as in the FRF.
%
% OUTPUT tr
%   .Valid             false if the layout is disconnected (see solve_frf)
%   .Freq              sweep (Hz);  .NaturalFreqs (Hz)
%   .T                 complex, [nOut x 3 (response x,y,z) x 3 (base direction x,y,z) x nFreq]
%   .Amp, .dB          abs(T) and 20*log10(abs(T))
%   .Peak              table: output point, base direction, response direction, peak |T|, frequency (Hz)
%   .Result            the full solve_frf result (also contains the force FRF res.U / res.Amp)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'Base', 'all');
    addParameter(p, 'Plot', true);
    parse(p, varargin{:});
    if nargin < 2, X = []; end

    res = solve_frf(model, X, 'Transmissibility', true);
    tr = struct('Valid', res.Valid, 'Freq', res.Freq, 'NaturalFreqs', res.NaturalFreqs, ...
                'T', [], 'Amp', [], 'dB', [], 'Peak', table(), 'Result', res);
    if ~res.Valid
        warning('transmissibility:Invalid', 'Layout is not valid (load/output cut off from the supports).');
        return;
    end
    tr.T = res.T; tr.Amp = abs(res.T); tr.dB = 20 * log10(tr.Amp);

    dirs = parseBase(p.Results.Base);
    lbl = 'xyz';
    rows = {};
    for o = 1:size(tr.Amp, 1)
        for b = dirs
            for c = 1:3
                [pk, ix] = max(squeeze(tr.Amp(o, c, b, :)));
                rows(end+1, :) = {o, lbl(b), lbl(c), pk, res.Freq(ix)}; %#ok<AGROW>
            end
        end
    end
    tr.Peak = cell2table(rows, 'VariableNames', {'Output', 'BaseDir', 'ResponseDir', 'PeakT', 'FreqHz'});

    fprintf('--- Transmissibility (base excitation) ---\n');
    for o = 1:size(tr.Amp, 1)
        for b = dirs
            [pk, ix] = max(squeeze(tr.Amp(o, b, b, :)));
            fprintf('  Output %d, base %s -> response %s: peak T = %.2f at %.1f Hz (T at %.0f Hz = %.2f)\n', ...
                o, lbl(b), lbl(b), pk, res.Freq(ix), res.Freq(1), tr.Amp(o, b, b, 1));
        end
    end

    if p.Results.Plot, plot_transmissibility(model, tr, 'Base', dirs); end
end

function dirs = parseBase(b)
    if ischar(b) || isstring(b)
        b = char(b);
        if strcmpi(b, 'all'), dirs = 1:3; else, dirs = find(ismember('xyz', lower(b))); end
    else
        dirs = b(:)';
    end
    assert(~isempty(dirs), 'Base must be ''x'', ''y'', ''z'', ''all'' or a vector of 1..3.');
end
