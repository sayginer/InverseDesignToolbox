%% EXERCISE_SurrogateData  -  how much data does a neural network need, and when does it pay off?
%
%  A surrogate is a neural network that predicts the result of an analysis (here the relative stiffness of a beam layout) in
%  milliseconds, instead of solving the finite-element problem. To learn, it needs examples, and every example costs one real
%  analysis. This exercise trains the same network on 3 different amounts of data and tests it on layouts it has never seen.
%
%  Questions for you (write the answers down BEFORE you run each step):
%     1. How will the error change when the training data triples? Will it ever reach zero?
%     2. How many analyses does the network need to save before it was worth building?
%     3. An optimizer asks the network for thousands of designs it has never seen. Why is each candidate still checked with the real analysis?
%
%  Needs results/CantileverBeam.mat (run SIM_StaticLoad.m first) and the Deep Learning Toolbox. Takes about 2-5 minutes.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

%% 1. SETTINGS
nTrain = [100 300 800];  nTest = 150;       % training sizes to compare, and unseen test layouts
Hmax = 3.0e-3;  Order = 'linear';        % coarse linear mesh: one analysis takes a fraction of a second
Seed = 1;

P = idt_load_params('CantileverBeam');
P.Mesh.Hmax = Hmax;  P.Mesh.Order = Order;
model = idt_build_model(P);
[~, m0] = idt_analyze(model);
c0 = m0.Compliance;                      % the full beam: the network predicts  c0 / compliance  ("relative stiffness", 1 = full beam)

%% 2. THE DATA  (the expensive part: every row is a real finite-element analysis)
rs = RandStream('twister', 'Seed', Seed);
N = max(nTrain) + nTest;
X = idt_random_layouts(model, N, [0.3 0.7], 10e-3, rs);
comp = nan(N, 1);
if isempty(gcp('nocreate')), try, parpool('Processes'); catch, end, end      % start the pool first so it is not counted below
fprintf('Analysing %d random layouts...\n', N);
t0 = tic;
parfor i = 1:N
    [~, m] = idt_analyze(model, X(i, :)');
    if m.Valid, comp(i) = m.Compliance; end
end
fprintf('  %.1f s in total (analyses run in parallel if a pool is available)\n', toc(t0));
tSerial = timeit(@() idt_analyze(model, X(1, :)'));       % ONE analysis alone: the cost used below (what a laptop without a pool pays)
fprintf('  one analysis alone takes %.3f s\n', tSerial);
s = c0 ./ comp;                          % relative stiffness (NaN for layouts cut off from the supports)

iTest = (max(nTrain) + 1):N;  iTest = iTest(isfinite(s(iTest)));

%% 3. TRAIN THE SAME NETWORK ON MORE AND MORE DATA, TEST ON LAYOUTS IT HAS NEVER SEEN
Hn = nn_options(struct('Objective', 'MaximizeF1', 'VolMax', 0.5, 'Network', 'cnn', 'Verbose', false, 'Seed', Seed));
mape = nan(size(nTrain));  r2 = mape;  tTrain = mape;
for q = 1:numel(nTrain)
    idx = 1:nTrain(q);  idx = idx(isfinite(s(idx)));
    D = struct('X', logical(X(idx, :)), 'f1fit', s(idx), 'f1', s(idx), 'usable', true(numel(idx), 1), ...
               'fit', true(numel(idx), 1), 'w', ones(numel(idx), 1));
    t1 = tic;
    sur = nn_train(model, D, Hn);
    tTrain(q) = toc(t1);
    pred = nn_predict(sur, logical(X(iTest, :)));
    mape(q) = mean(abs(pred - s(iTest)) ./ s(iTest)) * 100;
    r2(q) = 1 - sum((log(pred) - log(s(iTest))).^2) / sum((log(s(iTest)) - mean(log(s(iTest)))).^2);
    fprintf('  %4d training layouts: error on unseen layouts %5.1f %%, R^2 %.2f (training took %.0f s)\n', numel(idx), mape(q), r2(q), tTrain(q));
end
tPredict = timeit(@() nn_predict(sur, logical(X(iTest, :)))) / numel(iTest);

%% 4. RESULTS
figure('Name', 'Surrogate: error vs data', 'Color', 'w', 'Position', [100 100 1000 420]);
tiledlayout(1, 2, 'TileSpacing', 'compact');
nexttile; hold on; grid on;
yyaxis left;  plot(nTrain, mape, 'o-', 'LineWidth', 1.8, 'MarkerFaceColor', 'auto'); ylabel('error on unseen layouts (%)');
yyaxis right; plot(nTrain, nTrain * tSerial / 60, 's--', 'LineWidth', 1.4); ylabel('time to make the data, one analysis at a time (min)');
set(gca, 'XScale', 'log'); xlabel('number of training layouts'); title('More data: lower error, higher cost');
nexttile; hold on; grid on;
plot(s(iTest), pred, 'b.', 'MarkerSize', 12);
lim = [min([s(iTest); pred]) * 0.9, max([s(iTest); pred]) * 1.1];
plot(lim, lim, 'k--'); xlim(lim); ylim(lim); axis square;
xlabel('relative stiffness from the analysis'); ylabel('predicted by the network');
title(sprintf('Unseen layouts, %d training layouts', nTrain(end)));

fprintf('\n---------------- WHAT TO NOTICE ----------------\n');
fprintf('  one analysis alone      : %.3f s\n', tSerial);
fprintf('  one network prediction  : %.5f s   (%.0f x faster)\n', tPredict, tSerial / tPredict);
fprintf('  data for %d layouts     : %.1f min of analysis (one at a time) + %.0f s of training\n', nTrain(end), nTrain(end) * tSerial / 60, tTrain(end));
fprintf('  break-even              : the network starts to save time after about %.0f predictions that replace analyses\n', ...
        (nTrain(end) * tSerial + tTrain(end)) / max(tSerial - tPredict, eps));
fprintf('  The error does not reach zero, and it is measured on layouts like the training ones (random, smooth).\n');
fprintf('  An optimizer will ask the network about layouts it has NOT seen: that is why every candidate is verified\n');
fprintf('  with the real analysis (nn_optimize / static_nn_optimize).\n');
fprintf('------------------------------------------------\n');

%% 5. KEEP THE DATA  (optional: a CSV file for the Regression Learner app, Python, Excel ...)
% idt_export_dataset(model, 300, 'beam_dataset');
