# 10 - Static load (cantilever beam)

`SIM_StaticLoad.m` is the static counterpart of `SIM_HarmonicMotion.m`. It has the same ten steps
(import, bricks, selection, boundary conditions, mesh, model, apply, solve, plot, save). Only the
loading and the results differ. Nothing is optimized.

## The example

| File | Part | Size | Material |
|---|---|---|---|
| `cad/02StaticBeamDesignFrame.STEP` | design frame (the part that can be redesigned) | 140 x 10 x 40 mm | Aluminum-6061 |
| `cad/01StaticBeamFixedFrame.STEP` | outer frame with a 140 x 40 mm window | 150 x 50 x 10 mm | Structural-Steel |

The design frame sits in the window of the fixed frame, so the assembly is one 150 x 50 x 10 mm block.
Its left end (face 5) is clamped and the right end (face 3) is loaded: a cantilever beam. The top
and bottom bars of the outer frame are the flanges, the design frame is the web that carries shear.
The SolidWorks originals (`.SLDPRT`) are in the folder above the toolbox.

Face numbers of the assembly (step 1 prints them): `3` = right end (x = +75 mm), `5` = left end
(x = -75 mm), `4` / `6` = bottom / top bar, `1` / `2` = back / front.

## Parameters that differ from the harmonic example

| Parameter | Meaning |
|---|---|
| `P.Analysis.Type = 'Static'` | selects `analysis_static` in `idt_analyze`. There are no further analysis parameters. |
| `P.BC.FixedFaces` | clamped faces (u = v = w = 0) |
| `P.BC.LoadFaces` | face IDs over which the force is spread equally (new). `[]` = point load at `P.BC.LoadPoint`. A point load is a singularity: the local stress grows without limit as the mesh is refined. Prefer a face. |
| `P.BC.LoadDirection`, `P.BC.LoadAmplitude` | direction and **total force in N** (a constant force, not an amplitude) |
| `P.BC.OutPoints` | points whose displacement is reported; output 1 is used for the stiffness |
| `P.BC.ExtraMass` | 0 here (a lumped mass has no effect on a static solution, only on the mass printed) |
| `P.Mesh.Order` | `'quadratic'` (TET10) is the default of this script because bending needs it; `'linear'` is faster for optimizers |

The brick parameters are the ones of the harmonic example. Here `P.Design.Layers = [0 1 0]` gives one
layer through the 10 mm thickness and 21 x 6 bricks of 6.7 mm in the x-z plane.

## What is computed

`core/solve_static.m` assembles the same stiffness matrix as the harmonic solver, clamps the fixed
nodes and solves `K u = F`. Removed bricks delete their elements; pieces no longer connected to the
support are dropped (reported as floating elements). Stress is the isotropic linear-elastic stress at
each element centroid, reduced to the von Mises stress.

| Result (`met`) | Meaning |
|---|---|
| `MaxDisp` | largest displacement magnitude (m) |
| `OutDefl` | displacement (x, y, z) at each output point (m) |
| `Stiffness` | load / displacement of output 1 along the load direction (N/m) |
| `Compliance` | `F'u` (J), force times the movement it causes (twice the strain energy; the guide shows it in mJ, millijoules). Smaller is stiffer. This is what a topology optimizer minimizes. |
| `MaxVonMises` | largest element stress (Pa). Indicator only: it is dominated by the clamp edge and load face. |
| `Mass`, `VolFrac`, `Dropped` | as in the harmonic analysis |
| `res.Reaction` | sum of the support forces; must equal minus the load (printed as a check) |

`idt_plot_static(model, X, res)` shows the deformed shape (colored by displacement) and the von Mises
stress. `'Scale'` sets the magnification of the deformation (default: the largest displacement is
shown as 8 % of the model size). The stress colors are clipped at the 99th percentile so single hot
spots do not hide the rest.

## Measured (R2026a, Hmax 2 mm, 500 N)

| Case | Tip deflection | Mass | Peak stress |
|---|---|---|---|
| all 126 bricks, TET10 | 45.7 um | 298.8 g | 30.7 MPa |
| all 126 bricks, TET4 | 45.4 um | 298.7 g | 29.9 MPa |
| 36 bricks removed (window 80 x 20 mm), TET4 | 97.8 um | 255.9 g | 46.3 MPa |

Hand check (Euler-Bernoulli bending of the composite section plus web shear): about 41 um + 9 um
= 50 um; the finite-element value is lower because the clamped end and the end bars are stiffer than
the beam model assumes. The support reactions equal the load to 1e-9 N.

## Invalid designs

`met.Valid` is false if the load or an output point is cut off from the supports, or if the bricks touch only along an edge or corner. The latter is a mechanism:
the stiffness matrix is singular (`res.Mechanism = true`). `idt_sanity_checks(model, res, met)` after the solve prints the checks to read (reaction = load, no floating
pieces, mesh finer than the bricks).

## Pitfalls

* The clamp and the load face are rigid in this model, so the peak stress there is higher than in
  reality and depends on the mesh. Read stress away from them.
* Linear analysis only: displacements are small, the material stays elastic, no contact.
* With a stiff outer frame the web bricks change the deflection moderately. To make the design part
  matter more, give it the stiffer material or a thinner flange.

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
