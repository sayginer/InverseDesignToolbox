# 01 - Model setup: every parameter explained

All parameters live in one struct `P`. `SIM_HarmonicMotion.m` fills it step by step: each parameter sits in the
step it belongs to (geometry in step 1, bricks in step 2, boundary conditions in step 3, mesh in step 4,
analysis settings in step 5). `idt_build_model(P)` turns the finished `P` into a `model`. Any field you leave
out is filled from `functions/model/idt_default_params.m`.

**Units everywhere: meters, kilograms, newtons, seconds, Hz.** (Write `2e-3` for 2 mm.)

## Workflow: each step is checked before the next

The simulation script builds the model one stage at a time and draws each result **before any computation**.
Run a step, look at its figure, fix the parameters of that step if needed, run it again, then go on.

| Step | Function | Figure | Look for |
|---|---|---|---|
| 1. import | `idt_import_geometry` | "Imported parts" (one panel per part) and "Assembly faces" | all parts imported with the right size; in the assembly figure the **face numbers** of the surfaces you want to clamp |
| 2. design domain | `idt_make_bricks` | brick grid | the design domain is covered, bricks are a sensible size |
| 3. brick selection | `idt_select_bricks` | `idt_plot_brick_selection`: kept bricks as boxes, removed as a faint ghost | the layout you want to simulate, before any mesh exists |
| 4. boundary conditions | `idt_make_bc` | supports (red), load (magenta), outputs (green, numbered) | everything where you expect it |
| 5. mesh | `idt_make_mesh` | surface + cut-away | elements clearly smaller than a brick |
| 6. model | `idt_assemble_model` | none (numbers are printed) | the number of design variables, warnings about bricks too small for the mesh |
| 7. apply the selection | `select_bricks(model, 'Matrix', M)` | the meshed design (`plot_design`) | the cut edges follow the mesh |
| 8. simulation | `idt_analyze` | design, response curves, modes, transmissibility | see `02_analysis.md` |

`idt_build_model(P)` runs steps 1, 2, 4, 5 and 6 in one call (used by optimizers; they choose their own bricks).

### Brick selection (step 3)

`M = idt_select_bricks(bricks, ...)` works on the brick grid, so it needs no mesh and no model.
`M` has one entry per grid cell: 1 = present, 0 = removed, NaN = not a brick. Options (combinable):
`'KeepFcn'`, `'RemoveFcn'`, `'RemoveBox'`, `'RemoveIJK'` (rules on brick-center coordinates in meters, or grid
indices) and `'Matrix'`. You can also edit `M` by hand, e.g. `M(5:8, :, 1) = 0`, and print the layer maps with
`brick_matrix([], M)`. In step 7 the same `M` becomes the design vector `X`; bricks locked by supports, load or
output points always stay solid, so `X` can have a few entries fewer than `M` has bricks.

**Why the meshed design (step 7) looks jagged but the preview (step 3) does not:** bricks are only switches. The
analysis mesh is a free tetrahedral mesh of the real CAD geometry; removing a brick deletes the tetrahedra whose
centroid lies in it, so the cut follows the mesh to about one element size. Keep `Hmax` at most 0.7 x the brick edge
for a faithful result.

---

## 1. `P.Geometry`

| Field | Meaning |
|---|---|
| `Files` | cell array of CAD files (STEP, IGES, STL). Relative paths start in the toolbox folder, so `cad/part.STEP` works anywhere. Any number of parts. |
| `Names` | a label per file (used in figures and printouts) |
| `Materials` | one per file, same order. Either a library name (`'Aluminum-6061'`, `'Structural-Steel'`, `'PLA'`, ... see `core/get_material_properties.m`) or `struct('Name','X','E',70e9,'nu',0.33,'rho',2700)` |
| `Scale` | file units to meters. STEP is imported in meters already (`1`). For an STL drawn in mm use `1e-3`. A warning appears if a part is larger than 1 m. |

**Order matters.** The parts are fused into one assembly. If two parts overlap, the **first** one in
the list owns the overlap. The face numbers also depend on the order, so re-read them from the figure
if you reorder the files.

**Using your own geometry:** copy the STEP files into `cad/`, list them in `Files`, run
`SIM_HarmonicMotion`, read the face numbers in the geometry figure, set `FixedFaces`.

## 2. `P.Design`  (the design domain)

The design domain is the part an optimizer may change. `Type` selects how it is described.

| `Type` | Meaning |
|---|---|
| `'bricks'` | one part is cut into a grid of switchable bricks. A design is a vector `X`, 1 = present, 0 = removed. |
| `'none'` | no design domain; the geometry is analysed exactly as imported. `model.NumVars = 0`. |

(A parametric-shape representation will be added by the shape module in a later step.)

Fields for `'bricks'`:

| Field | Meaning |
|---|---|
| `Part` | index of the part that becomes the design domain |
| `MinPrintSize` | smallest printable feature [m]. A brick edge can never be smaller. |
| `Density` | 0 to 100. 100 = finest (edge = `MinPrintSize`). 0 = coarsest (edge = thinnest free dimension). |
| `Layers` | `[nx ny nz]` hard layer counts; 0 = automatic. `[0 0 3]` = exactly 3 layers in z (printing layers). The free axes share one edge that follows `Density`. |
| `MinFill` | a grid cell becomes a brick only if at least this fraction of it is design material (no thin slivers) |
| `MaxOverlap` | ... and it may overlap other parts by at most this fraction |

Cells that fail `MinFill` or `MaxOverlap` are **not bricks**: not drawn, not variables, their material stays solid.
Bricks that contain a support, the load point or an output point are **locked** (always solid).

## 3. `P.BC`  (boundary conditions)

| Field | Meaning |
|---|---|
| `FixedFaces` | assembly face numbers clamped in x, y and z |
| `LoadPoint` | `[x y z]` where the harmonic force acts (snapped to the nearest mesh node) |
| `LoadDirection` | direction vector (normalized internally) |
| `LoadAmplitude` | force amplitude [N] |
| `OutPoints` | n-by-3 list of response points. Output numbers equal the curve numbers in the plots. |
| `ExtraMass` | lumped mass [kg], e.g. a sensor. `0` = none. |
| `ExtraMassBox` | `[xmin xmax ymin ymax zmin zmax]` of the region the mass is spread over (`Inf` allowed) |

## 4. `P.Mesh`

| Field | Meaning |
|---|---|
| `Hmax` | target element size [m]. Keep it at most about 0.7 x the brick size, otherwise a brick may contain no element centroid and cannot be switched. The model builder warns about that. |
| `Order` | `'linear'` = TET4: fast, noticeably too stiff. `'quadratic'` = TET10: accurate, slower. |
| `Refine` | `{faceIDs, size, ...}` local refinement, e.g. `{[1 2 3 4], 1e-3}` |

The mesh follows the CAD surfaces (round holes stay round) and is independent of the bricks.

## 5. `P.Analysis`

| Field | Meaning |
|---|---|
| `Type` | `'ModalHarmonic'` (the only one so far) |
| `FreqStart`, `FreqEnd`, `FreqStep` | harmonic sweep [Hz]. A larger step is faster. |
| `Zeta` | modal damping ratio, 0.05 = 5 % |
| `NModes` | number of eigenmodes kept. Check `res.ModalCoverage` (highest kept mode / `FreqEnd`) is above about 1.5, otherwise raise `NModes` or lower `FreqEnd`. |
| `Transmissibility` | also compute base-excitation transmissibility (see `02_analysis.md`) |

## Saving and loading

The simulation script ends by saving `P` with `idt_save_params(P, ProblemName)` to `results/<ProblemName>.mat`.
Any other script gets the identical parameters with `P = idt_load_params(ProblemName)` and the identical model with
`model = idt_build_model(P)`, with no figure involved. You can change single fields of `P` in between (for example
a finer mesh for the final optimizer run). `idt_build_model` fills any field you leave out from
`functions/model/idt_default_params.m` and keeps the complete parameters in `model.Params`, so a result always
knows how it was made.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| "No nodes are fixed" or the wrong region clamped | Face numbers depend on file order. Read them again in the assembly figure. |
| Warning: bricks contain no element centroid | Mesh too coarse for the brick size. Lower `Hmax` or use bigger bricks (lower `Density`). |
| Warning about units on import | The part is larger than 1 m: the file is probably in mm. Use `Scale = 1e-3`. |
| `ModalCoverage` below 1.5 | Raise `NModes` or lower `FreqEnd`. |
| Frequencies change with the mesh | Thin parts or coarse mesh. Compare TET10 at two mesh sizes. |
| Error: minimum printable size larger than the thinnest dimension | Lower `MinPrintSize` or constrain fewer axes with `Layers`. |

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
