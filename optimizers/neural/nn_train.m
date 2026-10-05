function sur = nn_train(model, D, H)
% NN_TRAIN  Train the surrogate network: brick layout -> first natural frequency f1.
%
%   sur = nn_train(model, D, H)        D: dataset from nn_make_dataset      H: from nn_options
%
% Target: log(f1), standardized. Trained on the USABLE layouts of the random start (hinge-like layouts there have
% f1 close to 0 for reasons that depend on mesh details; as labels they are noise and the network collapses to a
% constant), plus, from round 2 on, the layouts verified by the search: a verified hinge counts as f1 = 1 Hz
% (these are local lessons "do not go there", repeated by the search, so they are consistent labels).
%
% Networks (Deep Learning Toolbox, trainnet, Adam, early stopping on the held-back data)
%   H.Network = 'cnn'  the brick grid as a 3-D image (2 channels: brick present / brick exists) through two
%                      3-D convolutions and fully connected layers. Knows that neighbouring bricks matter, so it
%                      needs much less data than a plain network. (default)
%   H.Network = 'mlp'  fully connected layers on the brick vector (H.Hidden).
% A fraction H.ValFraction of the data is held back and is NOT used for fitting; its errors tell you how far
% to trust the surrogate.
%
% OUTPUT sur: .net (dlnetwork), .mu, .sigma, .kind, .gridN, .varBricks, .nVar,
%   .val (held-back: idx, f1True, f1Pred), .metrics (R2 of log f1, MAPE of f1, counts, time)
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    use = find(D.fit);
    assert(numel(use) >= 40, 'nn_train:FewData', ...
        'Only %d usable layouts. Increase H.NumSamples or use a coarser brick design.', numel(use));
    rs = RandStream('twister', 'Seed', H.Seed);
    use = use(randperm(rs, numel(use)));
    nVal = max(10, round(H.ValFraction * numel(use)));
    iVal = use(1:nVal);  iTr = use(nVal + 1:end);
    if isfield(D, 'w'), iTr = repelem(iTr(:), round(D.w(iTr(:)))); end   % weighted layouts are repeated (training only)

    y = log(D.f1fit);
    mu = mean(y(iTr));  sg = std(y(iTr)) + eps;
    yn = single((y - mu) / sg);

    sur = struct('net', [], 'mu', mu, 'sigma', sg, 'kind', H.Network, 'gridN', model.Bricks.Grid.N, ...
                 'varBricks', model.VarBricks, 'nVar', model.NumVars);
    Xall = nn_encode(sur, D.X);
    switch H.Network
        case 'cnn'
            layers = [image3dInputLayer([sur.gridN 2], 'Normalization', 'none')
                      convolution3dLayer(3, 16, 'Padding', 'same'); reluLayer
                      convolution3dLayer(3, 32, 'Padding', 'same'); reluLayer
                      fullyConnectedLayer(64); reluLayer; dropoutLayer(0.2)
                      fullyConnectedLayer(1)];
            sel = @(A, ix) A(:, :, :, :, ix);
        case 'mlp'
            layers = featureInputLayer(sur.nVar, 'Normalization', 'none');
            for h = H.Hidden(:)'
                layers = [layers; fullyConnectedLayer(h); reluLayer; dropoutLayer(0.2)]; %#ok<AGROW>
            end
            layers = [layers; fullyConnectedLayer(1)];
            sel = @(A, ix) A(ix, :);
        otherwise
            error('nn_train:Network', 'H.Network must be ''cnn'' or ''mlp''.');
    end
    perEpoch = max(1, floor(numel(iTr) / H.MiniBatch));
    opts = trainingOptions('adam', 'MaxEpochs', H.MaxEpochs, 'MiniBatchSize', H.MiniBatch, ...
        'InitialLearnRate', H.LearnRate, 'Shuffle', 'every-epoch', 'L2Regularization', 1e-4, ...
        'ValidationData', {sel(Xall, iVal), yn(iVal)}, 'ValidationFrequency', perEpoch, ...
        'ValidationPatience', 15, 'OutputNetwork', 'best-validation', 'Plots', 'none', 'Verbose', false);
    t0 = tic;
    sur.net = trainnet(sel(Xall, iTr), yn(iTr), layers, 'mse', opts);

    %% held-back quality
    fP = nn_predict(sur, D.X(iVal, :));
    real = D.usable(iVal);                              % quality is measured on real f1 values only (not on the 1 Hz hinge labels)
    yT = log(D.f1fit(iVal(real)));  yP = log(fP(real));
    r2 = 1 - sum((yT - yP).^2) / sum((yT - mean(yT)).^2);
    mape = mean(abs(fP(real) - D.f1fit(iVal(real))) ./ D.f1fit(iVal(real))) * 100;
    sur.val = struct('idx', iVal(real), 'f1True', D.f1fit(iVal(real)), 'f1Pred', fP(real));
    sur.metrics = struct('R2', r2, 'MAPE', mape, 'nTrain', numel(iTr), 'nVal', numel(iVal), 'time', toc(t0));
    if H.Verbose
        fprintf('NN surrogate (%s): held-back R^2 (log f1) = %.3f, mean f1 error %.1f %%  (%d train / %d held back, %.0f s)\n', ...
            H.Network, r2, mape, numel(iTr), numel(iVal), sur.metrics.time);
    end
end
