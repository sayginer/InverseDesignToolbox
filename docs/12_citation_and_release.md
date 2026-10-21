# 12 - Citation and release (for the author)

How to give the InverseDesignToolbox a DOI and make it easy to cite. Nothing here is automatic: the steps below need your
accounts (GitHub, Zenodo, ORCID). Check each service's current instructions, because the details change.

## Status`n`nThe DOI exists: **10.5281/zenodo.23523181** (https://doi.org/10.5281/zenodo.23523181). It is in `CITATION.cff`, the README (badge and "How to cite") and the guide's Cite page. Check on the Zenodo record that it is the **concept DOI** ("Cite all versions"); if it is a version DOI, replace it everywhere with the concept DOI. For each new release only `version` and `date-released` in `CITATION.cff` (and the version in the README and the guide's Cite page) change.`n`n## A. Get a DOI (free, about an hour)

1. **Make a public GitHub repository** with the toolbox folder (code, `cad/`, `docs/`, `README.md`, `LICENSE`, `CITATION.cff`).
   Do not commit large result files (`results/*.mat`, `*.stl`) unless they are needed; put a small example result in `results/`.
2. **Create an ORCID** (orcid.org) if you do not have one, and add it to `CITATION.cff`.
3. **Link Zenodo to GitHub** (zenodo.org, log in with GitHub, switch the repository on in the GitHub settings page).
4. **Publish a release** on GitHub (for example tag `v1.0.0`). Zenodo archives it and issues a DOI within minutes.
5. **Zenodo gives two DOIs:** one for that exact version, and a "concept DOI" that always points to the latest. Cite the
   concept DOI in general, the version DOI when you need the exact code.
6. Put the DOI in `CITATION.cff`, the README (a DOI badge) and the guide (the Cite page, published at https://InverseDesignToolbox.sayginer.com), then
   publish the next release so the archived copy contains it.

## B. What actually earns citations

A DOI makes the software citable. It does not make people cite it. In rough order of effect:

- **A paper that people can cite.** Many authors prefer to cite a paper. Options: the *Journal of Open Source Software* (research
  software; read its current submission rules, it expects open source, documentation, tests and sustained development),
  *SoftwareX*, or an engineering-education venue (for example an ASEE conference paper or a journal on computer applications in
  engineering education) for the teaching side. A preprint on arXiv or EngrXiv gives a citable record sooner.
- **Visible in the places people look.** MATLAB File Exchange (link the GitHub repository; File Exchange shows a "Cite as" line),
  a good README with a figure, topics/keywords on GitHub, a short demo video, and the interactive guide hosted at a stable URL.
- **Easy to cite correctly.** `CITATION.cff` (GitHub shows "Cite this repository"), a BibTeX entry in the README, a DOI badge,
  a stable name and release numbers.
- **Used in papers and teaching.** Use the toolbox in your own publications and cite it, ask collaborators and students to cite
  it in theses and reports (the guide's Cite page tells them how), and keep the exercises and the guide openly licensed.
- **Maintained.** Tagged releases, a changelog, a small test suite, and responses to issues. Software that works on a new MATLAB
  release is cited more than software that does not.
- **Licensing.** The code is MIT. Consider a Creative Commons licence (for example CC BY 4.0) for the documentation and the guide,
  so teachers can reuse and adapt them with attribution.

## C. Before the first release, check

- The name and the author line are the same everywhere (README, files, guide, `CITATION.cff`).
- `LICENSE` is present. MATLAB and its toolboxes are MathWorks products with their own licence; say so in the README.
- The example CAD files may be shared (they are yours).
- No private paths or personal data in the files.
- The version number is set in `CITATION.cff` and in a `VERSION` or changelog entry.

---
*InverseDesignToolbox - author: Dr. Osman Sayginer.*
