function volBrick = nn_brick_volumes(model)
% NN_BRICK_VOLUMES  Material volume of every design brick [m^3] (element volumes summed per brick).
%
%   volBrick = nn_brick_volumes(model)        model.NumVars x 1
%
% Used to turn a brick layout into a volume fraction of the design domain: vol = X * volBrick / sum(volBrick).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    ev = model.ElemVar;
    volBrick = accumarray(ev(ev > 0), model.Vol(ev > 0), [model.NumVars, 1]);
end
