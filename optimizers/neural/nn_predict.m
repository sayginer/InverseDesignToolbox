function f1 = nn_predict(sur, X)
% NN_PREDICT  Predicted first natural frequency [Hz] of brick layouts.
%
%   f1 = nn_predict(sur, X)         X: n x nVar (logical or 0/1), one layout per row;  f1: n x 1
%
% Takes about a millisecond per layout, against about a second for the real FEA. The prediction is only as
% good as the training data: far from the layouts it was trained on it can be wrong, which is why
% nn_optimize verifies every candidate with the real analysis. Layouts that are not usable (cut off, or hinge-like)
% should come out near 1 Hz.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    y = predict(sur.net, nn_encode(sur, X));
    f1 = exp(double(y(:)) * sur.sigma + sur.mu);
end
