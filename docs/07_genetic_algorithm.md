# 07 - Genetic algorithm

The third optimizer module, `optimizers/genetic/`, used from `CASE_GA_TargetFrequency.m`. Same problem, same goals
(`'TargetF1'`, `'MaximizeF1'` with `VolMax`) and same printability clean-up and STL export as SIMP and the neural network,
so the three can be compared directly.

```matlab
H   = genetic_options(H);                 % defaults + checks         (genetic_options.m)
out = genetic_optimize(model, H);         % the whole procedure       (genetic_optimize.m)
genetic_plot_history(out);                % best and mean cost per generation
```

Everything uses toolboxes: `ga` (Global Optimization Toolbox) and `parfor` through `ga`'s `UseParallel` (Parallel Computing
Toolbox, optional). No figure is drawn inside the compute functions.

## 1. The method

A **population** of brick layouts, each one bit per design brick (present / removed), evolves for several generations:

1. **Start.** Random smooth layouts (`idt_random_layouts`), cleaned.
2. **Cost of an individual.** (a) `idt_clean_bricks` makes it printable, so the GA only ever searches printable layouts;
   (b) `idt_analyze` runs the REAL eigenfrequency analysis; (c) the goal gives the cost: `((f1 - target)/target)^2` for
   `'TargetF1'`, `-f1/f1_full` for `'MaximizeF1'`, plus a volume penalty if `VolMax` is set. A layout that cannot be analysed
   (cut off from the supports, hinge-like) costs 50.
3. **Selection** keeps the better individuals, **crossover** (two-point: swaps contiguous blocks of bricks, which preserves local
   structure; ga's default scattered crossover shreds layouts) mixes two parents, **mutation** flips a few bricks, and the
   `EliteCount` best are copied unchanged.
4. **Stop** when the target is met (`FreqTol`), when the best cost stalls (`StallGenerations`) or at `Generations`.
5. **Polish** (`idt_polish_bricks`) closes the last gap with brick-by-brick changes, then the STL is exported.

The population is evaluated in parallel; the model is sent to the workers once (`parallel.pool.Constant`), not with every
generation.

## 2. Options (`genetic_options.m` explains each one)

| Group | Option | Default | Meaning |
|---|---|---|---|
| goal | `Objective`, `TargetF1`, `VolMax` | `'TargetF1'` | same as SIMP and the neural network |
| GA | `PopSize`, `Generations`, `StallGenerations` | 60, 40, 12 | population size, generation limit, stall limit |
| GA | `FreqTol`, `EliteCount` | 0.3 Hz, 3 | stop when the target is met, number of unchanged elites |
| GA | `CrossoverFraction`, `MutationRate` | 0.8, 0.004 | share of children from crossover, flip probability per brick |
| start | `VolFracRange`, `FieldRadius`, `Seed` | [0.05 0.45], 6e-3, 1 | volume range and smoothness of the starting layouts |
| printability | `Clean`, `Polish` | `struct()`, `struct()` | see `05_printability.md` (`[]` = off) |
| run | `UseParallel`, `Verbose` | true, true | parallel evaluation, progress lines |

## 3. Outputs

`out.X` (best layout), `out.M` (brick matrix for `idt_plot_brick_selection`), `out.met` and `out.res` (full analysis, plot with
`idt_plot_analysis`), `out.History` (best and mean cost per generation), `out.Polish`, `out.NumEvaluations`, `out.Generations`,
`out.TotalTime`. The case study ends with the manufacturable STL (`06_stl_export.md`).

## 4. How it compares

| | SIMP | Neural network | GA |
|---|---|---|---|
| Needs gradients | yes (adjoint, only for frequency goals) | no | no |
| Needs training data | no | yes (about 1000 analyses) | no |
| Real analyses used (example) | about 120 to 160 + polish | about 1200 | population x generations (1740 for `MaximizeF1`, see section 5) |
| Works for any goal | no (needs a gradient) | yes | yes |
| Result | local optimum near the start | depends on the surrogate | a good layout, not a proven optimum |

## 5. What I measured (example assembly, 402 bricks, TET4, 6 parallel workers)

All three methods used the same problem, the same clean-up (`MinWidth = 2`) and polish, and every result was exported as a closed,
single-piece STL.

**Goal `MaximizeF1`, `VolMax = 0.15`** (a goal random sampling cannot solve by luck):

| Method | Final f1 | Bricks | Real analyses | Run time | Remark |
|---|---|---|---|---|---|
| GA | **177.28 Hz** | 64 | 1740 (28 generations) | 158 s | volume 14.96 %, mean cost fell from +3.5 to -0.5 |
| Neural network | 176.91 Hz | 62 | about 1150 | 667 s | proposed by the search, polish added 1 brick |
| SIMP (default `FilterRadius = 'auto'`, 8 mm) | 148.14 Hz | 59 | about 170 + polish | 71 s + polish | wide features keep the clean-up loss to 1.3 Hz; they also cost frequency |
| SIMP (old radius 4.5 mm, before the fix) | 58.94 Hz | 53 | about 160 + polish | 68 s + polish | the thin continuous optimum (173.76 Hz) lost almost everything in the clean-up: 32.5 Hz, and 12 polish steps only reached 58.9 Hz |

**Goal `TargetF1 = 100 Hz`:**

| Method | Final f1 | Bricks | Remark |
|---|---|---|---|
| SIMP (`'auto'` radius) | 99.58 Hz | 28 | about 2.5 minutes including polish (8 polish steps) |
| Neural network | 100.01 Hz | 72 | about 8 minutes, about 1200 analyses |
| GA | 99.87 Hz | 113 | **not a real test**: the random starting population (60 layouts) already contained a layout within 0.3 Hz, so the GA stopped after generation 1 (46 s, 120 analyses). Use a tighter `FreqTol` or a goal that random layouts cannot hit to see it evolve |

**Reading it.** Once the layouts must be printable, the methods that judge the cleaned layout directly (GA, neural network) do best
on `MaximizeF1` (about 177 Hz against SIMP's 148 Hz): SIMP's filter forces wide features, and with the radius matched to the
minimum width it is robust but conservative. For a single frequency target all three work; SIMP is the cheapest. The GA is simple, needs no gradient and no training, and the
parallel analyses made 1740 real analyses take under 3 minutes here, but the number of analyses grows with population x
generations and a plain GA on single bricks scales badly with the number of bricks.

## 6. Things to know

* **Cost per analysis.** Every individual is a finite-element analysis (about 0.6 to 1 s here). Parallel evaluation divides that by
  the number of workers; without the Parallel Computing Toolbox the run is several times slower.
* **Many variables.** 402 bricks is a large search space for a GA. Starting from smooth random layouts, two-point crossover and the
  clean-up keeps it workable, but a plain GA on single bricks scales badly: with many more bricks use SIMP, or fewer, bigger bricks.
* **Not a proof.** A GA gives a good layout, not a guaranteed optimum, and different seeds give different layouts.
* **Cleaning inside the cost.** The clean-up changes which layout is judged: the GA never sees the unclean genotype's analysis, only
  the printable one. Two different genotypes can clean to the same layout; that is harmless.
* **Reproducibility.** `H.Seed` fixes the starting population; `ga` itself uses MATLAB's global random generator, so runs still differ.

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
