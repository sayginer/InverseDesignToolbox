# InverseDesignToolbox

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23523181.svg)](https://doi.org/10.5281/zenodo.23523181)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![MATLAB R2023b+](https://img.shields.io/badge/MATLAB-R2023b%2B-orange)

**AI-supported mechanical engineering design in MATLAB, for students.** Import CAD, set supports and a load, analyse the part
with finite elements (static load or vibration), and let an optimizer (SIMP, genetic algorithm, neural network, shape cutters)
or an AI assistant propose a better design. Then check it with the solver.

**Author and developer: Dr. Osman Sayginer.**

**Student guide (no installation, runs no simulation, explains and animates):** <https://InverseDesignToolbox.sayginer.com>

## Start here

1. Install MATLAB R2023b or newer with the **Partial Differential Equation Toolbox** (more toolboxes are only needed for some optimizers, see section 2).
2. Download or clone this repository. Nothing to install: every script adds its own paths.
3. Open **`SIM_StaticLoad.m`** (a cantilever beam under a load) or `SIM_HarmonicMotion.m` (vibration) and run it step by step with **Ctrl+Enter**.
   Every step shows a figure to check. Details in section 3.
4. When the plain simulation looks right, try an optimizer: `CASE_SIMP_StaticBeam.m`, `CASE_GA_StaticBeam.m`, `CASE_NN_StaticBeam.m`, `CASE_GA_Shape_StaticBeam.m`.
5. Teaching: `docs/00_course_guide.md`. Using an AI assistant: point it to `AGENTS.md`.

## How to cite

If you use this toolbox, its exercises or the guide in a report, thesis or paper, please cite it:

> Sayginer, O. (2026). *InverseDesignToolbox: a modular MATLAB toolbox for inverse design with finite elements* (Version 1.0.0) [Computer software]. Zenodo. https://doi.org/10.5281/zenodo.23523181

```bibtex
@software{sayginer_inversedesigntoolbox_2026,
  author    = {Sayginer, Osman},
  title     = {{InverseDesignToolbox}: a modular {MATLAB} toolbox for inverse design with finite elements},
  year      = {2026},
  version   = {1.0.0},
  doi       = {10.5281/zenodo.23523181},
  url       = {https://doi.org/10.5281/zenodo.23523181},
  publisher = {Zenodo},
  note      = {Computer software}
}
```

GitHub's **Cite this repository** button (from `CITATION.cff`) gives the same reference in APA and BibTeX. Please also say which
toolbox version and which MATLAB release you used. The DOI above always leads to the project record on Zenodo.

## What is inside

* **Two physics:** static load (deflection, stress, compliance) and vibration (natural frequencies, harmonic response, transmissibility).
* **Four design tools, the same for both:** SIMP topology optimization, a genetic algorithm, a neural-network surrogate, and holes/rectangles (shape cutters).
  All give printable layouts and end with a checked STL file (`docs/05_printability.md`, `docs/06_stl_export.md`).
* **Teaching material:** the course guide, two exercises (`EXERCISE_SurrogateData.m`, `EXERCISE_AIDesigner.m`) and the interactive guide.
* **Documentation:** one page per module in `docs/` (static: `docs/10_static_load.md`, `docs/11_static_optimization.md`).
* Not built yet: shape parameters of the outline itself, and a network that proposes designs directly.

---
## 1. The idea: "lego bricks"

Four kinds of building block. A runner script snaps a few of them together and does nothing else.

```
  PARAMETERS P       SIMULATION               OPTIMIZER                 RUNNER
  all in the         idt_build_model          (separate modules,        SIM_*.m   one physics, no optimization
  SIM_*.m script --> idt_analyze          --> one folder each)      --> CASE_*.m  one case study =
  (saved to          = the physics            topology, shape, NN       saved parameters + simulation
  results/*.mat)     (harmonic motion today)  (later steps)             + optimizer + figures
```

* **Simulation without optimization comes first.** `SIM_HarmonicMotion.m` holds ALL simulation parameters
  in its first section, builds the model, lets you pick a design and simulates it. Nothing else is needed
  to use the toolbox.
* **Test first, then optimize with the same parameters.** When the simulation looks right, the script saves
  its parameters to `results/<ProblemName>.mat`. A case study loads them with
  `P = idt_load_params('<ProblemName>')`, so the optimizer runs on exactly the problem you tested.
* **Optimizers are separate and swappable.** An optimizer is a set of plain functions that only call
  `idt_build_model` and `idt_analyze`. Anyone can write another one and compare it on the same problem.
  Optimizers never edit the core.
* **One runner file per case study.** Each `CASE_*.m` is a few lines: load the parameters, choose an
  optimizer, set its parameters, plot. To try another optimizer you change one line.
* **The design representation belongs to the optimizer module, not to the core.** The topology module
  describes a design as a vector `X` of bricks (1 = present, 0 = removed). The shape module describes it
  with cutter parameters (holes and rectangles subtracted from the part). The core does not care which.
* **The physics is replaceable.** `idt_analyze` dispatches on `P.Analysis.Type`. Today it is
  `'ModalHarmonic'` (eigenfrequencies + forced vibration) or `'Static'` (deflection and stress under a constant load). A thermal analysis is one more
  function file plus one more `SIM_*.m` script (see `docs/99_extending.md`).

**Interactive student guide:** <https://InverseDesignToolbox.sayginer.com>. It explains the toolbox at three levels (beginner, intermediate, advanced), helps choose which script to run, and animates the ideas. It runs no simulation. The numbers and layouts shown as real results come from runs of the case studies for the cantilever beam; update the page if you change them.

**For teaching:** `docs/00_course_guide.md` (lab sequence, exercises, rubric); exercises `EXERCISE_SurrogateData.m` (how much data does a neural network need?) and `EXERCISE_AIDesigner.m` (an AI assistant proposes a design, the solver scores it).

**Working with an AI assistant?** Point it to `AGENTS.md`: it explains the workflow, units, face numbers and checks the toolbox expects.

## 2. Requirements

**MATLAB** R2023b or newer. The toolbox was developed and tested only on **R2026a (Windows)**. R2023b is the oldest release that has
`trainnet` and `checkGradients`, which the neural-network and SIMP modules use.

**Required MATLAB toolboxes** (checked with `matlab.codetools.requiredFilesAndProducts` over every file; nothing else is needed):

| Toolbox | Needed for | Used by |
|---|---|---|
| **Partial Differential Equation Toolbox** | STEP import, CAD boolean cuts, tetrahedral meshing | everything (model setup, all scripts) |
| **Image Processing Toolbox** | printability clean-up of brick layouts (`imclose`, `imopen`, connected pieces) and the minimum-wall check of cutters | `CASE_SIMP_`, `CASE_NN_`, `CASE_GA_`, `CASE_GA_Shape_`, `SIM_ShapeCutters.m` (wall check) |
| **Optimization Toolbox** | `fmincon` with adjoint gradients, `checkGradients` | SIMP (`CASE_SIMP_TargetFrequency.m`) |
| **Global Optimization Toolbox** | `ga` genetic algorithm | `CASE_GA_`, `CASE_NN_` (search on the surrogate), `CASE_GA_Shape_` |
| **Deep Learning Toolbox** | `trainnet`, 3-D convolutional network | neural network (`CASE_NN_TargetFrequency.m`) |
| **Parallel Computing Toolbox** | `parfor` / parallel `ga`: evaluates designs on all CPU cores | **optional**: speeds up neural network, GA, shape optimizer and polish by about the number of cores; without it they run serially |

Which toolboxes you need for what:

| You want to run | Toolboxes |
|---|---|
| `SIM_HarmonicMotion.m` or `SIM_StaticLoad.m` (simulation only) | PDE Toolbox |
| `SIM_ShapeCutters.m` | PDE Toolbox, Image Processing Toolbox |
| SIMP topology optimization | PDE, Image Processing, Optimization |
| `CASE_SIMP_StaticBeam.m` | PDE Toolbox (Image Processing only if `S.Clean` is set) |
| `CASE_GA_StaticBeam.m` | PDE, Global Optimization (Image Processing only if `S.Clean` is set) |
| `CASE_NN_StaticBeam.m` | PDE, Global Optimization, Deep Learning |
| `CASE_GA_Shape_StaticBeam.m` | PDE, Image Processing, Global Optimization |
| Genetic algorithm (bricks or shape) | PDE, Image Processing, Global Optimization |
| Neural-network optimizer | PDE, Image Processing, Global Optimization, Deep Learning |

Check what you have with `ver` in the MATLAB command window. No installation: put the folder anywhere, run a script. Every script adds its own paths.
## 3. Quick start

Open `SIM_HarmonicMotion.m` and work through its numbered steps in order. Run one step at a time with
**Ctrl+Enter** (or the whole script with F5). Every step has its own parameters at its top, a comment saying
what to check, and a figure that pops up before you go on:

| Step | What happens | What to check in the figure |
|---|---|---|
| 1 | import the CAD files | all parts imported; the **face numbers** you need for the supports |
| 2 | brick the design domain | bricks cover the part you want to redesign |
| 3 | choose the bricks to keep | brick selection preview: kept bricks as clean blue boxes, removed ones as a faint ghost |
| 4 | boundary conditions | supports (red), load arrow (magenta), numbered outputs (green) |
| 5 | mesh | elements clearly smaller than a brick |
| 6 | build the model | printed numbers and warnings (bricks too small for the mesh) |
| 7 | apply the selection | the meshed design (removed bricks gone; edges follow the mesh) |
| 8-9 | simulate and plot | natural frequencies, response curves, mode shapes, transmissibility |
| 10 | save the parameters | `results/<ProblemName>.mat`, for the optimizers |

**Your own geometry:** copy your STEP files into `cad/`, list them in step 1 (`P.Geometry.Files`) with their
materials, run step 1, read the face numbers in the figure (or the printed table), then continue with the next
steps. Change `ProblemName` so you do not overwrite the saved example.

## 4. Folder map

```
InverseDesignToolbox/
  SIM_HarmonicMotion.m     simulation script: ALL parameters -> model -> design -> eigen + harmonic analysis -> figures
  CASE_SIMP_TargetFrequency.m   case study: saved parameters + SIMP optimizer -> figures
  CASE_NN_TargetFrequency.m     case study: saved parameters + neural-network surrogate optimizer -> figures
  CASE_GA_TargetFrequency.m     case study: saved parameters + genetic algorithm (real FEA, in parallel) -> figures
  SIM_StaticLoad.m         simulation script: cantilever beam under a constant load -> deflection and von Mises stress
  CASE_SIMP_StaticBeam.m   case study: static cantilever, SIMP minimum compliance -> figures
  CASE_GA_StaticBeam.m     case study: static cantilever, genetic algorithm (min compliance or min mass) -> figures
  CASE_NN_StaticBeam.m     case study: static cantilever, neural-network surrogate optimizer -> figures
  CASE_GA_Shape_StaticBeam.m  case study: static cantilever, holes and rectangles placed by a genetic algorithm, exact CAD check, STL
  EXERCISE_SurrogateData.m exercise: neural-network error against the amount of training data, cost of data
  EXERCISE_AIDesigner.m    exercise: an AI assistant proposes a brick design, the solver scores it, compare with the optimizers
  SIM_ShapeCutters.m       simulation script: place holes and rectangles by hand, look, simulate, exact check, STL
  CASE_GA_Shape_TargetFrequency.m  case study: genetic algorithm places the cutters -> exact CAD check -> smooth STL
  CASE_GA_Isolator.m       ISOLATOR case study: brick layout that blocks a frequency band (minimum peak transmissibility)
  CASE_GA_Shape_Isolator.m ISOLATOR case study: holes and rectangles that block a frequency band, exact CAD check, STL
  cad/                     your STEP files (3 examples included)
  results/                 saved parameter files (<ProblemName>.mat) and optimizer results
  optimizers/
    topology/              SIMP: simp_options, simp_precompute, simp_optimize, simp_postprocess, plot helpers
    neural/                neural network: nn_options, nn_make_dataset, nn_train, nn_predict, nn_optimize,
                           nn_validity_setup / nn_is_valid, nn_encode, nn_brick_volumes, nn_plot_surrogate
    genetic/               genetic algorithm: genetic_options, genetic_optimize, genetic_plot_history
    shape/                 cutter (shape) optimizer: shape_options, shape_optimize
    static/                static load: static_options, static_simp_optimize, static_ga_optimize, static_nn_optimize, static_plot_history
  docs/
    01_model_setup.md      every parameter explained
    02_analysis.md         the physics, the outputs, how to read the figures
    03_simp.md             SIMP: method, options, outputs, pitfalls, verified results
    04_neural_network.md   neural-network surrogate optimizer: method, options, measured results, pitfalls
    05_printability.md     clean-up (no checkerboards, islands, thin features) and polish, used by both optimizers
    06_stl_export.md       the manufacturable shape: preview and STL file (idt_export_stl), checks, when it fails
    07_genetic_algorithm.md  genetic algorithm: method, options, measured comparison of all three optimizers
    10_static_load.md      static analysis: the cantilever example, parameters, results, pitfalls
    00_course_guide.md     for instructors: lab sequence, graded exercises, rubric, how to use AI assistants
    11_static_optimization.md  static SIMP, GA, neural network, shape cutters: method, options, measured results
    09_isolator.md         the isolator goal: transmissibility in a band, options, what to set, measured results
    08_shape_cutters.md    shape module: cutters (holes, rectangles), fast and exact analysis, GA, STL, measured results
    99_extending.md        how to add an analysis type or an optimizer module
  functions/
    model/                 idt_import_geometry, idt_make_bricks, idt_select_bricks, idt_make_bc, idt_make_mesh,
                           idt_assemble_model, idt_build_model (all stages in one call), idt_save_params,
                           idt_load_params, idt_prepare_params, idt_default_params, idt_root, idt_fill_defaults
    analysis/              idt_analyze (dispatcher), analysis_modal_harmonic, analysis_static, idt_isolation_options / idt_isolation_metric (isolator goal)
    design/                idt_clean_setup, idt_clean_bricks (printable layouts), idt_polish_bricks (close the gap to the goal),
                           idt_export_stl, idt_stl_check (preview + closed-surface check of an STL)
    shape/                 idt_cutter, idt_shape_options, idt_shape_setup, idt_cutters_from_vector / _filter / _inside / _mask,
                           idt_cutters_geometry (exact CAD cut), idt_cutters_verify (new mesh + analysis), idt_cutters_export_stl
    model/analysis checks: idt_validate_params (before solving), idt_sanity_checks (after solving); design/: idt_export_dataset (CSV for machine learning)
    plotting/              idt_plot_model, idt_plot_analysis, idt_plot_static, idt_plot_brick_selection, idt_plot_cutters, idt_plot_isolation
  core/                    the finite-element engine (see section 6)
```

Naming rule: functions the user calls start with `idt_`; analysis types are `analysis_<type>`.

## 5. The functions everything is built on

The model is five stages. The simulation script calls them one by one (with a figure after each);
`idt_build_model(P)` runs all five in one call for optimizers.

| Stage | Function | Look at it with |
|---|---|---|
| A. import | `geom = idt_import_geometry(P)` | `plot_geometry(geom)` |
| B. design domain | `bricks = idt_make_bricks(P, geom)` | `plot_bricks(geom, bricks)` |
| C. boundary conditions | `bc = idt_make_bc(P)` | `plot_bc(geom, bc)` |
| D. mesh | `mesh = idt_make_mesh(P, geom)` | `plot_mesh(mesh)` |
| E. model | `model = idt_assemble_model(P, geom, bricks, bc, mesh)` | (numbers printed) |

```matlab
model       = idt_build_model(P);          % P = parameter struct (from SIM_*.m, or idt_load_params)
[res, met]  = idt_analyze(model, X);       % X = design vector (omit it for "everything present")
```

* **No figures inside any compute function.** Figures live only in `functions/plotting/` and in the
  `SIM_*.m` / `CASE_*.m` scripts. That is why an optimizer can call `idt_analyze` thousands of times quietly.
* `model` is built **once**: meshing and element matrices are the slow part (about 7 s here).
  `idt_analyze` is then fast (about 1 s per design on the example).
* `res` holds the raw numbers (mode shapes, curves). `met` holds the reduced metrics optimizers use.

## 6. The engine in `core/`

The files in `core/` come from the earlier `topopt_fem` work and are the validated solver:

| Task | Files |
|---|---|
| Geometry | `import_geometry`, `plot_geometry`, `list_faces` |
| Bricks | `brick_grid_from_density`, `create_bricks`, `check_brickization`, `plot_bricks`, `select_bricks`, `brick_matrix` |
| Boundary conditions | `define_bc`, `plot_bc` |
| Mesh | `generate_mesh`, `plot_mesh` |
| Model and solver | `build_model`, `solve_frf`, `solve_static`, `transmissibility`, `tet_element_matrices`, `boundary_faces` |
| Results | `plot_design`, `plot_results`, `plot_transmissibility`, `export_geometry` |
| Materials | `get_material_properties` |

The natural frequencies agree with MATLAB's own `structuralModal` solver to four decimals on the
same mesh (TET4 and TET10). The forced-response part is not cross-checked against another solver.

Students normally only use the `idt_*` functions. The engine is there to be read.

## 7. Verified in Step 1

| Test | Result |
|---|---|
| Example assembly, all bricks present, TET4 2 mm | f1 = 302.1 Hz, f2 = 619.8 Hz, mass 23.84 g (same as the earlier toolbox) |
| `P.Design.Type = 'none'` (no bricks), TET10 3 mm | builds and analyses; f1 = 257.3 Hz; plots work with an empty design vector |
| `SIM_HarmonicMotion.m` with all bricks, and with a "cross" design (42 of 402 bricks) | runs end to end headless; the cross gives f1 = 175.4 Hz with the FRF peak at 176 Hz; figures: geometry, bricks, BC, mesh, design, FRF, modes, transmissibility |

## 8. Roadmap

| Step | Module | What it will contain |
|---|---|---|
| 1 | core + simulation (done) | model setup, harmonic-motion simulation script with all parameters, save / load of parameters, docs |
| 2a | topology: SIMP (done) | brick densities, `fmincon` with adjoint gradient, goals 'TargetF1' / 'MaximizeF1', `CASE_SIMP_TargetFrequency.m` |
| 2b | topology: GA (done) | genetic algorithm on the bricks with the real FEA, parallel, printable by construction, `CASE_GA_TargetFrequency.m` |
| 2c | neural network (done) | CNN surrogate trained on FEA data, `ga` on the surrogate, verification and calibration rounds, `CASE_NN_TargetFrequency.m` |
| 3a | shape: cutters (done) | holes and rectangles subtracted from the design part, placed by a GA, exact CAD check, smooth STL, `CASE_GA_Shape_TargetFrequency.m` |
| 3b | shape: outline parameters | parameters for the outline of the imported geometry itself (not bricks), neural-network surrogate for the shape parameters |
| 3c | isolator goal (done) | `'MinTransmissibility'`: the smallest peak transmissibility in a frequency band, for the brick GA and the shape GA, `CASE_GA_Isolator.m`, `CASE_GA_Shape_Isolator.m` |
| 4 | neural network, next level | a network that proposes a layout directly for a given target (inverse design) |
| 5a | static loading (done) | `'Static'`: deflection, stress, compliance; `SIM_StaticLoad.m` |
| 5b | static optimizers (done) | SIMP, GA, neural network and shape cutters for the static beam: `CASE_SIMP_StaticBeam.m`, `CASE_GA_StaticBeam.m`, `CASE_NN_StaticBeam.m`, `CASE_GA_Shape_StaticBeam.m` |
| later | more physics (postponed) | thermal conduction: a new `analysis_<type>` file and a new `SIM_*.m` script |

Each step is agreed before it is built.

## 9. Limitations to know about

* Linear analysis only; modal damping; one harmonic or one static load case.
* Brick membership is decided by element centroids, so removed regions follow the mesh to about one
  element size. Use elements clearly finer than a brick.
* Thin structures need fine meshes; check mesh convergence of the quantity you care about.
* TET4 is about 18 % too stiff in frequency at practical sizes; use TET10 (`P.Mesh.Order = 'quadratic'`)
  for accuracy and TET4 for fast optimizer runs.
* STEP files cannot be written from MATLAB; `export_geometry` writes STL.
* Shape module: cutters only subtract material, only the design part is cut, and the fast analysis removes whole mesh elements,
  so the exact CAD cut differs by a few percent in f1 (measured 0.5 % to 2.7 %). The minimum wall (`MinWall`) is checked on a 0.25 mm top-view raster.

## 10. Author, credits and how to cite

* **Author and developer:** Dr. Osman Sayginer. All modules (model setup, simulation, SIMP, neural-network, genetic-algorithm and shape optimizers, printability and STL export) and all documentation in this folder.
* **Every source file** (`.m`) carries the line `Author: Dr. Osman Sayginer (InverseDesignToolbox)` at the end of its header comment, and every page in `docs/` names the author at its end.
* **Built on MATLAB toolboxes:** Partial Differential Equation Toolbox, Optimization Toolbox, Global Optimization Toolbox, Deep Learning Toolbox, Parallel Computing Toolbox, Image Processing Toolbox (MathWorks). The finite-element engine in `core/` comes from the author's earlier `topopt_fem` work.
* **How to cite:** Sayginer, O. *InverseDesignToolbox: a modular MATLAB toolbox for inverse design with finite elements*, 2026, DOI 10.5281/zenodo.23523181. The machine-readable form is `CITATION.cff` (GitHub shows a "Cite this repository" button for it); the guide has a Cite page with a BibTeX entry (see also "How to cite" at the top). Steps for new releases and to grow citations: `docs/12_citation_and_release.md`.
* **License:** MIT, see the file `LICENSE` (Copyright (c) 2026 Dr. Osman Sayginer). It covers the code, documentation and example CAD files in this folder. MATLAB and its toolboxes are MathWorks products with their own license; users need their own copies.


