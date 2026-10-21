# AGENTS.md - InverseDesignToolbox

Instructions for any AI assistant or coding agent working in this folder. Students use this toolbox to
**design a part first, then analyse it**. Your job is to help them do that, not to hide the steps from them.

## What this toolbox is

A small MATLAB toolbox for teaching inverse design with finite elements: import CAD (STEP), set supports and a load,
simulate, and (optionally) let an optimizer find a better design. Author: Dr. Osman Sayginer. Full overview: `README.md`.

## How to help a student (the order matters)

1. **Start from the task, not the code.** Ask what part they want, what is fixed, what load acts, and what "better" means
   (stiffer, lighter, a target frequency).
2. **Copy the closest example** and change its parameters; do not write a new pipeline:
   - static load (deflection, stress): `SIM_StaticLoad.m`
   - vibration (natural frequencies, harmonic response): `SIM_HarmonicMotion.m`
3. **Run the numbered steps in order.** Every step shows a figure. Have the student look at the figures of step 1 (face
   numbers), step 3 (brick selection) and step 4 (supports, load) **before** you go on. Do not skip them.
4. **Simulate first, optimize second.** Only after the plain simulation looks right, use an optimizer (`CASE_*.m`).
5. **Verify the answer** (see "Check every result" below) and explain it in plain words.

## Rules of the toolbox

- **Units are SI everywhere:** meters, kilograms, newtons, seconds, Hz. `1e-3` = 1 mm. Stress is in Pa (figures show MPa).
- **All parameters live in one struct `P`** (geometry, design, BC, mesh, analysis). Defaults are in
  `functions/model/idt_default_params.m`; parameters are documented in `docs/01_model_setup.md`.
- **Face numbers** come from `list_faces(geom)` / the step-1 figure. They depend on the order of the CAD files. Never guess them.
- **Analysis types:** `P.Analysis.Type = 'ModalHarmonic'` or `'Static'`. Everything is evaluated through
  `[res, met] = idt_analyze(model, X)`.
- **Do not edit `core/`** (the validated finite-element engine) or the dispatcher unless the task is to extend the toolbox
  (`docs/99_extending.md`). Add new files instead.
- **No figures in compute functions.** Figures belong in `functions/plotting/` and in the `SIM_*.m` / `CASE_*.m` scripts.
- **Style:** one function per file, a header comment with inputs and outputs, units in comments (`% [m]`),
  header line `Author: Dr. Osman Sayginer (InverseDesignToolbox)`.

## Helpers to use

- `idt_validate_params(P, geom)` - plain-language check of the parameters (already called by the `SIM_*` scripts and `idt_build_model`). Run it after you fill in `P`.
- `idt_sanity_checks(model, res, met)` - reaction = load? mesh finer than the bricks? floating pieces? Read every line with the student.
- `idt_export_dataset(model, n, name)` - random layouts + results as CSV for machine-learning exercises.
- `EXERCISE_SurrogateData.m` (how much data does a network need?) and `EXERCISE_AIDesigner.m` (an assistant proposes a design, the solver scores it).
- `docs/00_course_guide.md` - the course sequence and grading ideas.

## Design tools (pick one with the student)

| Method | Script | Good for |
|---|---|---|
| Brick layout by hand | step 3 of `SIM_*.m` | first designs, understanding |
| SIMP topology optimization | `CASE_SIMP_*.m` | smooth, gradient-based, fast |
| Genetic algorithm | `CASE_GA_*.m` | any goal, needs no gradients |
| Neural-network surrogate | `CASE_NN_*.m` | learning how machine learning helps design |
| Holes and rectangles (shape) | `CASE_GA_Shape_*.m` | printable cut-outs, round holes |

The neural network is not always the best choice: on small, cheap problems SIMP or the GA can win. Say so honestly and let
the student see the numbers (`docs/11_static_optimization.md` has a measured comparison).

## Check every result

An AI proposes, the solver verifies, and a human checks that the solver was asked the right question.

- Static: the printed **reaction check** must equal minus the load. Compare the tip deflection with a hand estimate.
- Mesh: elements should be clearly smaller than a brick (`Hmax <= ~0.7 x brick edge`). Try a finer mesh and see if the answer moves.
- Peak stress at a clamp or load face depends on the mesh; read stress away from them.
- Vibration: `modal coverage` should be above 1.5.
- State what the optimizer actually optimized (e.g. compliance at 50 % volume). Stress is **not** constrained unless the
  student adds it.

## Known pitfalls

- The shape module cuts **through z**. If the part's thickness is along another axis, set `P.Geometry.Rotate = [angle ax ay az]`
  (and rotate the load direction and output points with it); face numbers do not change.
- A point load is a stress singularity; prefer `P.BC.LoadFaces`.
- A brick design needs `Layers`/`Density` that give at least a few bricks across the part; very coarse grids make cleanup
  (`S.Clean` / `H.Clean`) delete the design.
- Optimizers use the Parallel Computing Toolbox if available and fall back to serial; the first run starts a pool (slow once).
- Toolboxes needed: PDE (always); Global Optimization (GA); Deep Learning (neural network); Image Processing (printability
  cleanup); Optimization (original SIMP). See `README.md` section 2.
- A layout whose bricks touch only along an edge or corner is a **mechanism**; the static solver reports it as not valid (`met.Valid = false`). Remaining bricks must join face to face.
- Results are saved in `results/`; do not overwrite a student's files, use a new `ProblemName`.

## Working style

- Make small changes, run the script, show the figure, then continue.
- Explain *why* a parameter was chosen; students are learning, so prefer the simplest design that works.
- If something is untested or uncertain, say so instead of guessing. Never invent results, face numbers or material data.
