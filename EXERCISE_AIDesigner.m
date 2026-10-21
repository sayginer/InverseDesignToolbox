%% EXERCISE_AIDesigner  -  can an AI assistant design the beam? You decide by measuring.
%
%  The idea: an AI assistant (any chat assistant or coding agent) PROPOSES a design, the finite-element solver VERIFIES it, and
%  you JUDGE the result. The assistant never sees the solver unless you tell it the numbers, so you play the "engineering loop":
%
%     1. Run section 1: it prints a description of the problem. Copy it into your assistant.
%     2. The assistant answers with a list of bricks to remove. Paste it into section 2.
%     3. Run section 3: the solver scores the design and compares it with a hand design, random layouts and the optimizers.
%     4. Tell the assistant the numbers and ask for an improved design. Repeat 3-5 rounds. Keep a table of your rounds.
%
%  Questions: Did the assistant respect the rules (volume limit, only removable bricks)? Did the score improve from round to
%  round? How does it compare with the optimizers, and with the number of analyses they needed? What did the assistant get
%  wrong, and would you have noticed without the solver?
%
%  Needs results/CantileverBeam.mat (run SIM_StaticLoad.m first). For the comparison with the optimizers, run
%  CASE_SIMP_StaticBeam / CASE_GA_StaticBeam / CASE_NN_StaticBeam first (optional).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

%% 0. THE PROBLEM  (same mesh and settings as the CASE_*_StaticBeam optimizers, so the scores are comparable)
VolMax = 0.5;                               % the design may keep at most 50 % of the removable bricks
P = idt_load_params('CantileverBeam');
P.Mesh.Hmax = 3.0e-3;  P.Mesh.Order = 'linear';
model = idt_build_model(P);
bricks = model.Bricks;
[~, m0] = idt_analyze(model);               % the full beam
g = bricks.Grid;
[bi, bj, bk] = ind2sub(g.N, model.VarBricks);
nVar = model.NumVars;  nKeepMax = floor(VolMax * nVar);

%% 1. THE TEXT FOR YOUR ASSISTANT  (copy everything between the lines into the chat)
L = {};
L{end+1} = 'You are helping me design a lightweight but stiff cantilever beam. I will run your design in a finite-element solver and tell you the result.';
L{end+1} = '';
bb = model.Geom.BBox * 1e3;
L{end+1} = sprintf('GEOMETRY: a plate %.0f x %.0f x %.0f mm (x = length, y = thickness, z = height). An outer frame (steel) cannot be changed.', bb(2)-bb(1), bb(4)-bb(3), bb(6)-bb(5));
L{end+1} = sprintf('Inside it, a web (aluminum) is divided into a grid of %d x %d x %d bricks (index i along x, j through the thickness, k along z). Brick index i = 1 is at the clamped end.', g.N);
L{end+1} = 'LOADS: the left end (i = 1 side) is clamped. A downward force of 500 N acts on the right end.';
L{end+1} = sprintf('REMOVABLE BRICKS: %d bricks (listed below as i j k). Every other brick is fixed.', nVar);
L{end+1} = sprintf('GOAL: remove bricks so that the beam is as STIFF as possible (smallest tip deflection) while keeping at most %d of the %d removable bricks (%.0f %%).', nKeepMax, nVar, 100 * VolMax);
L{end+1} = 'RULES: only remove bricks from the list. The remaining bricks must stay joined FACE TO FACE from the clamped end to the loaded end (bricks that touch only along an edge or at a corner do not count as connected).';
L{end+1} = '';
L{end+1} = 'Layer map of the removable bricks (# = removable brick; columns = i from 1, rows = k from the top layer down to k = 1):';
for k = g.N(3):-1:1
    row = repmat('.', 1, g.N(1));
    row(bi(bk == k)) = '#';
    L{end+1} = sprintf('  k=%d  %s', k, row); %#ok<SAGROW>
end
L{end+1} = '';
L{end+1} = 'ANSWER FORMAT: reply with ONE line of MATLAB code that lists the bricks to REMOVE, like   removeIJK = [i j k; i j k; ...];   and a two-sentence reason.';
L{end+1} = sprintf('(For reference the full beam has a tip deflection of %.1f micrometers; a design that keeps the beam stiff while removing %d bricks is the aim.)', ...
    abs(m0.OutDefl(1, 3)) * 1e6, nVar - nKeepMax);
prompt = strjoin(L, newline);
if ~isfolder(fullfile(idt_root(), 'results')), mkdir(fullfile(idt_root(), 'results')); end
fid = fopen(fullfile(idt_root(), 'results', 'AIDesigner_prompt.txt'), 'w'); fprintf(fid, '%s\n', prompt); fclose(fid);
fprintf('\n----------------- COPY FROM HERE -----------------\n%s\n----------------- TO HERE (also saved in results/AIDesigner_prompt.txt) -----------------\n\n', prompt);

%% 2. PASTE THE ASSISTANT'S ANSWER HERE  (the example below is a simple hand design: replace it)
[I, K] = meshgrid(4:18, 3:4);        removeIJK = [I(:), ones(numel(I), 1), K(:)];                       % a window in the middle of the web
[I, K] = meshgrid(7:15, [2 5]);       removeIJK = [removeIJK; I(:), ones(numel(I), 1), K(:)];            % widen it
[I, K] = meshgrid([2 3 19 20], 3:4); removeIJK = [removeIJK; I(:), ones(numel(I), 1), K(:)];            % thin the ends
[I, K] = meshgrid([2 3 19 20], [2 5]); removeIJK = [removeIJK; I(:), ones(numel(I), 1), K(:)];
roundName = 'my first design';

%% 3. THE SOLVER SCORES THE DESIGN
okRule = true;
removable = [bi bj bk];
unknown = ~ismember(removeIJK, removable, 'rows');
if any(unknown)
    fprintf('[RULE BROKEN] %d listed brick(s) are not removable (ignored): %s\n', nnz(unknown), mat2str(removeIJK(unknown, :)'));
    okRule = false;
end
removeIJK = unique(removeIJK(~unknown, :), 'rows');
M = idt_select_bricks(bricks, 'RemoveIJK', removeIJK);
X = select_bricks(model, 'Matrix', M);
nKeep = nnz(X);
if nKeep > nKeepMax
    fprintf('[RULE BROKEN] the design keeps %d bricks, the limit is %d.\n', nKeep, nKeepMax); okRule = false;
end
[res, met] = idt_analyze(model, X);
if ~met.Valid
    fprintf('[INVALID] the load is cut off from the clamped end, or bricks touch only along an edge or corner (a mechanism). Tell your assistant: the remaining bricks must be joined face to face.\n');
    return;
end

% benchmarks at the same number of bricks: the best of 100 random layouts
rs = RandStream('twister', 'Seed', 1);
R = idt_random_layouts(model, 100, [nKeep / nVar nKeep / nVar], 10e-3, rs);
cRand = nan(100, 1);
for i = 1:100
    [~, mr] = idt_analyze(model, R(i, :)');
    if mr.Valid, cRand(i) = mr.Compliance; end
end
names = {'full beam (all bricks)'; sprintf('YOUR DESIGN: %s', roundName); 'best of 100 random layouts'};
comp = [m0.Compliance; met.Compliance; min(cRand)];
nb = [nVar; nKeep; nKeep];  nAn = [0; 1; 100];
for f = {'SIMPstatic', 'GAstatic', 'NNstatic'}              % results of the optimizers, if they have been run
    fn = fullfile(idt_root(), 'results', [f{1} '_CantileverBeam.mat']);
    if isfile(fn)
        Sx = load(fn, 'out');
        names{end+1, 1} = [f{1}(1:end-6) ' optimizer']; %#ok<SAGROW>
        comp(end+1, 1) = Sx.out.met.Compliance;  nb(end+1, 1) = nnz(Sx.out.X);
        if isfield(Sx.out, 'NumEvaluations'), nAn(end+1, 1) = Sx.out.NumEvaluations; else, nAn(end+1, 1) = NaN; end
    end
end
T = table(string(names), nb, comp * 1e3, comp / m0.Compliance, nAn, 'VariableNames', {'Design', 'Bricks', 'Compliance_mJ', 'VsFullBeam', 'Analyses'});
fprintf('\n---------------- SCORE (smaller compliance = stiffer) ----------------\n');
disp(T);
fprintf('  your design: tip deflection %.1f um (full beam %.1f um), mass %.0f g, max von Mises %.0f MPa, %d of %d bricks kept%s\n', ...
    abs(met.OutDefl(1, 3)) * 1e6, abs(m0.OutDefl(1, 3)) * 1e6, met.Mass * 1e3, met.MaxVonMises * 1e-6, nKeep, nVar, ternary(okRule, '', '  [rules broken]'));
fprintf('  -> give your assistant: tip deflection %.1f um, %d bricks kept, compliance %.2f mJ (full beam %.2f mJ).\n', ...
    abs(met.OutDefl(1, 3)) * 1e6, nKeep, met.Compliance * 1e3, m0.Compliance * 1e3);
fprintf('  Note: stress is NOT part of the goal. Look at the stress figure: a stiff design can still be too highly stressed.\n');
fprintf('----------------------------------------------------------------------\n');
idt_sanity_checks(model, res, met);
idt_plot_brick_selection(model.Geom, bricks, M);
idt_plot_static(model, X, res);

%% 4. THINK ABOUT IT
% - Did the assistant follow the rules without being reminded? Did it ever invent a brick that does not exist?
% - Which round was best? Did the assistant use your numbers, or did it just guess again?
% - The optimizers needed hundreds to thousands of analyses. You needed a handful. What does that tell you about where
%   an assistant helps (ideas, reasoning, explaining) and where a solver is needed (numbers)?

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
