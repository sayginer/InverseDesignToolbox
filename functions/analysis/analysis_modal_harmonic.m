function [res, met] = analysis_modal_harmonic(model, X)
% ANALYSIS_MODAL_HARMONIC  Eigenfrequencies + harmonic (forced) response of one design.
%
%   [res, met] = analysis_modal_harmonic(model, X)
%
% Physics (solved by core/solve_frf.m, validated against MATLAB's structuralModal):
%   eigenproblem      K phi = omega^2 M phi              -> natural frequencies and mode shapes
%   force FRF         harmonic force at the load point; modal superposition with modal damping
%                     Zeta plus a static correction for the modes that were not kept
%   transmissibility  (optional) the clamped faces move as a rigid base; T = absolute response of
%                     an output point / base motion, for base motion along x, y and z
%
% res (raw, from solve_frf)
%   .Valid, .NaturalFreqs [Hz], .Freq [Hz], .U / .Amp [nOut x 3 x nFreq] (m), .Modes, .Mass,
%   .DroppedElems, .ModalCoverage, and when requested .T / .TAmp [nOut x 3 x 3 x nFreq]
%
% met (reduced numbers)
%   .Valid         false if load / output points are cut off from every support
%   .NaturalFreqs  all kept natural frequencies [Hz];  .f1, .f2 the first two
%   .Mass          total mass including extra mass [kg]
%   .VolFrac       fraction of design bricks present (NaN without a design domain)
%   .Dropped       mesh elements removed because they float free of the supports
%   .FRFPeak       [nOut x 3] peak displacement amplitude of the force FRF (m)
%   .FRFPeakFreq   [nOut x 3] frequency of that peak (Hz)
%   .StaticDefl    [nOut x 3] displacement amplitude at the lowest sweep frequency (m)
%   .TPeak         [nOut x 3 x 3] peak |T| (response dir x base dir), NaN if not computed
%   .TPeakFreq     [nOut x 3 x 3] its frequency (Hz)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    A = model.Params.Analysis;
    res = solve_frf(model, X, 'Transmissibility', A.Transmissibility);

    nOut = numel(model.OutNodes);
    met = struct('Valid', false, 'NaturalFreqs', [], 'f1', NaN, 'f2', NaN, 'Mass', NaN, ...
                 'VolFrac', NaN, 'Dropped', NaN, 'FRFPeak', nan(nOut, 3), 'FRFPeakFreq', nan(nOut, 3), ...
                 'StaticDefl', nan(nOut, 3), 'TPeak', nan(nOut, 3, 3), 'TPeakFreq', nan(nOut, 3, 3));
    if ~res.Valid || isempty(res.NaturalFreqs), return; end

    met.Valid = true;
    met.NaturalFreqs = res.NaturalFreqs(:);
    met.f1 = res.NaturalFreqs(1);
    if numel(res.NaturalFreqs) > 1, met.f2 = res.NaturalFreqs(2); end
    met.Mass = res.Mass;
    if model.NumVars > 0, met.VolFrac = mean(logical(X)); end
    met.Dropped = res.DroppedElems;

    f = res.Freq(:);
    [pk, ip] = max(res.Amp, [], 3);                 % nOut x 3
    met.FRFPeak = pk;  met.FRFPeakFreq = f(ip);
    met.StaticDefl = res.Amp(:, :, 1);

    if isfield(res, 'TAmp')
        [pk, ip] = max(res.TAmp, [], 4);            % nOut x 3 x 3
        met.TPeak = pk;  met.TPeakFreq = f(ip);
    end
end
