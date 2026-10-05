# 02 - Analysis: eigenfrequencies and harmonic response

```matlab
[res, met] = idt_analyze(model, X);     % X = which bricks are present (omit for "all")
```

`idt_analyze` runs the analysis chosen by `model.Params.Analysis.Type` (today `'ModalHarmonic'`).
It never draws anything. `idt_plot_analysis(model, X, res)` draws the results.

## What is computed

1. **Eigenproblem.** The generalized problem `K phi = omega^2 M phi` gives the natural frequencies
   `f = omega / 2 pi` and the mode shapes (mass-normalized). `K` is the stiffness matrix, `M` the mass
   matrix (consistent mass plus the optional lumped extra mass).
2. **Force FRF (frequency response).** A harmonic force `F0 exp(i w t)` acts at the load point.
   By modal superposition with modal damping ratio `Zeta`:

   `u(w) = sum_j phi_j (phi_j' F) / (w_j^2 - w^2 + 2 i Zeta w_j w)  +  static correction`

   The static correction restores the contribution of the modes that were not kept, so a small
   `NModes` still gives the right low-frequency level.
3. **Transmissibility** (if `P.Analysis.Transmissibility = true`). The clamped faces are treated as a
   rigid base that moves harmonically along x, y or z. `T` is the **absolute response of an output point
   divided by the base motion**. It is dimensionless and independent of the force amplitude.
   `T = 1` at low frequency, peaks at resonance, and falls below 1 above about `sqrt(2)` times the
   resonance frequency (isolation).

Removed bricks are deleted from the mesh (no artificial soft material). Pieces that are no longer
connected to a clamped node are dropped automatically and counted in `met.Dropped`.

## The outputs

`res` (raw)

| Field | Meaning |
|---|---|
| `Valid` | `false` if the load point or an output point is cut off from every support |
| `NaturalFreqs` | natural frequencies [Hz] |
| `Freq` | sweep frequencies [Hz] |
| `U`, `Amp` | complex displacement and its magnitude, size `[nOut x 3 x nFreq]` (x, y, z of each output point) [m] |
| `T`, `TAmp` | transmissibility, size `[nOut x 3 (response) x 3 (base direction) x nFreq]` |
| `Modes` | mode shapes on the global node numbering |
| `Mass`, `DroppedElems`, `ModalCoverage`, `Active`, `NumDOFs`, `SolveTime` | mass [kg], floating elements removed, kept modes / sweep end, active elements, size, time |

`met` (reduced numbers for reports and optimizers)

| Field | Meaning |
|---|---|
| `Valid` | as above |
| `NaturalFreqs`, `f1`, `f2` | kept natural frequencies, first two |
| `Mass` | total mass [kg] |
| `VolFrac` | fraction of design bricks present (`NaN` without a design domain) |
| `Dropped` | floating elements removed |
| `FRFPeak`, `FRFPeakFreq` | `[nOut x 3]` peak displacement amplitude and its frequency |
| `StaticDefl` | `[nOut x 3]` amplitude at the lowest sweep frequency, about the static compliance times `F0` |
| `TPeak`, `TPeakFreq` | `[nOut x 3 x 3]` peak transmissibility (response direction x base direction) and its frequency |

## Reading the figures of `idt_plot_analysis`

| Figure | How to read it |
|---|---|
| Design | the meshed structure, colored by part. Red = supports, magenta arrow = load, green numbers = outputs. |
| Displacement FRF | one row per direction x, y, z; one line per output. Dotted vertical lines are natural frequencies. A peak at a dotted line is a resonance. |
| Mode shapes | the first four modes with exaggerated deformation. Color = displacement magnitude. |
| Transmissibility | solid line = response in the same direction as the base motion. The dotted line marks `T = 1`. |

## Things to watch

* **Mesh sensitivity.** Frequencies depend on the mesh, most for thin parts. Compare a coarse and a
  fine mesh before trusting a number.
* **TET4 vs TET10.** TET4 is stiff (about 18 % high in frequency in the validation case). Use TET10
  (`P.Mesh.Order = 'quadratic'`) for results, TET4 for fast experiments.
* **Resonance amplitudes** of a linear model with small damping are large. They scale linearly with
  `LoadAmplitude`.
* **Damping** is one modal ratio for all modes. Real materials (for example TPU) can differ a lot.
* **Frequency step.** If the step is coarser than the width of a resonance peak, the peak can be
  missed. Use a smaller `FreqStep` for the final result.

## Validation

The natural frequencies match MATLAB's own `structuralModal` solver to four decimals on the same
mesh (both element orders). The transmissibility was checked against a direct undamped solve with a
maximum relative error of 4e-5. The force FRF and the multi-material assembly are not compared against
another solver.

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
