---
name: manifest
description: Generate or update a getManifest()-style output-path manifest (the nextflow_crash_course day2 convention) for a Nextflow subworkflow or workflow in nextflow_pipelines/. Use when the user asks to create/add/update a manifest for a subworkflow or workflow, or invokes /manifest.
---

# Nextflow output manifest

Produce a `manifests/manifest_<name>.nf` file declaring every real output path a
subworkflow or workflow produces, as a plain Groovy map (`getXManifest()`), per the
convention in `nextflow_crash_course/day2_material/day2_pipeline2production.qmd`
("`getManifest()`: naming every output once") and demonstrated in
`nextflow_pipelines/manifests/`.

## Steps

1. **Identify the target(s).** A subworkflow (`nextflow_pipelines/subworkflows/<name>.nf`)
   or a workflow (`nextflow_pipelines/workflows/<name>/<name>.nf`). If the user didn't name
   one and it's not obvious from context, ask. If asked for "all" or "every subworkflow",
   enumerate `nextflow_pipelines/subworkflows/*.nf` (skip `TEMPLATE.nf`) and
   `nextflow_pipelines/workflows/*/*.nf`, and skip any that already have a
   `manifests/manifest_<name>.nf`.

2. **Trace every output to its real source.** Read the target's `take:`/`emit:` block
   (subworkflow) or full body (workflow). For each emitted channel, follow it back to the
   process that actually produces it, then read that process's own file:
   - Shared tool wrappers: `../../../nextflow_modules/modules/<tool>.nf`
   - Local, benchmark-specific processes: `../modules/local/<name>.nf`
   Get the real output filename/path from the process's `output:` block and shell script —
   never invent one. If you're inferring a filename from a tool's well-known behavior
   rather than reading it directly in this repo's code (e.g. CheckV's standard
   `quality_summary.tsv`/`completeness.tsv`/etc.), say so in a comment next to it.

3. **Exclude what never reaches disk.** Anything captured only via `env()` in a process
   output, or anything `subworkflows/CLAUDE.md` documents as never separately written to
   disk (per-subworkflow `metrics` rows — only the parent workflow's merged
   `pipeline_info/metrics_summary.tsv` is a real file). Don't fabricate a path for it.

4. **Exclude inputs.** A subworkflow's `take:` channels sourced from elsewhere (e.g. an
   assembly passed in from the parent workflow) belong in whichever manifest actually
   produces them, not this one.

5. **Path style.** Relative to a per-sample root, no sample ID baked into the filename
   (e.g. `fastq/clean_r1.fastq`, not `${sampleid}_clean_1.fastq`), grouped by semantic
   category matching what the file represents, not today's flat `params.*_outdir` layout.
   Note at the top of the file that this is a target layout and is **not** wired into any
   `publishDir` — don't touch existing `publishDir` lines unless the user separately asks
   for that rewire (it's a real behavior change, not implied by "add a manifest").

6. **Location, naming, composition.**
   - `nextflow_pipelines/manifests/manifest_<subworkflow-or-workflow-name>.nf`
   - Function name `get<PascalCaseName>Manifest()` (e.g. `getReadqcManifest()`); reserve
     bare `getManifest()` for the top-level workflow file.
   - A workflow-level manifest composes its subworkflows' manifests via `include {}` plus
     any paths the workflow owns directly (tools it calls outside any subworkflow, and
     pipeline-wide files like the merged metrics summary).
   - **Merge sub-manifests with plain map `+`** (`getA() + getB() + [...]`), never
     Groovy's spread-map operator (`*:` inside a map literal, as
     `nextflow_crash_course/day2_material/manifests/example_manifest.nf` uses) — that does
     **not** parse under Nextflow's strict script parser (confirmed against 26.04.6:
     `Unexpected input: '*'`), even though it's the pattern the crash-course example
     follows.

7. **Verify every new/edited file**, standalone, before considering it done:
   ```
   nextflow run nextflow_pipelines/manifests/manifest_<name>.nf
   ```
   Expect `[SUCCESS] completed=0 failed=0 cached=0` with no compile error — there's no
   `workflow {}` entry point to actually run, so a clean parse is the whole check. Clean up
   `work/` and `.nextflow*` it leaves behind afterward.

## Checklist before considering a manifest done

1. Every path is either read directly from a module's real output, or explicitly marked as
   an inferred/standard tool output.
2. No `take:`-only input channels included.
3. No file included for something proven to never hit disk.
4. No Groovy spread-map (`*:`) syntax — plain map `+`.
5. `nextflow run` on the file succeeds with a clean parse; scratch run artifacts cleaned up.
6. Header comment notes it's a declarative target layout, not wired into `publishDir`.
