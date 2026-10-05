# 04 - Neural-network surrogate optimization

A second optimizer module, `optimizers/neural/`, used from `CASE_NN_TargetFrequency.m`. It has the same problem and
the same goals as SIMP (`'TargetF1'`, `'MaximizeF1'` with `VolMax`), so the two can be compared directly.

**Idea.** The finite-element analysis is accurate but takes about a second. A trained network predicts f1 from a brick
layout in about a millisecond. A genetic algorithm can then try hundreds of thousands of layouts on the network, and only
the most promising ones are checked with the real analysis.

```matlab
H   = nn_options(H);                       % defaults + checks              (nn_options.m)
out = nn_optimize(model, H);               % the whole procedure            (nn_optimize.m)
%   inside:  nn_make_dataset  -> nn_train -> ga on nn_predict -> verify with idt_analyze -> calibrate -> repeat
```

Everything uses toolboxes: `trainnet` and layers (Deep Learning Toolbox), `ga` (Global Optimization Toolbox), `parfor`
(Parallel Computing Toolbox, optional). No figure is drawn inside the compute functions.

## 1. How to run a case study

1. Run `SIM_HarmonicMotion.m` once and let it save `results/<ProblemName>.mat`.
2. Open `CASE_NN_TargetFrequency.m`, choose the goal in section 2, run it (F5).
3. Results are saved to `results/NN_<ProblemName>.mat`. `out.D` holds every analysed layout and can train other networks.

Runtime on the example (402 bricks, 6 parallel workers): about 8 minutes, of which about 2 minutes are FEA; the rest is training and
the genetic algorithm (every individual is cleaned in every generation).

## 2. The procedure

1. **Training data** (`nn_make_dataset`). Random smooth layouts: a random field is smoothed over the bricks and thresholded
   to a random volume fraction (5 to 45 %). Smooth layouts resemble real designs; independent random bricks would almost
   never be usable. Layouts that do not connect the load to the supports are skipped without any FEA (`nn_validity_setup`,
   an exact graph test of about 0.1 ms). The rest are analysed with `idt_analyze`, in parallel.
2. **Training** (`nn_train`). A 3-D convolutional network sees the brick grid as a small 3-D image (two channels: brick
   present, brick exists) and predicts `log(f1)`. 15 % of the data is held back and never used for fitting; its errors measure
   how far the network can be trusted. `H.Network = 'mlp'` selects a plain fully connected network instead.
3. **Search** (`nn_optimize`). `ga` (bit-string population, vectorized, two-point crossover) minimizes the cost
   `((f1_predicted - target)/target)^2` (or `-f1`), plus a volume penalty and a large penalty for cut-off layouts. It starts
   from the best layouts verified so far.
4. **Verification.** The best `TopK` new layouts are analysed with the real FEA (in parallel).
5. **Calibration.** The search exploits the network's mistakes, so the network is typically biased exactly where the search
   looks. The median of `log(true f1 / predicted f1)` over the verified layouts corrects the cost and steps 3 and 4 repeat
   (`H.Passes` per round).
6. **Retraining.** All verified layouts join the training data with weight `H.VerifiedWeight`. A verified layout that turned
   out to be a hinge enters with the label f1 = 1 Hz, which teaches the network to avoid that region.

The final answer is the best layout that was verified with the real analysis, never a prediction.
`out.FromSearch` tells you whether it was proposed by the search or was one of the random starting layouts.

## 3. Options (`nn_options.m` explains each one)

| Group | Option | Default | Meaning |
|---|---|---|---|
| goal | `Objective`, `TargetF1`, `VolMax` | `'TargetF1'` | same as SIMP |
| data | `NumSamples`, `VolFracRange`, `FieldRadius` | 1000, [0.05 0.45], 6e-3 | number, volume range and smoothness of the random layouts |
| data | `UseParallel`, `Seed` | true, 1 | parallel analyses, reproducible data |
| network | `Network`, `MaxEpochs`, `MiniBatch`, `LearnRate`, `ValFraction` | `'cnn'`, 300, 64, 1e-3, 0.15 | architecture and training |
| search | `PopSize`, `Generations`, `TopK` | 300, 150, 24 | ga size, candidates verified per pass |
| rounds | `Rounds`, `Passes`, `VerifiedWeight` | 4, 2, 5 | train + search cycles, calibration passes, weight of verified layouts |
| printability | `Clean`, `Polish` | `struct()`, `struct()` | clean-up of every layout and final polish, see `05_printability.md` (`[]` = off) |

## 4. Outputs

`out.X` (best verified layout), `out.M` (brick matrix for `idt_plot_brick_selection`), `out.met` and `out.res` (full analysis,
plot with `idt_plot_analysis`), `out.D` (all analysed layouts), `out.sur` (the last network, `nn_predict(out.sur, X)`),
`out.Rounds` (per round: surrogate R^2 and error, candidates verified and usable, error before / after calibration, best f1),
`out.FromSearch`, `out.TotalTime`. Figure: `nn_plot_surrogate(out)` shows the network's predicted-vs-true f1 on held-back
layouts and, per round, its error on the search's own proposals and the best verified f1.

## 5. What I measured (example assembly, 402 bricks, TET4, 2 mm mesh, 6 workers)

All layouts below are printable: the clean-up of `docs/05_printability.md` (`H.Clean`, `H.Polish`) is on by default.

| Goal | Result |
|---|---|
| `TargetF1 = 100 Hz` (latest run with the full clean-up incl. diagonal / corner repair, 465 s, 1186 analyses) | final layout proposed by the search: f1 = 100.01 Hz, 72 bricks, 17.7 g, f2 = 358 Hz; the network's error on its own proposals was 1 to 5 % in the best rounds. Exported as a closed single-piece STL (1882 triangles, 9400 mm^3). |
| `TargetF1 = 100 Hz` (earlier run, 499 s, 1177 analyses) | final layout proposed by the search: f1 = 100.02 Hz, 56 bricks, 17.4 g, f2 = 291 Hz. |
| `TargetF1 = 100 Hz` (previous run of the same setup) | final f1 = 100.30 Hz, but it was one of the random starting layouts; the search's own candidates were 76 to 93 Hz. Runs differ because `ga` and training are stochastic. |
| `MaximizeF1`, `VolMax = 0.15` (before the printability clean-up) | final f1 = 152.25 Hz, proposed by the search. SIMP reaches 173.76 Hz for the same goal in about 100 analyses. Not re-measured with the clean-up. |

Network quality on held-back layouts with the clean-up: R^2 of log f1 0.85 to 0.88, mean error 16 to 20 %. Before the clean-up it was
0.65 to 0.75 and 30 to 35 %: printable layouts are simply easier to learn (97 % of the cleaned random layouts give a usable analysis,
against 79 % before). The network's error on the layouts the search proposes was 4 to 7 % in the best rounds, but 33 to 36 % in
one round: calibration does not always help.

**Honest summary.** The pipeline works and, with the clean-up, usually finds a printable layout within about 0.3 Hz of a 100 Hz target,
but the result varies from run to run and it needs about 1200 analyses where SIMP needs about 100. For a single target on one problem,
SIMP is the cheaper tool. The network pays off when you want many answers from one training: after training, `nn_predict` answers
"what is f1 of this layout?" in a millisecond for any new target.

## 6. Things to know (these cost me time, so they are written down)

* **Hinges.** About one in five connected random layouts has parts joined only at a mesh node or along an edge. They turn
  the structure into a mechanism (rotation modes at 0 Hz) and f1 is meaningless (the solver still reports `Valid = true`). They arise
  inside bricks when the mesh is not much finer than the bricks (here 2 mm elements against bricks 1.67 mm thick) and cannot be
  predicted from the brick layout: a classifier reached an AUC of only 0.62 and a graph rule on face contact did not catch them.
  They are flagged unusable (f1 < 1 Hz) and excluded from the first training set. A finer mesh (`Hmax` about 0.7 x the brick edge)
  would reduce them but multiplies the analysis time.
* **Scrambling crossover.** With ga's default (scattered) crossover 29 of 30 proposed candidates were hinges; with two-point
  crossover (contiguous blocks of bricks, as used here) 22 to 23 of 24 were usable.
* **The search exploits the network.** Candidates are the layouts the network likes best, so its error there is larger than on the
  held-back set (about 40 % before calibration). Hence the calibration pass and the weighted retraining.
* **Learning the failures.** Labelling all unusable layouts as f1 = 1 Hz from the start made the network collapse to a constant
  (held-back R^2 about 0): those labels depend on mesh details. Verified hinges found by the search are different (local and
  repeated), so they are used from round 2 on, and they helped `MaximizeF1`.
* **Data size.** 800 usable layouts give R^2 about 0.7. More data is better (about 1.5 minutes per 1000 layouts with 6 workers),
  but the network does not become accurate enough for tight targets.
* **Random seeds.** `H.Seed` fixes the data and the split; ga uses MATLAB's global random generator, so runs still differ.
* **Without the Parallel Computing Toolbox** the analyses run serially (about 6 times slower).

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
