# 03 - SIMP topology optimization

SIMP (Solid Isotropic Material with Penalization) decides **which bricks of the design domain are solid and which
are void** by following exact gradients instead of trying designs at random. It is the first optimizer module:
`optimizers/topology/`, used from the case study `CASE_SIMP_TargetFrequency.m`.

```matlab
H    = simp_options(H);                           % defaults + checks            (simp_options.m)
S    = simp_precompute(model, H.FilterRadius);    % matrices that never change   (simp_precompute.m)
out  = simp_optimize(model, S, H);                % the optimization loop        (simp_optimize.m)
post = simp_postprocess(model, S, out, H);        % densities -> solid bricks    (simp_postprocess.m)
```

The module only uses the core: `model` comes from `idt_build_model`, designs are verified with `idt_analyze`.
No figure is drawn inside these four functions (except the optional live plot).

## 1. How to run a case study

1. Run `SIM_HarmonicMotion.m` once, check every step, and let it save `results/<ProblemName>.mat`.
2. Open `CASE_SIMP_TargetFrequency.m`. It loads that file, builds the model, and lists every SIMP option in
   section 2. Choose the goal, run it (F5), read the figures.
3. Results are saved to `results/SIMP_<ProblemName>.mat` (`post`, `out`, `H`, `P`).

Runtime on the example (402 bricks, TET4): about 1 to 2 minutes.

## 2. What is optimized

| `H.Objective` | Meaning | Needed |
|---|---|---|
| `'TargetF1'` | make the first natural frequency equal `TargetF1`: minimize `((f1 - TargetF1)/TargetF1)^2` | `H.TargetF1` |
| `'MaximizeF1'` | make f1 as high as possible for a material budget: minimize `-f1/f1_ref` | `H.VolMax` (volume fraction of the design domain, 0 to 1) |

Both are eigenfrequency goals, so one eigenvalue solution gives the exact gradient. Goals based on the
harmonic response (for example transmissibility) need their own sensitivities and are not part of SIMP here.

## 3. The method, step by step

Design variable: **one density `rho` between 0 (void) and 1 (solid) per brick.** Every mesh element of a brick takes its
brick's density. Elements outside the design domain (holder, fixed frame, bricks locked by supports) stay solid.

One evaluation of `simp_optimize`:

1. **Filter.** `rho_t = Hf * rho`. A cone filter averages each brick with its neighbours within `FilterRadius`.
   Isolated bricks vanish (no floating islands, no checkerboards) and features thinner than about the radius cannot form.
2. **Projection.** `rho_p = Heaviside(rho_t; beta, eta)` pushes the field towards 0 and 1. `beta` is increased in stages
   (continuation): `1, 2, 4, ... BetaMax`.
3. **Interpolation (the "SIMP" part).** Stiffness `E = E0 (RhoMin + (1 - RhoMin) rho_p^p)`, mass `m = m0 rho_p^q`.
   With `p = 3`, grey material is stiff-inefficient but still costs mass, so the optimizer prefers solid or void.
4. **Eigenproblem.** `K phi = lambda M phi` gives `f1 = sqrt(lambda_1) / 2 pi`.
5. **Adjoint gradient.** `d lambda / d rho_e = phi_e' (dK_e - lambda dM_e) phi_e`. **One** eigenvector gives the gradient
   with respect to **all** densities at once. A genetic algorithm would need one analysis per variable for the same information.
6. **Chain rule** through projection and filter gives `d f1 / d rho`.
7. **Update.** `fmincon` (Optimization Toolbox, algorithm `sqp`) takes the objective and gradient and moves the densities.
   One `fmincon` call per `beta` stage, starting from the previous result.

After the last stage `simp_postprocess` converts densities to solid bricks: for each cutoff in `H.Thresholds` it keeps the
bricks with `rho_p` above the cutoff, analyses that layout with `idt_analyze`, and keeps the best **valid** one (closest f1
to the target, or highest f1 within `VolMax`). Valid means the load and output points are still connected to the supports.

## 4. Options (`simp_options.m` explains each one in detail)

| Group | Option | Default | Effect |
|---|---|---|---|
| goal | `Objective`, `TargetF1`, `VolMax` | `'TargetF1'`, - , - | see section 2 |
| field | `FilterRadius` | `'auto'` | filter radius [m] or `'auto'` = 1.3 x `Clean.MinWidth` x the in-plane brick edge (8 mm here). Must match the printable minimum width; larger = thicker, smoother arms |
| field | `VolFracInit`, `RhoFloor` | 0.30, 0.01 | start density, smallest density |
| SIMP | `PenalStiff` | 3 | penalization power `p` |
| SIMP | `RhoMin` | 1e-6 | stiffness of void. **Keep tiny** (see section 6) |
| SIMP | `PenalMass` | 1 | mass interpolation power |
| projection | `BetaStart`, `BetaMax`, `Eta` | 1, 64, 0.5 | sharpness continuation. `BetaMax = 1` turns the projection off |
| fmincon | `Algorithm`, `StageIter`, `MoveLimit` | `'sqp'`, 10, 0.3 | solver, iterations per stage, trust region per stage |
| post | `Thresholds` | 0.1 ... 0.9 | cutoffs tried for the solid layout |

## 5. Outputs

`out` (from `simp_optimize`): `.rho` (design variables), `.rho_t` (filtered), `.rho_p` (projected), `.History` (f1, f2,
volume fraction, grey fraction, beta, J, time per evaluation), `.Iterations`, `.TotalTime`.

`post` (from `simp_postprocess`): `.X` (solid layout, one entry per design brick), `.M` (brick matrix for
`idt_plot_brick_selection`), `.rho_b`, `.Threshold` (cutoff used), `.Sweep` (every cutoff tried), `.met`, `.res`
(the full analysis of the final design, plot it with `idt_plot_analysis`).

Figures of the case study: convergence (`simp_plot_live`), brick densities and solid layers by z layer
(`simp_plot_density`), the layout as clean bricks (`idt_plot_brick_selection`), and the analysis figures.

**Printability (see `docs/05_printability.md`).** Every threshold candidate is cleaned (no checkerboards, islands or features
thinner than 2 bricks) and the winner is polished brick by brick with the real analysis. This is on by default (`H.Clean`,
`H.Polish`; `[]` switches them off). Cleaning shifts f1 (107.6 to 117.8 Hz for the 100 Hz target) and polish brings it back
(final: 97.75 Hz, 26 bricks, 2 face-connected arms, all features at least 2 bricks wide).

**The filter radius must match the printable minimum width (`H.FilterRadius = 'auto'`).** SIMP does not know the minimum feature
width; the filter radius is what sets it. With a radius below the minimum SIMP builds thin features that the clean-up then removes.
Measured for `MaximizeF1` with `VolMax = 0.15` (402 bricks, brick edge 3.08 mm, `MinWidth = 2` = 6.2 mm):

| Filter radius | continuous f1 | solid, no clean-up | solid, cleaned |
|---|---|---|---|
| 4.5 mm (old default, 1.5 edges) | 173.8 Hz | 173.8 Hz | **32.5 Hz** (polish only reached 58.9 Hz in 12 steps) |
| 6.5 mm | 157.2 Hz | 157.2 Hz | 39.8 Hz |
| 7.0 mm | 163.3 Hz | 163.1 Hz | 133.5 Hz |
| 7.5 mm | 148.1 Hz | 148.3 Hz | 146.8 Hz |
| 8.0 mm (`'auto'` = 1.3 x MinWidth x edge) | 148.2 Hz | 148.3 Hz | 146.8 Hz |
| 10 mm | 147.4 Hz | 147.5 Hz | 146.5 Hz |

From about 7.5 mm up the cleaned printable layout is within 1 to 2 Hz of the continuous optimum, so `'auto'` uses 1.3 x
`Clean.MinWidth` x the in-plane brick edge (8.0 mm here) and follows `H.Clean.MinWidth` automatically. The price is real: wider
features give a lower f1 (148 Hz against the 174 Hz of the thin, unprintable optimum). One run with a 4.3 mm radius happened to keep
173.9 Hz through the clean-up, but that was luck of the optimization path; the same radius range lost nearly everything in another run.
For a frequency target the polish still closes the last gap (123.3 Hz after cleaning, 99.58 Hz after 8 polish steps; 28 bricks).
The GA and the neural network, which judge cleaned layouts directly, reach about 177 Hz for the same goal
(`docs/07_genetic_algorithm.md`) because they search printable layouts that need not be as wide as SIMP's filtered design.

## 6. Things to know (these cost me time, so they are written down)

* **Grey material.** Without projection (`BetaMax = 1`) SIMP lowers or raises f1 with uniform grey density, which cannot be
  built. In a test the continuous design hit 18 Hz, but the solid bricks gave 54 Hz. The projection and the `beta` continuation
  fix most of this; look at the "Grey" column in the log (it should end near 0).
* **Void must not be a spring.** With `RhoMin = 1e-4` the void was soft enough to hold the holder at about 14 Hz, so the
  optimizer "reached" a low target with a disconnected design. `RhoMin = 1e-6` removes that.
* **Continuous vs solid.** The solid design can differ from the continuous optimum because whole bricks replace a smooth field.
  Example (`TargetF1 = 100 Hz`): continuous 99.8 Hz, solid 107.6 Hz (`BetaMax = 64`; with 16 the solid design was 120 Hz).
  For `MaximizeF1` with a 15 % volume cap both agreed (173.76 Hz). Always read the f1 of the **solid** design (`post.met.f1`).
* **Number of bricks.** `sqp` builds a dense Hessian: about 1 to 2 minutes for 402 bricks, but 2299 bricks did not finish in
  20 minutes. Use bigger bricks (lower `P.Design.Density`), or try `H.Algorithm = 'interior-point'` (not tuned).
* **Local optima.** SIMP finds a good design near its starting point, not the global best, and the result need not be symmetric.
  Different `VolFracInit`, `FilterRadius` or `TargetF1` give different layouts.
* **Mesh.** Keep `Hmax` at most 0.7 x the brick edge, otherwise bricks hold too few elements and the density field is not
  resolved.
* **The target-frequency goal alone does not make an isolator.** A design with f1 = 18 Hz can still have a second mode right next
  to f1 and amplify above the cutoff. Check the transmissibility figure of the final design.

## 7. Verified results (example assembly, 402 bricks, TET4, 2 mm mesh)

| Case | Continuous f1 | Solid-brick design | Notes |
|---|---|---|---|
| `TargetF1 = 100`, `BetaMax = 64`, no clean-up | about 100 Hz | f1 = 107.6 Hz, 36 of 402 bricks, 17 g | about 2 minutes |
| same, with clean-up and polish, old radius 4.5 mm | about 100 Hz | f1 = 97.75 Hz, 26 of 402 bricks, 16.8 g, printable | about 3 minutes |
| same, default `FilterRadius = 'auto'` (8 mm) | about 100 Hz | f1 = 99.58 Hz, 28 of 402 bricks, 16.9 g, printable, closed STL | about 2.5 minutes |
| `MaximizeF1`, `VolMax = 0.15`, `'auto'` radius | 148.1 Hz | f1 = 148.14 Hz, 59 of 402 bricks, 17.5 g, printable, closed STL | about 2 minutes |
| `MaximizeF1`, `VolMax = 0.15`, `BetaMax = 64` | 173.76 Hz | f1 = 173.76 Hz, 61 of 402 bricks, 17.5 g | volume cap respected, 106 s |

**Gradient check.** With `H.CheckGradients = true` the adjoint gradient of the `TargetF1` objective (402 bricks, `beta = 4`)
was compared with finite differences by `checkGradients`: maximum relative difference 1.8e-5. The `MaximizeF1` objective uses
the same f1 gradient with a different scale factor; the gradient of its volume constraint was not checked separately, but that
run kept the 15 % volume cap.

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
