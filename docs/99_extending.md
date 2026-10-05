# 99 - Extending the toolbox

The toolbox is meant to grow one module at a time. There are two extension points.

## A. Add a new analysis type (static load, thermal conduction, ...)

An analysis type is one function file `functions/analysis/analysis_<type>.m` plus one line in the
`switch` of `functions/analysis/idt_analyze.m`.

**Contract**

```matlab
function [res, met] = analysis_static(model, X)
% res : raw results (displacement field, stresses, ...)  - must contain a logical field res.Valid
% met : reduced numbers used by optimizers and reports   - must contain met.Valid and met.Mass
```

* `X` is the design vector (`model.NumVars x 1` logical; empty when there is no design domain).
* Never draw figures. Put plotting in `functions/plotting/`.
* Return `Valid = false` (with `NaN` metrics) for a design that cannot be analysed, so optimizers can
  penalize it instead of crashing.

**Steps**

1. Copy `analysis_modal_harmonic.m`, rename it, replace the solver call.
2. Add a `case` in `idt_analyze.m` and a line to the error message.
3. Add any new inputs to `P.Analysis` in `idt_default_params.m` (so old params files still load) and
   to the parameter section of the simulation script (so students see them).
4. Add a plotting function, a simulation script `SIM_<Physics>.m` modelled on `SIM_HarmonicMotion.m`, and a short page `docs/0x_<type>.md`.

The model (geometry, mesh, supports) is shared. A static analysis can reuse `core/tet_element_matrices`,
the stiffness assembly in `core/solve_frf.m`, and `P.BC` (a static load uses `LoadPoint`, `LoadDirection`,
`LoadAmplitude`). New BC kinds (pressure, temperature) add fields to `P.BC`.

## B. Add an optimizer module (topology, shape, neural network, ...)

An optimizer module is a folder (for example `topology/`) of plain functions. Each case study that uses it is one
runner script `CASE_<name>.m` in the toolbox root: it picks a problem, a simulation and an optimizer, sets the optimizer's
parameters and plots. Swapping the optimizer should change one line of the runner. Rules:

1. It builds the model with `idt_build_model` and evaluates designs only through `idt_analyze`.
2. It does not modify anything in `core/`, `functions/model/` or `functions/analysis/`.
3. It keeps compute functions free of figures. A script may call plotting functions.
4. It documents its parameters in `docs/` the same way as the core.

**Design representation is the module's job.** The topology module represents a design as the brick
vector `X`. The shape module (`docs/08_shape_cutters.md`) represents it as a list of cutters (holes and rectangles): the
optimizer's numbers become cutters (`idt_cutters_from_vector`), the cutters become an element mask for the fast analysis
(`idt_cutters_mask`) or an exact CAD cut (`idt_cutters_geometry`). It still evaluates designs only through `idt_analyze`.

**Objectives** (the goal an optimizer minimizes) are defined per module on top of `met`, for example
"match f1 to a target" or "keep the peak response below a limit". They are agreed and added in the step
that needs them; they are deliberately not part of the core.

## Style rules used in this toolbox

* Plain MATLAB and the official toolboxes; no hand-written solvers where a toolbox function exists.
* One function per file; the file starts with a comment that says what it does, its inputs and its outputs.
* Units are SI everywhere. Names with units in comments, e.g. `% [m]`, `% [Hz]`.
* No figures in compute functions; one short runner script per task (`SIM_*.m` for a simulation, `CASE_*.m` for a case study), parameters at the top.

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
