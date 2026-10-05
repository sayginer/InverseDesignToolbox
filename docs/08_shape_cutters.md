# 08 - Shape optimization with cutters (holes and rectangles)

The topology modules (SIMP, neural network, GA on bricks) decide which bricks of a grid exist. The **shape module** works on the
real geometry instead: the design is a fixed number of **holes and rectangles that are subtracted from the design part**. The
optimizer searches their positions, sizes and angles. The result is smooth (round holes stay round, no brick staircase) and the STL
is an exact CAD cut.

Files: `functions/shape/` (shared tools), `optimizers/shape/` (GA), `SIM_ShapeCutters.m` (by hand, no optimization),
`CASE_GA_Shape_TargetFrequency.m` (optimizer).

```matlab
model       = idt_build_model(P);                     % P.Design.Type = 'none': no bricks
[smodel, S] = idt_shape_setup(model, C);              % cutter design space, fast analysis model
out         = shape_optimize(smodel, S, H);           % GA places the cutters
geom2       = idt_cutters_geometry(model, out.cut);   % exact CAD cut
[vmodel, vres, vmet] = idt_cutters_verify(model, geom2);   % new mesh + analysis of the exact shape
idt_cutters_export_stl(geom2, 'my_shape');            % closed STL, preview
```

## 1. What a cutter is

A cutter goes through the **full thickness** of the design part (like a laser or CNC cut). Two kinds:

| Kind | Numbers | Make it by hand |
|---|---|---|
| hole | x, y, radius | `idt_cutter('hole', x, y, radius)` |
| rectangle | x, y, width, height, angle | `idt_cutter('rect', x, y, width, height, angleDeg)` |

All lengths in meters, angles in degrees (counter-clockwise from +z). Several cutters are a list:
`cut = [idt_cutter(...), idt_cutter(...)]`. Cutters may overlap each other and may stick out of the part (only the part is cut).
Only the design part (`P.Design.Part`) is cut; other parts, such as the holder and the fixed frame, are never touched.

## 2. The design space `C` (`idt_shape_options.m`)

| Option | Default | Meaning |
|---|---|---|
| `NumHoles`, `NumRects` | 3, 2 | how many cutters the optimizer has. The number is fixed; a cutter that is too small is switched off, so a design can use fewer |
| `Region` | bounding box of the part | `[xmin xmax ymin ymax]` where cutter centers may lie |
| `HoleRadius` | `[Hmax, 15 % of the part size]` | `[rmin rmax]`: the radius variable runs from 0 to `rmax`; a hole smaller than `rmin` is **off** |
| `RectSize` | `[2 Hmax, 50 % of the part size]` | `[smin smax]`: same rule for width and height |
| `AllowRotation` | true | false = rectangles stay axis-aligned |
| `MinWall` | 2 mm | thinnest wall the cutters may leave, between two cutters or a cutter and a free edge. 0 = no rule. See section 4 |
| `Margin` | `Hmax` | a cutter closer than this to a support, the load point or an output point is switched **off** (those places stay solid) |

The minimum sizes default to a few mesh elements. The fast analysis removes whole mesh elements, so a smaller cutter would be
rounded to the mesh and the analysis would be unreliable. For a smaller feature use a finer mesh (`P.Mesh.Hmax`).

The optimizer's unknown is one number vector `p` of `S.NumParams` entries: `[hole 1: x y r | ... | rect 1: x y w h angle | ...]`
(`S.Names` lists them, `S.LB`/`S.UB` are the bounds). `idt_cutters_from_vector(S, p)` turns it into the cutter list.

Helper functions in `functions/shape/`: `idt_cutters_inside` (which points lie in a cutter: the single definition of what a cutter removes), `idt_cutters_filter` (drops cutters that touch supports, load or outputs), `idt_cutters_mask` (element mask for the fast analysis), `idt_cutters_wall` / `idt_cutters_repair_walls` (minimum wall), `idt_cutters_geometry` / `idt_cutters_verify` / `idt_cutters_export_stl` (exact CAD cut, re-meshed check, STL).

## 3. Two analyses of the same design

**Fast (used by the optimizer and by step 4 of `SIM_ShapeCutters.m`).** The mesh is built once. A mesh element of the design part
whose centroid lies inside a cutter is removed (`idt_cutters_mask`), exactly like a removed brick; then `idt_analyze` runs the usual
eigenfrequency + harmonic analysis. No re-meshing, about 1 s per design (parallel on all workers). Elements that touch a support, the
load point or an output are never removed. The cutter edge follows the mesh to about one element size.

**Exact (the check at the end).** `idt_cutters_geometry` subtracts real cylinders and boxes from the CAD part (`subtract`, PDE
Toolbox) and fuses the parts again. `idt_cutters_verify` meshes that geometry (the mesh follows the true hole and rectangle edges) and
analyses it with the same parameters. The support faces are found again by their position, because face numbers change when the
CAD is cut. This takes about 6 s. The same geometry is what the STL contains.

Why both: the fast analysis makes thousands of evaluations affordable; the exact one tells you how far to trust the result.

## 4. Minimum wall (printability)

`idt_cutters_wall(S, cut)` checks the top view on a 0.25 mm raster. The solid area is the material of all parts minus the cutters
(a cutter removes only the design part). A morphological opening with a disk of diameter `MinWall` (Image Processing Toolbox)
keeps every wall at least that thick; what it removes is a too-thin wall or a too-small island. It is reported (`ok`, `info.Area`),
drawn red in `idt_plot_cutters` and used by the optimizer. Three details that cost time to find:

* walls that already exist in the uncut part are ignored (`Thin0`);
* hairline gaps in the raster where parts touch (point-in-mesh tests miss points exactly on an interface) are closed;
* the opening rounds every convex corner of the solid, for example a holder corner that a cutter exposes. Blobs smaller than
  1.5 r^2 pixels (r = opening radius in pixels) are ignored, so corner rounding is not counted as a thin wall.

Tested directly: two holes leaving a wall of 0.5 mm and 1.5 mm are flagged, a wall of 2.0 mm passes, the uncut part passes.
The optimizer adds `10 x (thin area / design-part area)` to the cost, and after the search `idt_cutters_repair_walls` shrinks
all cutters by 3 % steps until no thin wall is left (it did nothing in the final run below). Repairing inside every evaluation was
tried and made the search worse (the repair is a rough, non-smooth step: 242 Hz instead of 200 Hz), so it is only used at the end.

## 5. The optimizer (`shape_optimize.m`, options in `shape_options.m`)

`ga` (Global Optimization Toolbox, real-valued variables with bounds) evolves a population of cutter vectors. Cost per design:
cutters from the vector, mask, real analysis, goal.

| `H.Objective` | Cost |
|---|---|
| `'TargetF1'` | `((f1 - TargetF1)/TargetF1)^2` |
| `'MaximizeF1'` | `-f1 / f1_uncut` plus a penalty if more than `H.VolMax` of the design part remains |

A design that cannot be analysed (the load or an output is cut off from the supports) costs 50. `H.VolMax` can also be given with
`'TargetF1'` as a limit on the remaining volume fraction. The population runs in parallel; the model goes to the workers once
(`parallel.pool.Constant`). Defaults: population 40, up to 40 generations, stop when `|f1 - target| < FreqTol` or the best cost
stalls for 10 generations.

## 6. Output

`out.p`, `out.cut` (the active cutters), `out.X` (element mask), `out.VolFrac` (fraction of the design part left), `out.met` and
`out.res` (analysis; `idt_plot_analysis(smodel, out.X, out.res, 'Design', false)`), `out.History` (`genetic_plot_history(out)`),
`out.NumEvaluations`, `out.TotalTime`.

Figures: `idt_plot_cutters(smodel, S, cut)` (exact outlines on the analysis mesh, top and 3-D), the usual analysis figures, and the
STL preview. `idt_cutters_export_stl` writes `results/<name>.stl` in mm and checks it: closed surface, number of solid pieces,
volume, size.

## 7. Measured (example assembly: design frame 40 x 40 x 5 mm, TET4 2 mm mesh, 6 workers)

| Test | Result |
|---|---|
| Part without cutters | f1 = 302.1 Hz, 23.84 g |
| 2 holes (r = 3.5 mm) + 2 rectangles placed by hand, `SIM_ShapeCutters.m` | fast f1 = 279.60 Hz, exact CAD cut f1 = 280.95 Hz (0.48 % difference); mass 22.61 g fast, 22.62 g exact; STL closed, 1 piece, 1684 triangles |
| `CASE_GA_Shape_TargetFrequency.m`, `TargetF1 = 200 Hz`, 3 holes + 2 rectangles, **without** the wall rule (first version) | 9 generations, 384 analyses, 95 s. Fast f1 = 200.02 Hz, 4 cutters. Exact CAD cut 194.60 Hz (2.7 % lower). Its cutters leave 7.9 mm^2 of wall thinner than 2 mm |
| same, **with** `MinWall = 2 mm` | 34 generations, 1334 analyses, 175 s. Fast f1 = 200.22 Hz, 2 holes + 2 rectangles, 64.4 % of the part left, 21.13 g, no wall thinner than 2 mm (no repair needed). **Exact CAD cut: 196.53 Hz (1.8 % lower)**. STL closed, 1 piece, 1572 triangles |

Reading the second row. The optimizer reached the target on the mesh it works on; on the re-meshed exact shape the same cutters
give 2.7 % less. The reason is the mesh: with 2 mm elements and cutters of 3 to 18 mm the removed region is only accurate to about one
element, and the optimizer finds the cutter positions that happen to fit that mesh best. The result is a very good design, but not
an exactly-at-target one. If the target must be met on the exact shape: use a finer mesh (`P.Mesh.Hmax`), or run the optimizer with a
target shifted by the measured difference (200 / 0.982 = 203.7 Hz here) and verify again.

## 8. Things to know

* **Only subtracting.** Cutters remove material; they cannot add any. Reaching a frequency above the uncut part is impossible. A
  target frequency below f1 of the uncut part is the natural goal. (`'MaximizeF1'` is meaningful only when the mass saved by the
  cutters matters more than the stiffness lost.)
* **Printability.** Walls are controlled by `MinWall`; cutter sizes are bounded below. Overhangs and the printer's tolerance are not modelled (cutters go straight through, so there are no overhangs in the cut itself).
* **Cutters at the part's border.** A cutter that reaches the interface to another part only removes the design part's
  material. In the preview it can look like a notch whose far side is filled by the neighbouring part. That is correct, and the
  exact CAD cut does the same.
* **Local optima, run-to-run differences.** `ga` is stochastic; `H.Seed` fixes the starting population only.
* **Moderate counts.** Five cutters are 19 numbers, which a GA of 40 individuals handles. Many more cutters need larger populations.
* **Neural network and SIMP.** They are not used on cutter designs here: SIMP needs a density field, and a surrogate for cutter
  numbers is a possible later step.

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
