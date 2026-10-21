# 00 - Course guide: AI-supported mechanical design

For instructors. The aim is that students **design a part first and analyse it second**, and that they become familiar with machine learning,
neural networks and AI assistants as design tools, without having to be experts. The toolbox is the lab: the simulation is the ground
truth, AI tools propose, the student judges.

## Principles to repeat in every lab

1. **Design first, then analyse.** A student states the task (what is fixed, what load, what "better" means) before touching code.
2. **AI proposes, the solver verifies, the engineer judges.** No AI answer is a result until the solver has checked it and the student
   has read the figure and the sanity checks (`idt_sanity_checks`).
3. **Predict before you run.** Write down what you expect (deflection, which layout is stiffer) and compare afterwards.
4. **Numbers need units and a hand check.** Everything is SI. Compare at least one result with a hand estimate.

## Suggested sequence (five labs of 2-3 hours)

| Lab | Student does | Files | Learning goals |
|---|---|---|---|
| 1. Simulate | Run the static cantilever step by step; read the face-number figure, check the reaction force, vary the load and mesh | `SIM_StaticLoad.m`, `docs/10_static_load.md` | boundary conditions, units, mesh convergence, what a sanity check is |
| 2. Design by hand, then by optimizer | Remove bricks by hand for a stiffer or lighter beam; then run SIMP and the GA and compare | `SIM_StaticLoad.m` step 3, `CASE_SIMP_StaticBeam.m`, `CASE_GA_StaticBeam.m`, `docs/11_static_optimization.md` | design intuition, what an objective and a constraint are, gradient-based vs population-based search |
| 3. Learn a surrogate | Train a network on analysis results; see how error depends on data; run the neural-network optimizer | `EXERCISE_SurrogateData.m`, `CASE_NN_StaticBeam.m`, `idt_export_dataset` | training / testing, over- and under-fitting, cost of data, why candidates are verified |
| 4. AI assistant as designer | Ask an assistant for designs, score them with the solver, feed the numbers back, compare with optimizers | `EXERCISE_AIDesigner.m` | prompting with a precise problem, verification, strengths and limits of assistants |
| 5. Project | Own part (STEP file) and own goal (static or vibration), design with any tools, defend the result | `SIM_*.m`, `CASE_*.m`, `AGENTS.md` | the whole loop, honest reporting |

Vibration (`SIM_HarmonicMotion.m`, `CASE_*_TargetFrequency.m`, isolator cases) can replace or extend Labs 1-3 for a dynamics course.

## What students should observe (typical, this machine; yours will differ)

Static cantilever, 500 N, 50 % of the web bricks kept, coarse linear mesh:

| Method | Compliance (smaller = stiffer) | Real analyses |
|---|---|---|
| Full beam (reference) | 22.8 mJ | - |
| SIMP | about 34 mJ | 200 solves |
| Genetic algorithm | about 41 mJ | about 2300 |
| Neural network optimizer | about 48 mJ | about 900 |
| Best of 100 random layouts | about 50 mJ | 100 |

Points to draw out in discussion: the gradient method wins on this small, cheap problem; the neural network needs data and its prediction error
(about 40 % in `EXERCISE_SurrogateData`) does not vanish with more data of the same kind; an assistant's design is judged by the same
number; none of the objectives includes stress, so a stiff design can be overstressed.

## Exercises that can be graded

- **Lab 1 report:** table of tip deflection vs mesh size, with the hand estimate; the reaction check printed by `idt_sanity_checks`.
- **Lab 2 report:** best hand design, SIMP, GA: compliance, mass, number of analyses; one paragraph on why they differ.
- **Lab 3 report:** error vs training size (figure from `EXERCISE_SurrogateData`); answer: "when would you use a surrogate?".
- **Lab 4 report:** table of at least 4 rounds with the assistant (prompt change, score, rule violations) and a comparison with the optimizers.
- **Project:** problem statement, design, verification (hand check, mesh, sanity checks), limitations (what was not checked, e.g. stress).

## Rubric (suggested, 100 points)

| Criterion | Points |
|---|---|
| Problem stated clearly (loads, supports, goal, units) | 15 |
| Model set up correctly and checked (faces, mesh, `idt_sanity_checks`, hand estimate) | 25 |
| Design process documented, including at least one AI-assisted step and what the solver said about it | 25 |
| Result interpreted honestly (what was optimized, what was not: stress, fatigue, manufacturing) | 20 |
| Report clarity and reproducibility (parameters saved, seeds, files) | 15 |

## Using AI assistants in the labs

- Point the assistant to `AGENTS.md`; it explains the workflow, units, face numbers and checks.
- Students keep a log: prompt, answer, what they changed, what the solver said. This log is graded in Lab 4 and the project.
- Rules for the course (suggestion): an assistant may suggest code and designs; the student must be able to explain every line they run and every
  parameter they set. A design is only reported with the solver's numbers.
- Typical failure cases to show on purpose: a made-up face number or brick, millimeters entered as meters (the validator `idt_validate_params`
  stops these), an answer that breaks the volume limit, a design that is a mechanism (bricks joined only at an edge or corner).

## Practical notes

- Give students the guide at https://InverseDesignToolbox.sayginer.com (interactive guide with three explanation levels, a path chooser, run guide and glossary). It explains; it does not run anything.

- Requirements are in `README.md` (MATLAB R2023b+ and the PDE Toolbox; the Deep Learning and Global Optimization toolboxes for Labs 2-4).
  Without the Parallel Computing Toolbox everything runs serially, slower.
- Run `SIM_StaticLoad.m` once before the exercises: it saves `results/CantileverBeam.mat`, which they load.
- Run times on a laptop with 6 workers: SIMP about 1.5 min, GA about 3 min, neural network about 3 min, `EXERCISE_SurrogateData` about 2-5 min.

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
