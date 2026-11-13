# bonphyre_pipelines

Nextflow pipelines for metagenomics from the BONPHYRE project and the Hurwitz
lab. Tool modules (BBDuk, MEGAHIT, geNomad, ...) are not kept here: they're
shared lab-wide through the sibling
[`nextflow_process_library`](https://github.com/hurwitzlab/nextflow_process_library)
repo.

## Pipelines

| Pipeline | What it does | Status |
|---|---|---|
| `i_mg_viralinferencegenomad` | Finds viruses in Illumina paired-end metagenomes and builds a viral abundance table: read QC, MEGAHIT assembly, geNomad + CheckV viral filtering, MMseqs2 clustering, BWA + CoverM abundance | **Released** in `nextflow_pipelines/`. User guide: [`nextflow_pipelines/workflows/i_mg_viralinferencegenomad/README.md`](nextflow_pipelines/workflows/i_mg_viralinferencegenomad/README.md) |
| `i_mg_viralinfbenchmark` | Benchmarks viral identification tools (geNomad, VIBRANT, VirSorter2, DeepVirFinder, MARVEL, ...) | In development (`dev/`) |
| `i_mg_generatemockmetagenomes` | Generates mock metagenomes | In development (`dev/`) |
| `i_mg_bac_class_metaphlan` | Bacterial classification with MetaPhlAn | In development (`dev/`), just started |

## Repo layout

```
bonphyre_pipelines/
├── nextflow_pipelines/        released pipelines; run these
│   ├── nextflow.config  conf/          configs shared by every pipeline
│   ├── workflows/<pipeline>/           each pipeline's .nf, .config and README
│   ├── subworkflows/  modules/local/  bin/
│   └── build.sh                        builds a self-contained copy of one pipeline
├── dev/<pipeline>/            pipelines in development, one self-contained copy each
│   ├── pipeline/
│   └── nextflow_process_library/
├── writing/                   write-ups and notes
├── NOTEBOOK.md                lab notebook (see below)
└── .claude/skills/            Claude Code skills for this repo (/notebook, /manifest)
```

## Running a pipeline

Clone this repo and `nextflow_process_library` **side by side** in the same
parent folder (the pipelines load modules by relative path):

```bash
git clone https://github.com/hurwitzlab/bonphyre_pipelines.git
git clone https://github.com/hurwitzlab/nextflow_process_library.git
```

Then follow the pipeline's own README. For how the config files fit together
and which ones you edit, see
[`nextflow_pipelines/README.md`](nextflow_pipelines/README.md).

## From dev to release

1. **Develop in `dev/<pipeline>/`.** Each folder is a self-contained copy made
   with `nextflow_pipelines/build.sh` (`pipeline/` next to its own
   `nextflow_process_library/`), so you can change and test modules without
   touching the shared library or anyone else's pipeline.
2. **Release it.** When the dev copy runs end to end, copy its `pipeline/`
   into `nextflow_pipelines/` on a branch. The only difference to fix is the
   include paths to the library, which need one more `../` there. Open a PR.
3. **Send module changes upstream.** Any change you made to a module in the
   dev copy goes to `nextflow_process_library` in its own PR, so the released
   pipeline and the library match.

## Contributing

This repo gets edited concurrently by different lab members, and often by
more than one Claude Code session at once. Before editing a
subworkflow, module, or config here:

1. Follow `nextflow_pipelines/subworkflows/CLAUDE.md` and `TEMPLATE.nf` for
   new subworkflows.
2. Follow the shared `nextflow_process_library`'s own
   `modules/CLAUDE.md` for tool modules there, and keep anything specific to
   one pipeline (QC/metrics logic, thresholds) in this repo's own
   `nextflow_pipelines/modules/local/` — never in the shared module repo.
3. Verify a changed subworkflow standalone with `nextflow run <file>.nf` —
   it should fail only on a missing required parameter, not a compile error.
4. Whatever you change here — a subworkflow, a config, `CLAUDE.md`, this
   README, anything — **record it in `NOTEBOOK.md` before you're done** (see
   below), not just in the commit message. The commit says *what* changed;
   the notebook says *why* and *what happened* (results, errors, decisions,
   flags for whoever picks this up next).

### Lab notebook conventions

`NOTEBOOK.md` at the repo root is a chronological, append-only log of work
sessions on this repo — one dated entry per session, covering what was done,
what happened (concrete results/errors, not a diff restatement), and the
decision or next step. Never edit or reorder past entries; always append.

If you use Claude Code, this convention is checked in as a project skill at
`.claude/skills/notebook/` — anyone who clones this repo gets the same
`/notebook` behavior automatically, no setup needed. If you don't use Claude
Code, follow the header format documented at the top of `NOTEBOOK.md`
itself.

If you use Claude Code, this is a suggested prompt:

```
Before we wrap up, review what we changed in this session and append one
dated entry to NOTEBOOK.md at the repo root, following the format in its own
header. Cover:
- what was done/tried
- what happened — concrete results, errors, numbers, not a restatement of
  the diff
- any decision made or flags left for whoever works on this next

If today's date already has an entry, add to it rather than starting a new
heading. Never edit or reorder any past entry — only append.

Use the skill present in this repo for lab notebook generation.
```
