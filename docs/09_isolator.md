# 09 - Vibration isolator: block a frequency band

An isolator should keep base vibration away from a protected point (here the sensor on the holder). The goal is therefore **not** a
natural frequency but the **transmissibility** inside the band that must be blocked.

```matlab
H.Objective = 'MinTransmissibility';
H.Isolation.Band   = [100 500];     % Hz that must be blocked
H.Isolation.Output = 1;             % protected output point
H.Isolation.Pairs  = [3 3];         % [response base] direction: vertical base motion -> vertical response
```

Case studies: `CASE_GA_Isolator.m` (brick layouts, genetic algorithm) and `CASE_GA_Shape_Isolator.m` (holes and rectangles,
genetic algorithm). Everything else (model, clean-up, polish, STL, exact CAD check) is shared with the other case studies.

## 1. The measure

Base excitation: the clamped faces move together as a rigid body with a harmonic displacement. The transmissibility of an output
point is `T(f) = |absolute response of the output| / |base motion|` (`core/transmissibility.m`, modal damping `P.Analysis.Zeta`).

| T | Meaning |
|---|---|
| T = 1 | the output moves exactly like the base |
| T > 1 | the vibration is **amplified** (resonance) |
| T < 1 | the vibration is reduced; T = 0.1 is -20 dB |

For a single mass on a spring, T < 1 above about 1.41 x f1. A real structure has more modes, and **every mode inside the band puts a
peak above 1 there**. That is why a target for f1 alone does not work: with f1 = 57 Hz the example had T = 0.4 at 100 Hz but peaks
of 1.2 to 3 near its second mode (about 215 Hz) and of 8 to 10 in the lateral directions.

## 2. The goal `'MinTransmissibility'`

The cost of a design is `log10(peakT)`, where `peakT` is the largest `|T|` over the band, over the protected outputs and over the
direction pairs you list (`idt_isolation_metric`). So 0 means "just not amplifying", -1 means 20 dB of isolation everywhere in
the band. A design that cannot be analysed costs 50. `H.VolMax` can be added as a volume limit; for the brick GA the cleaned
layout is judged, as in the other goals; the shape GA also penalizes thin walls (`docs/08_shape_cutters.md`).

| Option (`H.Isolation.`) | Default | Meaning |
|---|---|---|
| `Band` | `[100, FreqEnd]` | `[f_low f_high]` in Hz. It must lie inside the sweep `P.Analysis.FreqStart ... FreqEnd` |
| `Output` | 1 | protected output point(s): number, list, or `'all'` (the worst one counts) |
| `Pairs` | `[3 3]` | rows `[response base]`, 1 = x, 2 = y, 3 = z. `[3 3; 1 1; 2 2]` blocks vertical and both lateral directions, worst of them counts |
| `TargetT` | `[]` | stop as soon as the peak T is below this value (for example 0.5, or 0.1 for -20 dB) |

The optimizers switch `P.Analysis.Transmissibility` on for this goal. The polish step (`idt_polish_bricks`) also supports it.

## 3. What you must set in the runner

* **Sweep and modes.** The sweep must contain the band, and the highest kept mode should be above 1.5 x `FreqEnd` ("modal
  coverage" in the report). Otherwise the T at the top of the band is not reliable. The runners set `FreqEnd = 500` and `NModes = 10`.
* **Damping.** `P.Analysis.Zeta` (0.05) is assumed. Peak heights scale with it; measure it for your material.
* **Material.** The example uses TPU with E = 50 MPa as in the saved parameters; every frequency scales with the square root of E.

## 4. Output and figures

`out.PeakT`, `out.Isolation` (table: output, response, base, peak T, frequency of the peak, one row per output and pair),
`out.res` (full analysis with `res.TAmp`), plus the usual `out.X` / `out.cut`, `out.History`, `out.Polish`.
`idt_plot_isolation(res, I)` draws T against frequency with the band shaded, T = 1 dotted and the worst peak marked.
The shape case study also checks the best design with the exact CAD cut and reports the peak T there.

## 5. Flat passband below the stop band (`H.Isolation.Pass`)

Often the isolator should also pass slow motion unchanged: T close to 1 up to a corner frequency (no resonance peak), then isolation above the stop-band start.
`H.Isolation.Pass = [2 60]` and `H.Isolation.PassTol = 3` (dB) add this to the cost (`idt_isolation_cost`):

    J = ( 20*log10(peakT in the stop band)  +  PassWeight * max(0, dev - PassTol) ) / 20 ,   dev = largest |20*log10(T)| in Pass

so 1 dB of passband violation costs as much as 1 dB less isolation. Between `Pass(2)` and `Band(1)` (here 60 to 100 Hz) the response is free: no
real structure can go from T = 1 to T = 0.1 in no distance. With a passband set, `TargetT` is ignored and the search runs to its limits.

**Why this is hard.** A spring-mass system has T > 1 on the way up to its resonance, and the resonance peak is about 1/(2 zeta). Standard formula, single mass:

| zeta | peak T | T at half the resonance frequency |
|---|---|---|
| 0.05 | 10.1 | 1.33 |
| 0.2 | 2.7 | 1.31 |
| 0.5 | 1.47 | 1.24 |
| 0.7 | 1.28 | 1.19 |

Even heavy damping does not make one resonance flat. A flat passband followed by isolation needs several modes working together AND damping.

## 6. Measured (example geometry, 402 bricks, `CASE_GA_Isolator.m`, stop band 100-500 Hz, passband 2-60 Hz +-3 dB, output 1, vertical)

| zeta (whole structure) | stop band: peak T | passband deviation (allowed 3 dB) | f1 / f2 | bricks | note |
|---|---|---|---|---|---|
| 0.05 (assumed TPU) | **0.098 (-20.2 dB)** | **17.1 dB**: resonance at 30.6 Hz, T = 7.1 | 30.6 / 92.3 Hz | 58 | isolates well, passband far from flat |
| 0.3 | 0.21 (-13.4 dB) | 5.8 dB (T = 1.95 near 30 Hz) | 31.3 / 100.4 Hz | 37 | closer |
| 0.6 | 0.34 (-9.3 dB) | 3.9 dB (T = 1.27 near 30 Hz) | 29.0 / 73.9 Hz | 97 | almost flat, isolation reduced |

**Reading it.** Flat to +-3 dB below 60 Hz and -20 dB above 100 Hz is not reached at any damping tried: the more damping, the flatter the passband
but the weaker the isolation (-20 -> -13 -> -9 dB), because damping adds transmission at high frequency. A realistic printed TPU is probably at
zeta 0.05 to 0.15 (not measured here), where the passband stays far from flat. Options: accept a passband peak (for example +-6 dB or T < 2), accept weaker isolation, or add a real
damping mechanism (a damping layer or viscoelastic insert); the model has one global zeta, so a damping GEOMETRY is not modelled yet (modal strain energy per material would be the way).

Two bugs found by these runs and fixed: (1) the polish step for this goal accepted a hinge-like layout (f1 = 0.0 Hz, a mechanism) because it lacked the f1 check the GA has;
it now rejects every layout with f1 below 1 Hz; (2) stopping at `TargetT` ignored the passband, so a run stopped after one generation with a non-flat passband.

**Shape isolator (`CASE_GA_Shape_Isolator.m`) does not isolate this part.** Cutters only remove material, f1 stays near 300 Hz, and the best design had peak T = 13.5 in the band
(exact CAD cut 13.6). Cutters cannot make this part soft enough; use the brick optimizer, or a geometry whose f1 is already low.

**Not measured:** TPU damping and stiffness, lateral directions (`Pairs`), output 2, the real printed part. All the numbers above use the assumed zeta and E = 50 MPa.

---

*InverseDesignToolbox - author: Dr. Osman Sayginer.*
