# nextflow_pipelines

Nextflow pipelines for viral inference benchmarking. Each pipeline lives under
`workflows/<name>/` and is built from pipeline-specific `subworkflows/` and
tool modules shared lab-wide (see **Modules** below).

## Prerequisites

Clone this repo and [`nextflow_process_library`](https://github.com/hurwitzlab/nextflow_process_library)
**as siblings**, under the same parent directory:

```
some_parent_dir/
  viral_inference_benchmark/
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
  conf/
    site.config                        # edit this, once per machine/cluster
    base.config                        # default per-process resources, by label
  nextflow.config                      # repo-wide: profiles, includeConfig site.config + base.config
  workflows/
    <name>/
      <name>.config                    # per-pipeline: I/O paths, tool params, container refs
      <name>.nf
```

Each `<name>.config` includes `'../../nextflow.config'`, which pulls in
`conf/site.config` — so `params.databases_dir` and
`params.singularity_images_dir` are available to every pipeline without
being redefined per pipeline. `i_mg_viralinference.config` additionally
includes `'../../conf/site.config'` directly, *before* that, because it
needs `params.data_lake_dir` early to build `params.outdir` (which must
already be set by the time `nextflow.config` is parsed — see the comments
in that file). Re-including the same config file twice is harmless; a
future `<name>.config` that also builds `outdir` from the data lake should
follow the same pattern.

There are four config files in this repo. As someone *running* a pipeline
(not developing one), you'll only ever touch the first one:

| File | What it holds | Who edits it, and when |
|---|---|---|
| `conf/site.config` | `databases_dir`, `singularity_images_dir`, `data_lake_dir` — where your reference databases, container images, and data lake root live on disk | **You, once**, the first time you run any pipeline here on a new machine/cluster. This is the file. |
| `workflows/<name>/<name>.config` | That pipeline's tool params (`bbduk_k`, `megahit_preset`, ...), the `reads` I/O default, container references, and the `pipeline_name`/`workflow_version` that (together with `--project_id`) build `outdir` | The pipeline's maintainer, when adding/changing a tool or its default settings. As a runner, you'd only touch this to change a *default* permanently — day-to-day tweaks go through `--flags` instead (see below), not this file. |
| `nextflow.config` (repo root) | Profiles (`hazel`, `local`) and `includeConfig` wiring that pulls `site.config`/`base.config` into every pipeline | Rarely — only when adding support for a new cluster/executor. Not something you edit to run an existing pipeline. |
| `conf/base.config` | Default CPU/memory/time per resource tier (`process_single/low/medium/high`), shared by every pipeline | Rarely — only if the lab's actual hardware/typical job sizes change lab-wide. |

In short: **`conf/site.config` is the one file you edit to use these
pipelines.** Everything else is either plumbing you never touch, or a
per-pipeline default that a maintainer sets and you override at the command
line instead of editing.

## Running a pipeline

**The only file you need to edit is `conf/site.config`, and only the first
time you run a pipeline on a new machine or cluster.** It holds three values:

```groovy
params {
    databases_dir          = '/path/to/databases'
    singularity_images_dir = '/path/to/singularity_images'
    data_lake_dir           = '/path/to/data_lake'
}
```

Point these at your reference database root, your prebuilt `.sif` container
directory, and your data lake root, and every pipeline in this repo can find
its databases, containers, and where to publish results.

Everything else is passed at the command line, not edited in a file:

```bash
nextflow run workflows/i_mg_viralinference/i_mg_viralinference.nf \
    -c workflows/i_mg_viralinference/i_mg_viralinference.config \
    -profile hazel \
    --reads '/path/to/your/reads/*_{1,2}.fastq.gz' \
    --project_id my_project
```

- `-profile` selects the container engine/executor (`hazel`, `local`, or a new
  one you add to `nextflow.config`).
- `--reads` and any other `params.*` shown in a pipeline's `.config` file can
  be overridden the same way, without editing anything.
- `--project_id` is **required** — there's no default. Every run is
  namespaced under a project on the data lake so different projects'
  (or different pipelines'/versions') outputs never collide. `outdir` itself
  is *not* a flag you pass: it's built automatically as
  `"${data_lake_dir}/<project_id>/<pipeline_name>/<workflow_version>"` (see
  `i_mg_viralinference.config`). You technically can still override it
  directly with `--outdir` since it's a normal `params.outdir` under the
  hood, but doing so opts you out of the data lake layout this convention
  exists for.

You should never need to edit a pipeline's `.config`, `.nf` workflow,
subworkflow, or module file just to run it somewhere new — if you find
yourself doing that, something is missing from `conf/site.config` or
`nextflow.config` instead.


## Modules

Tool modules (`genomad.nf`, `checkv.nf`, `bbmap.nf`, ...) live in the separate
[`nextflow_process_library`](https://github.com/hurwitzlab/nextflow_process_library) repo, not
in this one — the whole lab shares the same module files across every
pipeline. This repo only keeps its own `subworkflows/` (pipeline-specific
orchestration) and each workflow's own `.config`/`.nf`.

To add or change a tool module, work in `nextflow_process_library`, following the
conventions in its `modules/CLAUDE.md`, and bump the relative-path reference
here only if the module's filename changes.

## `publishDir` is wired to `manifests/`

Every process's output location is now built from the manifest that
`manifests/` declares for it, not a flat `params.*_outdir` string:
`bbduk`, `trimmomatic`, `megahit`, `genomad`, `checkv`, and `pileup` all
publish to `"${params.outdir}/<sampleid>/<manifest-declared subpath>"`, so
everything for one sample lands in a single directory tree instead of
interleaving by filename across tool-named directories.

How it works:
- None of `bbduk`/`trimmomatic`/`megahit`/`genomad`/`checkv`/`pileup` has a
  `publishDir` directive in `nextflow_process_library` at all any more. Each just
  carries a second label — `publish_intermediate` (`bbduk`) or
  `publish_final` (the other five) — alongside its usual `label
  "process_<tier>"`. `conf/base.config`'s `withLabel:publish_intermediate`/
  `withLabel:publish_final` blocks are what actually give a labeled process
  its `publishDir`, dispatched per-process via `task.process` (stripped of
  its subworkflow-qualified prefix) to look up that process's own
  `params.<tool>_outdir` — same duality as before
  (`instanceof Closure ? ...(sampleid) : ...`), just resolved centrally in
  one place instead of duplicated into every module. See
  `nextflow_process_library/modules/CLAUDE.md`'s publishDir section (the
  "Alternative" bullet) and `conf/base.config` here for the mechanism.
- `s_i_mg_readqc.nf` and `s_i_mg_genomadviralfilter.nf` each still read
  their own subworkflow manifest (`getReadqcManifest()`,
  `getGenomadViralFilterManifest()`) and set `params.bbduk_outdir`,
  `params.trimmomatic_outdir`, `params.genomad_outdir`,
  `params.checkv_outdir`, and `params.pileup_outdir` to sampleid-taking
  closures before calling their processes — that part is unchanged; only
  *who reads* those params moved, from each module's own `publishDir`
  directive to the centralized `withLabel:` blocks above.
  `i_mg_viralinference.nf` does the same for `params.megahit_outdir` from
  the top-level manifest (megahit is called directly, not via a
  subworkflow).
- Getting the manifest's exact declared filenames (not just directories)
  also meant simplifying `genomad`/`checkv`/`megahit`'s own output paths in
  `nextflow_process_library` to drop their internal, redundant `${sampleid}/`
  nesting — sample-scoping now lives entirely in `publishDir`.

Caveats:
- `bbduk` lives inside `bbmap.nf` in `nextflow_process_library`, not its own
  `bbduk.nf` file — `include { bbduk } from '.../nextflow_process_library/modules/bbmap/bbmap.nf'`.
- The six `*_outdir` params are no longer independently settable — the
  `--trimmomatic_outdir`-style CLI override this README used to promise for
  any `params.*` no longer does anything for these six, since each
  subworkflow overwrites them at runtime. See the comment block in
  `i_mg_viralinference.config`'s INPUT/OUTPUT PARAMETERS section.
- Since the module itself no longer declares any `publishDir`, a labeled
  process silently publishes nothing at all if it's ever run by a pipeline
  that hasn't defined matching `withLabel:publish_intermediate`/
  `withLabel:publish_final` blocks in its own config. Not a risk today —
  these six processes have no other consumer — but worth knowing before
  reusing one of them in a new pipeline.
- `publish_mode_intermediate` (default `'symlink'`) and `publish_mode_final`
  (default `'copy'`) in `conf/base.config` control *how* files land for
  every `publish_intermediate`/`publish_final` process at once — override
  either at the command line (e.g. `--publish_mode_intermediate copy`) to
  change it for a whole tier without touching any module or subworkflow.
