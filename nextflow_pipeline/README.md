# nextflow_pipeline

Nextflow pipelines for viral inference benchmarking. Each pipeline lives under
`workflows/<name>/` and is built from pipeline-specific `subworkflows/` and
tool modules shared lab-wide (see **Modules** below).

## Prerequisites

Clone this repo and [`nextflow_modules`](https://github.com/hurwitzlab/nextflow_modules)
**as siblings**, under the same parent directory:

```
some_parent_dir/
  viral_inference_benchmark/
  nextflow_modules/
```

Every `include` statement in this repo's subworkflows/workflows references
tool modules by relative path (e.g. `../../../nextflow_modules/modules/genomad.nf`),
so this layout isn't optional — if `nextflow_modules` isn't cloned in exactly
this location, every include fails at parse time.

## Which config do I edit?

### Config layout

```
nextflow_pipeline/
  conf/
    site.config                        # edit this, once per machine/cluster
    base.config                        # default per-process resources, by label
  nextflow.config                      # repo-wide: profiles, includeConfig site.config + base.config
  workflows/
    <name>/
      <name>.config                    # per-pipeline: I/O paths, tool params, container refs
      <name>.nf
```

There are four config files in this repo. As someone *running* a pipeline
(not developing one), you'll only ever touch the first one:

| File | What it holds | Who edits it, and when |
|---|---|---|
| `conf/site.config` | `databases_dir`, `singularity_images_dir` — where your reference databases and container images live on disk | **You, once**, the first time you run any pipeline here on a new machine/cluster. This is the file. |
| `workflows/<name>/<name>.config` | That pipeline's tool params (`bbduk_k`, `megahit_kmin`, ...), I/O defaults (`reads`, `outdir`), and container references | The pipeline's maintainer, when adding/changing a tool or its default settings. As a runner, you'd only touch this to change a *default* permanently — day-to-day tweaks go through `--flags` instead (see below), not this file. |
| `nextflow.config` (repo root) | Profiles (`hazel`, `local`) and `includeConfig` wiring that pulls `site.config`/`base.config` into every pipeline | Rarely — only when adding support for a new cluster/executor. Not something you edit to run an existing pipeline. |
| `conf/base.config` | Default CPU/memory/time per resource tier (`process_single/low/medium/high`), shared by every pipeline | Rarely — only if the lab's actual hardware/typical job sizes change lab-wide. |

In short: **`conf/site.config` is the one file you edit to use these
pipelines.** Everything else is either plumbing you never touch, or a
per-pipeline default that a maintainer sets and you override at the command
line instead of editing.

## Running a pipeline

**The only file you need to edit is `conf/site.config`, and only the first
time you run a pipeline on a new machine or cluster.** It holds two values:

```groovy
params {
    databases_dir          = '/path/to/databases'
    singularity_images_dir = '/path/to/singularity_images'
}
```

Point these at your reference database root and your prebuilt `.sif`
container directory, and every pipeline in this repo can find its databases
and containers.

Everything else is passed at the command line, not edited in a file:

```bash
nextflow run workflows/i_mg_viralinference/i_mg_viralinference.nf \
    -c workflows/i_mg_viralinference/i_mg_viralinference.config \
    -profile hazel \
    --reads '/path/to/your/reads/*_{1,2}.fastq.gz' \
    --outdir results
```

- `-profile` selects the container engine/executor (`hazel`, `local`, or a new
  one you add to `nextflow.config`).
- `--reads`, `--outdir`, and any other `params.*` shown in a pipeline's
  `.config` file can be overridden the same way, without editing anything.

You should never need to edit a pipeline's `.config`, `.nf` workflow,
subworkflow, or module file just to run it somewhere new — if you find
yourself doing that, something is missing from `conf/site.config` or
`nextflow.config` instead.


