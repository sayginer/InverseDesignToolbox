# 11 - Static optimization (SIMP, genetic algorithm, neural network, shape cutters)

The same four optimizers as for the harmonic problem, for the static cantilever of `docs/10_static_load.md`. The brick optimizers work on the layout
`X`, the shape optimizer on cutter numbers; all evaluate designs only through `idt_analyze` (`P.Analysis.Type = 'Static'`). Run
`SIM_StaticLoad.m` first: it saves `results/CantileverBeam.mat`, which the case studies load.

| Runner | Optimizer | Goals |
|---|---|---|
| `CASE_SIMP_StaticBeam.m` | `optimizers/static/static_simp_optimize.m` | `'MinCompliance'` |
| `CASE_GA_StaticBeam.m` | `optimizers/static/static_ga_optimize.m` | `'MinCompliance'`, `'MinMass'` |
| `CASE_NN_StaticBeam.m` | `optimizers/static/static_nn_optimize.m` | `'MinCompliance'` |
| `CASE_GA_Shape_StaticBeam.m` | `optimizers/shape/shape_optimize.m` (new static goals) | `'MinCompliance'`, `'MinMass'` |

All options are documented in `optimizers/static/static_options.m`. Plot convergence with
`static_plot_history(out)`.

## Goals

* **MinCompliance** - the stiffest layout (smallest `F'u`) that uses at most `S.VolMax` of the
  design-brick volume. Bricks locked by supports, load or outputs are solid and not counted.
* **MinMass** (GA) - the lightest layout whose tip deflection (output 1 along the load direction)
  stays below `S.MaxDeflection` [m].

## SIMP

One density per brick; a brick scales the stiffness of its elements by `Emin + (1-Emin) rho^p`.
Densities are smoothed by a distance filter on the brick grid (no checkerboards) and sharpened by a
Heaviside projection whose `beta` doubles from 1 to `BetaMax`. The update is the optimality-criteria
rule with a bisection on the volume; gradients are analytic (the problem is self-adjoint), so one
solve per iteration. At the end the densities are thresholded to the volume limit, optionally cleaned
(`S.Clean`) and analysed with the real analysis (removed bricks are deleted from the mesh).

## Genetic algorithm

A population of bit strings (one bit per brick) evolves with `ga`: two-point crossover, uniform
mutation, random smooth starting layouts. Every individual is one real static analysis, evaluated in
parallel when the Parallel Computing Toolbox is available. Cost: `compliance / compliance_full` plus
a penalty for exceeding `VolMax` (`MinCompliance`), or `mass / mass_full` plus a penalty for
exceeding `MaxDeflection` (`MinMass`). A layout cut off from the supports costs 50.

## Neural network

Same method as `nn_optimize` for frequencies: real static analyses of random smooth layouts train a network (3-D CNN or MLP) that
predicts the relative stiffness `compliance(full) / compliance(layout)`; a genetic algorithm searches the network (milliseconds per
design) with the volume penalty; the best candidates are verified with the real analysis, added to the data and the network is retrained
(rounds). Options: `NN*` in `static_options`. Needs the Deep Learning Toolbox.

## Shape cutters

The design is a list of holes and rectangles subtracted from the design frame (`docs/08_shape_cutters.md`), searched by a genetic
algorithm; `shape_optimize` has the two static goals `'MinCompliance'` (`H.VolMax` = fraction of the design frame that may remain)
and `'MinMass'` (`H.MaxDeflection`). The shape module cuts through z, but the beam's thickness is along y, so the case study
rotates the geometry on import: `P.Geometry.Rotate = [-90 1 0 0]` (new option: `[angle_deg ax ay az]`, every part is rotated
about that axis through the origin; face numbers do not change). The load direction and output points are rotated with it. The final
design is re-meshed from the exact CAD cut and re-analysed; the compliance on the optimization mesh and
on the exact cut differed by 0.22 % in the full run (below). Five small cutters (hole radius up to 6 mm, rectangles up to 20 mm) cannot remove much of the 140 x 40 mm web, so `H.VolMax` = 0.85 is used; with 0.7 the GA ended at 82.5 %, i.e. above the limit (infeasible).

## Measured (R2026a, TET4 Hmax 3 mm, 500 N, 63 of 126 bricks = 50 %)

| Layout | Tip deflection | Compliance | Mass | Time |
|---|---|---|---|---|
| all bricks (reference) | 45.5 um | 22.8 mJ | 297 g | - |
| SIMP, 200 iterations | 67.6 um | 33.8 mJ | 221 g | 93 s |
| GA, 40 generations x 60 (2343 analyses) | 81.8 um | 41.3 mJ | 221 g | 189 s |
| Neural network, 4 rounds, 800 + 96 analyses (R^2 of the network about 0.7) | 95.5 um | 47.9 mJ | 221 g | 177 s |
| 80 x 20 mm window cut by hand (SIM_StaticLoad, TET4) | 97.8 um | - | 256 g | - |
| Shape cutters: 3 holes + 2 rectangles, 85 % of the web left (1562 analyses; different mesh, 2.5 mm) | 50.6 um | 25.4 mJ | 275 g | 390 s |

SIMP is better and cheaper here because it has gradients. The neural network needs fewer real analyses than the GA but ends worse: the problem has only 126 bricks and an analysis costs a fraction of a second (0.1-0.3 s here), so a surrogate does not pay off (a surrogate should pay off for finer brick grids or more expensive analyses; not tested here). With 300 instead of 800 training layouts the network was worse (R^2 near 0, 50.1 mJ; measured before mechanisms were excluded, see below). Times depend on the machine; the GA and neural-network results change with the random seed. The GA needs no gradients, so it also
handles `'MinMass'` and any goal you can compute, but its answer depends on the seed and the number
of generations.

## Mechanisms

A random layout can join two pieces only along an edge or at a corner. Such a layout is a mechanism: the stiffness matrix is singular and any displacement
it gives is meaningless. `solve_static` detects this (MATLAB's singular-matrix warning is turned into an error), returns `Valid = false` and sets `res.Mechanism = true`, so
optimizers and training data skip it. In 60 random layouts of the example beam, 8 were mechanisms. The `S.Clean` option (default settings) also removes edge and corner
contacts; the case studies set `S.Clean = []` for simplicity.

## Pitfalls

* The outer frame (steel flanges) is not a design variable and carries most of the bending, so the
  web bricks change the stiffness only moderately. Save mass first, stiffness second.
* The peak von Mises stress of the optimized layout is higher than that of the full beam. It is not a
  constraint of either optimizer; check `met.MaxVonMises`.
* A coarser mesh changes the answer slightly: keep `Hmax` below about 0.7 x the brick edge (6.7 mm).
* `S.Clean = []` here: with only 6 bricks over the height, the default 2-brick minimum width would
  remove most of the layout. Set `MinWidth` / `CloseGaps` for finer brick grids.

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
