# 06 - The manufacturable shape: preview and STL

```matlab
info = idt_export_stl(model, X, 'my_design');      % writes results/my_design.stl and shows the preview
```

`X` is the final layout of an optimizer (`post.X` from SIMP, `out.X` from the neural network). Both case studies call this as
their last step and write `results/simp_design_<ProblemName>.stl` or `results/nn_design_<ProblemName>.stl`.

## What is in the file

By default (`opt.Content = 'cad'`) the STL is the **whole imported assembly** (holder, design frame, fixed frame) with
every removed brick cut out as a box-shaped pocket (`export_geometry`). That is one exact solid: round holes stay round,
flat faces are a few large triangles (typically 1500 to 2000 triangles in total), and the design bricks that were kept
are fused with the holder and the frame. This is the part you slice and print.
`opt.Content = 'bricks'` writes only the kept design bricks as merged boxes.

Units are mm (`opt.Units = 'm'` for meters; STL itself has no units, so set the same unit in the slicer).

## The preview shows what was saved

The function reads the STL file back and draws that, not the model: an isometric view and a top view, flat shaded with the
sharp edges outlined. The title of the top view says whether the check passed. The check, also returned in `info`:

| Field | Meaning |
|---|---|
| `Watertight` | every edge belongs to exactly two triangles: a closed surface, which slicers need |
| `Shells` | number of separate solid pieces (1 = one connected part) |
| `Volume`, `BBox`, `NumTriangles` | enclosed volume (mm^3), bounding box, triangle count |
| `Content` | what was really exported |

Compare `Volume` with the model: the example gave 8690 mm^3 in the file and 8769 mm^3 for the kept elements of the analysis
mesh (0.9 % apart; the mesh cuts bricks by element centroids, the CAD cut by exact boxes).

## Options

`opt` = `struct('Content', 'cad' | 'bricks', 'Units', 'mm' | 'm', 'Preview', true | false, 'SaveSelection', false | true)`.
`SaveSelection = true` also writes the brick table (`_bricks.csv`) and the selection (`_selection.mat`) next to the STL.

## How the cut is made robust

The CAD cut subtracts the removed bricks (merged into box-shaped pockets, 20 to 30 boxes) one after the other from the imported
assembly. MATLAB's boolean is sensitive to the ORDER of the cuts: for one neural-network layout the original order failed at
box 14 and all cuts after it, the reversed order failed once, and a shuffled order cut everything. `export_geometry` therefore tries
the original order, the reversed one and up to 15 shuffled ones (fixed seed, reproducible) and stops at the first order that works.
That is why an export can take 5 to 25 seconds. Only if no order works does it fall back to the faceted mesh skin.

## When it fails

* **"CAD boolean failed", fallback to the faceted skin.** No cut order worked. The usual cause is a shape the CAD kernel cannot
  represent because two solid regions touch only along an edge or at a corner. `idt_clean_bricks` removes these (step 5, `05_printability.md`).
  Layouts that were not cleaned (SIMP or NN with `H.Clean = []`) can fail. The warning says so and the STL is then the analysis-mesh
  skin, not the exact CAD shape.
* **"NOT watertight".** Same cause; clean the layout and export again.
* The STL has no material information. Materials are in the parameters (`P.Geometry.Materials`); a multi-material print needs the
  parts exported separately.
* The outline is made of whole bricks (steps of about 3 mm in the plane, one layer in z). Smoothing it is not done.
* STEP cannot be written from MATLAB.

## Same check for cutter designs

The read-back, closed-surface check and preview live in `idt_stl_check(stl, units, preview)`. `idt_export_stl` (brick layouts) and `idt_cutters_export_stl` (shape designs with holes and rectangles, `docs/08_shape_cutters.md`) both use it, so the preview and the `info` fields are identical.

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
