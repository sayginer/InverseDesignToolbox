# 05 - Printability: no checkerboards, no islands, no thin features

Optimizers do not care whether a design can be printed. Left alone they produce scattered bricks, bricks that touch
only along an edge or corner (checkerboards, which act as hinges), floating islands and one-brick-thin fragments.
Two shared functions in `functions/design/` fix that for every optimizer (SIMP and the neural network use them; so can
yours):

```matlab
C       = idt_clean_setup(model);                     % once per model
[Xc, r] = idt_clean_bricks(C, X, opt);                % make a layout printable
[Xp, h] = idt_polish_bricks(model, Xc, goal, C, opt, polishOpt);   % close the gap to the goal again, brick by brick
```

## 1. `idt_clean_bricks`: what it does

It works on the brick grid with Image Processing Toolbox operations. Grid cells that are not design bricks (the holder
and other permanent material) count as solid.

| Step | Operation | Effect |
|---|---|---|
| 1 | `imclose` with a square of `CloseGaps` bricks, layer by layer | fills one-brick gaps and holes |
| 2 | `imopen` with a square of `MinWidth` bricks, layer by layer | removes every feature narrower than `MinWidth` bricks |
| 3 | overhang rule (optional) | removes bricks with nothing solid below them |
| 4 | `bwconncomp` with **face** connectivity (6 neighbours) | bricks that touch only along an edge or corner are not connected: checkerboards and islands disappear. Only groups attached as `KeepOnly` says are kept |
| 5 | diagonal and corner repair | two solid bricks meeting only along an **edge** (a 2x2 checkerboard in any plane) or at a single **corner** (a 2x2x2 window whose solid or void part is not face-connected) make a non-manifold edge or vertex. Slicers reject such an STL and the CAD cut fails. One void cell of each diagonal pattern, or the void cells of each bad corner window, are filled. Steps 4 and 5 repeat until neither changes anything |

If cleaning would destroy the load path, the original layout is returned (`rep.Reverted`).

**Why step 5 exists.** Face connectivity of each group (step 4) does not forbid two solid regions touching each other along
an edge. A neural-network layout that passed steps 1 to 4 still exported as a non-watertight STL (3 diagonal patterns, 1 bad
corner window); after step 5 the CAD cut works and the STL is a closed single-piece solid. The cost is a few added bricks
(+4 here), which shifts f1 slightly (100.0 to 104.1 Hz), so run polish after cleaning. See `06_stl_export.md`.

Options (`opt`, all optional):

| Field | Default | Meaning |
|---|---|---|
| `MinWidth` | 2 | smallest feature width in bricks. 1 = no thin-feature removal. Set it from your printer: nozzle or minimum wall divided by the brick edge |
| `CloseGaps` | 2 | gaps up to this many bricks minus one are filled. 1 = off |
| `Overhang` | false | true: remove bricks without support below (print from the bottom layer up) |
| `KeepOnly` | `'loadpath'` | `'loadpath'` keeps only groups touching both the supports and the load side (no dead ends); `'attached'` keeps groups touching either; `'all'` only removes checkerboards and thin parts |

`rep` reports the bricks removed and added, the number of face-connected pieces before and after, and whether a
load path exists.

**Anchoring.** A brick counts as touching the supports (or the load side) if it shares at least 4 mesh nodes with that
permanent piece (`idt_clean_setup`, second argument). A face contact shares several nodes, an edge contact one or two.

## 2. `idt_polish_bricks`: why it is needed

Making a layout printable changes its frequency. The optimizer worked with a smooth or approximate model; cleaning
and whole bricks move f1 away from the goal (SIMP: 107.6 Hz before cleaning, 117.8 Hz after, target 100 Hz). Polish
closes that gap with the REAL analysis: it toggles every boundary brick (adds one next to a present brick, removes
one next to an absent brick), re-cleans each candidate, analyses all candidates in parallel, accepts the best one if it
improves the goal and repeats until nothing improves or `MaxSteps` is reached (`Tol`: stop when `TargetF1` is within
that many Hz). For `'MaximizeF1'` it increases f1 within `VolMax`. The result is a local optimum of single-brick changes.

## 3. How the optimizers use it

* **SIMP** (`simp_postprocess`): every threshold candidate is cleaned before it is analysed, then the winner is polished.
  Options `H.Clean`, `H.Polish` (set to `[]` to switch off).
* **Neural network** (`nn_make_dataset`, `nn_optimize`): the random training layouts are cleaned, every individual of the
  genetic algorithm is cleaned before the network judges it, the candidates are cleaned before verification, and the final
  answer is polished. The network therefore only ever sees printable layouts. Options `H.Clean`, `H.Polish`.

## 4. What it changed (example assembly, 402 bricks, TET4)

| | before | after |
|---|---|---|
| Random layouts that give a usable analysis (neural-network training data) | 79 % (the rest were hinges or cut off) | 97 % |
| Network accuracy on held-back layouts (R^2 of log f1) | 0.65 to 0.75 | 0.85 to 0.88 (mean error about 18 % instead of 33 %) |
| SIMP result, `TargetF1 = 100 Hz` | 36 bricks, 2 pieces, one arm a single brick wide in places, f1 = 107.6 Hz | 26 bricks, 2 pieces, all features at least 2 bricks wide, f1 = 97.75 Hz |
| Neural-network result (earlier run) | 113 bricks in 10 separate pieces, floating fragments | 125 bricks in 2 face-connected pieces, no brick without a face neighbour, f1 = 100.30 Hz |

## 5. Limits

* The outline is still made of whole bricks (a staircase of 3 mm steps). Cleaning removes defects; it does not round
  corners. A smoothed STL export of the brick layout would be a separate step.
* `MinWidth` is measured in the layer plane. Thickness is set by the layer count (`P.Design.Layers`).
* Cleaning is a rule, not an optimization: it can change the structure noticeably when the optimizer's result is thin.
  For SIMP the remedy is a filter radius that matches `MinWidth` (`H.FilterRadius = 'auto'`, see `03_simp.md`: with 4.5 mm the
  cleaned maximize design lost 140 Hz, with 8 mm it lost 1.3 Hz). For a frequency TARGET the cleaned design is still off
  (123 Hz for a 100 Hz target even with the matched radius), which is why polish exists.
* Bricks locked by supports, load or outputs are treated as permanent material.
* Polish needs one real analysis per boundary brick and step: about 25 to 100 analyses per step (parallel if available).

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
