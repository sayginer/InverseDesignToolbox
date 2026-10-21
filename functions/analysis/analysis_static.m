function [res, met] = analysis_static(model, X)
% ANALYSIS_STATIC  Linear static deflection and stress of one design under a constant load.
%
%   [res, met] = analysis_static(model, X)
%
% Physics (solved by core/solve_static.m):
%   K u = F      F = P.BC.LoadAmplitude [N] along P.BC.LoadDirection, spread over the load nodes
%   stress       isotropic linear elasticity, evaluated at the element centroids, von Mises
%
% res (raw, from solve_static)
%   .Valid, .U [Nn x 3], .UMag, .VonMises [Ne x 1] (Pa), .Stress, .OutU, .Compliance, .Reaction,
%   .Mass, .DroppedElems, .Active
%
% met (reduced numbers)
%   .Valid         false if load / output points are cut off from every support
%   .MaxDisp       largest displacement magnitude anywhere (m)
%   .OutDefl       [nOut x 3] displacement at the output points (m)
%   .MaxVonMises   largest element von Mises stress (Pa)  (a stress concentration at a support
%                  or load node grows with mesh refinement: read it as an indicator)
%   .Compliance    F'u (J), the quantity SIMP topology optimization minimizes
%   .Stiffness     LoadAmplitude / (displacement of output 1 along the load direction) (N/m)
%   .Mass          total mass (kg)
%   .VolFrac       fraction of design bricks present (NaN without a design domain)
%   .Dropped       mesh elements removed because they float free of the supports
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    nOut = numel(model.OutNodes);
    met = struct('Valid', false, 'MaxDisp', NaN, 'OutDefl', nan(nOut, 3), 'MaxVonMises', NaN, ...
                 'Compliance', NaN, 'Stiffness', NaN, 'Mass', NaN, 'VolFrac', NaN, 'Dropped', NaN);
    res = solve_static(model, X);
    if ~res.Valid, return; end

    met.Valid = true;
    met.MaxDisp = max(res.UMag);
    met.OutDefl = res.OutU;
    met.MaxVonMises = max(res.VonMises, [], 'omitnan');
    met.Compliance = res.Compliance;
    d = model.BC.LoadDirection(:)' / norm(model.BC.LoadDirection);
    along = res.OutU(1, :) * d';
    if abs(along) > 0, met.Stiffness = model.BC.LoadAmplitude / abs(along); end
    met.Mass = res.Mass;
    if model.NumVars > 0, met.VolFrac = mean(logical(X)); end
    met.Dropped = res.DroppedElems;
end
