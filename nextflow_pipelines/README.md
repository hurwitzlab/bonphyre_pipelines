# nextflow_pipelines

Nextflow pipelines for viral inference benchmarking. Each pipeline lives under
`workflows/<name>/` and is built from pipeline-specific `subworkflows/` and
tool modules shared lab-wide (see **Modules** below).

**To set up and run `i_mg_viralinferencegenomad`, see its user guide:
[`workflows/i_mg_viralinferencegenomad/README.md`](workflows/i_mg_viralinferencegenomad/README.md).**

## Prerequisites

Clone this repo and [`nextflow_process_library`](https://github.com/hurwitzlab/nextflow_process_library)
**as siblings**, under the same parent directory:

```
some_parent_dir/
  bonphyre_pipelines/
  nextflow_process_library/
```

Every `include` statement in this repo's subworkflows/workflows references
tool modules by relative path (e.g. `../../../nextflow_process_library/modules/genomad/genomad.nf`),
so this layout isn't optional — if `nextflow_process_library` isn't cloned in exactly
this location, every include fails at parse time.

## Which config do I edit?

### Config layout

```
nextflow_pipelines/
  nextflow.config                      # HOW to run: profiles (executor, Singularity, limits) per cluster
  conf/
    site.config                        # WHERE things are: databases, .sif images, data lake root
    base.config                        # HOW MUCH: Slurm queue/account, resources per label, publish labels
  workflows/
    <name>/
      <name>.config                    # WHAT to run: reads, database paths, containers, tool params
      <name>.nf
```

| File | What it holds |
|---|---|
| `workflows/<name>/<name>.config` | That pipeline's `reads` default, database paths, `container__*` images, tool params (`bbduk_k`, `megahit_preset`, ...), QC thresholds, and the `pipeline_name`/`workflow_version` that (with `--project_id`) build `outdir`. This is the file you pass with `-c`; it includes the other three. |
| `conf/site.config` | `databases_dir`, `singularity_images_dir`, `singularity_images_dev`, `data_lake_dir`: where reference databases, container images and results live on one machine/cluster. Pipeline configs build every path from these. |
| `conf/base.config` | The Slurm `queue` and `clusterOptions` (account/QOS) every job is submitted to, default CPU/memory/time per resource label (`process_single/low/medium/high`), the retry rule, and the `publish_*` labels. |
| `nextflow.config` | Profiles (`hazel`, `hazel_test`): executor, how Singularity is loaded, `resourceLimits`, `workDir`. |

### What you edit depends on who you are

The defaults are set up for the Hurwitz lab on NC State's Hazel cluster, so
the further you are from that setup, the more files you edit:

| You are... | Files you edit | Profile |
|---|---|---|
| **A member of BONPHYRE / the Hurwitz lab** | Only `workflows/<name>/<name>.config` | `-profile hazel` |
| **At NC State, not in the Hurwitz lab** | The workflow config, `conf/site.config` (your databases, images and data lake), and `queue`/`clusterOptions` in `conf/base.config` (your Slurm partition and account; the lab's `compute_partners` / `--account=ivirus_cpu` reject other users) | `-profile hazel` |
| **At a different organization** | All of the above, **plus** a new profile in `nextflow.config` (copy `hazel` and change the executor, `beforeScript`, `resourceLimits` and `singularity.cacheDir`) | `-profile <your_profile>` |

You should never need to edit a pipeline's `.nf` workflow, subworkflow, or
module file to run it somewhere new. If you find yourself doing that,
something belongs in one of the config files above instead.

For step-by-step instructions, see each pipeline's own README, e.g.
[`workflows/i_mg_viralinferencegenomad/README.md`](workflows/i_mg_viralinferencegenomad/README.md).

### How the configs are loaded

Each `<name>.config` includes `'../../conf/site.config'`,
`'../../conf/base.config'` and `'../../nextflow.config'`, so
`params.databases_dir`, `params.singularity_images_dir` and the profiles are
available to every pipeline without being redefined per pipeline.
`site.config` comes first because the pipeline config needs
`params.data_lake_dir` early to build `params.outdir` (which must already be
set by the time `nextflow.config` is parsed; see the comments in that file).
`nextflow.config` includes `site.config` and `base.config` again;
re-including the same config file twice is harmless. A future `<name>.config`
that also builds `outdir` from the data lake should follow the same pattern.

When a value is set in more than one place, the last one loaded wins, and
command-line values beat every file:

```
site.config / base.config  →  nextflow.config (+ -profile)  →  <name>.config  →  -params-file  →  --flags
```

So one-off changes go on the command line (`--trimmomatic_minlen 60`); edit a
file only to change a default every time.

## Running a pipeline

```bash
nextflow run workflows/i_mg_viralinferencegenomad/i_mg_viralinferencegenomad.nf \
    -c workflows/i_mg_viralinferencegenomad/i_mg_viralinferencegenomad.config \
    -profile hazel \
    --reads '/path/to/your/reads/*_R{1,2}.fastq.gz' \
    --project_id my_project \
    -resume
```

- `-c` is required: it loads the pipeline config, which loads the rest.
- `-profile` selects the executor/container setup (`hazel`, `hazel_test`, or
  a new one you add to `nextflow.config`).
- `--reads` and any other `params.*` shown in a pipeline's `.config` file can
  be overridden the same way, without editing anything.
- `--project_id` is **required** — there's no default. Every run is
  namespaced under a project on the data lake so different projects'
  (or different pipelines'/versions') outputs never collide. `outdir` itself
  is *not* a flag you pass: it's built automatically as
  `"${data_lake_dir}/<project_id>/<pipeline_name>/<workflow_version>"` (see
  `i_mg_viralinferencegenomad.config`). You technically can still override it
  directly with `--outdir` since it's a normal `params.outdir` under the
  hood, but doing so opts you out of the data lake layout this convention
  exists for.
- On Hazel, submit the launch command as a job (`sbatch submit_hazel.sh`)
  rather than running it on the login node.

## Modules

Tool modules (`genomad.nf`, `checkv.nf`, `bbmap.nf`, ...) live in the separate
[`nextflow_process_library`](https://github.com/hurwitzlab/nextflow_process_library) repo, not
in this one — the whole lab shares the same module files across every
pipeline. This repo only keeps its own `subworkflows/` (pipeline-specific
orchestration) and each workflow's own `.config`/`.nf`.

To add or change a tool module, work in `nextflow_process_library`, following the
conventions in its `modules/CLAUDE.md`, and bump the relative-path reference
here only if the module's filename changes.

## Where outputs are published

Modules in `nextflow_process_library` carry no `publishDir` of their own.
Each one has a publish label next to its `process_<tier>` label, and
`conf/base.config` turns that label into a `publishDir`:

| Label | Published to | Mode |
|---|---|---|
| `publish_intermediate` | `<outdir>/<sampleid>/<process name>/` | `publish_mode_intermediate` (default `symlink`) |
| `publish_final` | `<outdir>/<sampleid>/<process name>/` | `publish_mode_final` (default `copy`) |
| `publish_intermediate_pooled` | `<outdir>/<pooledid>/<process name>/` | `publish_mode_intermediate` |
| `publish_final_pooled` | `<outdir>/<pooledid>/<process name>/` | `publish_mode_final` |

- `<process name>` is the short name (the subworkflow prefix is removed), e.g.
  `<outdir>/sampleA/trimmomatic/`.
- The `*_pooled` labels are for steps that make one output from all samples
  together (the viral catalog, the abundance table). Those processes take
  `val(pooledid)` in place of `val(sampleid)`, e.g. `viral_catalog`.
- A process with a publish label publishes nothing if the pipeline's config
  has no matching `withLabel:` block.
- Intermediate outputs are symlinks into `work/`, so they break if `work/`
  is deleted. This is why `cleanup = false` in `nextflow.config`.

The manifest-based layout used before (`manifests/`, `params.<tool>_outdir`)
has been removed. A copy was kept outside the repo for review.
