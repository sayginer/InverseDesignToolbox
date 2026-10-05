function H = simp_options(H)
% SIMP_OPTIONS  Defaults and validation of the SIMP topology-optimization settings.
%
%   H = simp_options(H)          H may be [] or hold only the fields you want to change.
%
% GOAL (what is optimized)
%  Objective    'TargetF1'   'TargetF1'  : make the first natural frequency equal TargetF1
%                                          minimize J = ((f1 - TargetF1) / TargetF1)^2
%                            'MaximizeF1': make f1 as high as possible for the material budget
%                                          (stiff / light structure); needs VolMax
%  TargetF1     []           target for f1 [Hz] (required for 'TargetF1')
%  VolMax       []           largest allowed volume fraction of the design domain, 0..1
%                            (required for 'MaximizeF1'; optional upper bound for 'TargetF1')
%
% DESIGN FIELD
%  FilterRadius 'auto'       density filter radius [m], measured between brick centers, or 'auto'. Features thinner
%                            than about this cannot form and isolated bricks vanish (no islands, no checkerboard).
%                            It must match the printable minimum width: 'auto' = 1.3 x Clean.MinWidth x brick edge
%                            (8 mm on the example). A smaller radius lets SIMP build thin features that the clean-up
%                            then removes, which can destroy the result (maximize f1: 6.5 mm lost almost everything).
%                            Without the clean-up ('Clean = []') 'auto' = 1.5 brick edges.
%  VolFracInit  0.30         starting density of every brick ('TargetF1'; 'MaximizeF1' starts at VolMax)
%  RhoFloor     0.01         smallest density a brick may take
%
% MATERIAL INTERPOLATION (SIMP)
%  PenalStiff   3            penalization power p:  E(rho) = E0 * (RhoMin + (1-RhoMin) * rho^p)
%  RhoMin       1e-6         stiffness of "void". Must be tiny: a larger floor makes void a soft spring that
%                            fakes a low natural frequency without any real structure.
%  PenalMass    1            mass interpolation power q:  m(rho) = m0 * rho^q
%
% PROJECTION (turns grey into black / white)
%  BetaStart    1            Heaviside sharpness in the first stage (1 = almost linear)
%  BetaMax      64           sharpness in the last stage (the higher, the closer the field is to 0/1 and the
%                            smaller the gap between the continuous design and the solid bricks).
%                            BetaMax = 1 switches the projection off (you will see grey "fake material").
%  Eta          0.5          projection threshold: filtered density above Eta -> solid
%
% OPTIMIZER (fmincon, Optimization Toolbox)
%  Algorithm    'sqp'        'sqp' | 'interior-point' | 'active-set'. 'sqp' is robust but builds a dense
%                            Hessian: fine up to about 1000 bricks, far too slow beyond (2300 bricks did not
%                            finish in 20 min). For more bricks use bigger bricks (lower P.Design.Density).
%  StageIter    10           fmincon iterations per beta stage (beta doubles between stages)
%  MoveLimit    0.3          a density may change at most this much within one stage (trust region;
%                            stops the optimizer from jumping to void in one step). [] = no limit.
%  FreqTol      0.35         'TargetF1': stop the last stage when |f1 - TargetF1| < FreqTol [Hz]
%  EigTol       1e-3         eigenvalue solver tolerance
%
% POST-PROCESSING
%  Thresholds   [.1 ... .9]  cutoffs tried when turning the final densities into solid bricks
%  Clean        struct()     printability clean-up applied to every candidate layout (idt_clean_bricks): fills
%                            one-brick gaps, removes features thinner than MinWidth bricks, removes checkerboards
%                            and islands (face connectivity), keeps only groups joining supports and load.
%                            Fields: MinWidth (2), CloseGaps (2), Overhang (false), KeepOnly ('loadpath').
%                            Clean = [] switches the clean-up off.
%  Polish       struct()     after cleaning, a local search on the REAL analysis adds / removes boundary bricks to
%                            close the gap that making the layout printable opens (idt_polish_bricks).
%                            Fields: MaxSteps (12), Tol (0.5 Hz), UseParallel (true). Polish = [] switches it off.
%
% OUTPUT
%  CheckGradients false      compare the adjoint gradient with finite differences before the first stage
%                            (checkGradients, Optimization Toolbox; one analysis per brick, slow; for testing)
%  LivePlot     false        draw the convergence figure while running
%  Verbose      true         print one line per function evaluation
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    D = struct('Objective', 'TargetF1', 'TargetF1', [], 'VolMax', [], ...
               'FilterRadius', 'auto', 'VolFracInit', 0.30, 'RhoFloor', 0.01, ...
               'PenalStiff', 3, 'RhoMin', 1e-6, 'PenalMass', 1, ...
               'BetaStart', 1, 'BetaMax', 64, 'Eta', 0.5, ...
               'Algorithm', 'sqp', 'StageIter', 10, 'MoveLimit', 0.3, 'FreqTol', 0.35, 'EigTol', 1e-3, ...
               'Thresholds', [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9], 'Clean', struct(), 'Polish', struct(), ...
               'CheckGradients', false, 'LivePlot', false, 'Verbose', true);
    if nargin < 1 || isempty(H), H = struct(); end
    H = idt_fill_defaults(H, D);

    assert(any(strcmp(H.Objective, {'TargetF1', 'MaximizeF1'})), ...
        'simp_options:Objective', 'Objective must be ''TargetF1'' or ''MaximizeF1''.');
    if strcmp(H.Objective, 'TargetF1')
        assert(~isempty(H.TargetF1), 'simp_options:TargetF1', 'Objective ''TargetF1'' needs H.TargetF1 [Hz].');
    else
        assert(~isempty(H.VolMax), 'simp_options:VolMax', 'Objective ''MaximizeF1'' needs H.VolMax (0..1).');
    end
    assert(isempty(H.VolMax) || (H.VolMax > 0 && H.VolMax <= 1), 'VolMax must be in (0, 1].');
    assert(H.PenalStiff >= 1 && H.PenalMass >= 1, 'PenalStiff and PenalMass must be >= 1.');
    assert(H.RhoFloor > 0 && H.RhoFloor < 1, 'RhoFloor must be in (0, 1).');
    assert(H.StageIter >= 1, 'StageIter must be >= 1.');
    assert((isnumeric(H.FilterRadius) && H.FilterRadius > 0) || strcmpi(char(H.FilterRadius), 'auto'), ...
        'FilterRadius must be a positive number [m] or ''auto''.');
    assert(H.BetaStart >= 0.5 && H.BetaMax >= H.BetaStart, 'Need 0.5 <= BetaStart <= BetaMax.');
    assert(H.Eta > 0 && H.Eta < 1, 'Eta must be in (0, 1).');
end
