# Subworkflow conventions (viral_inference_benchmark)

Rules for writing/editing `.nf` files in `nextflow_pipelines/subworkflows/`, derived
from `s_i_mg_readqc.nf` and `s_i_mg_genomadviralfilter.nf`. Follow these for any new
subworkflow. See `TEMPLATE.nf` for a copy-paste starting point, and `README.md` for
the file-naming convention.

## File layout

- One file per subworkflow, named per the convention in `README.md`
  (e.g. `s_i_mg_genomadviralfilter.nf`).
- File starts with `#!/usr/bin/env nextflow`, then `nextflow.enable.dsl=2`. Unlike
  modules in the shared `nextflow_process_library` repo, subworkflow files here do declare
  DSL2 themselves.
- `include { }` for shared tool wrappers comes from
  `../../../nextflow_process_library/modules/<tool>/<tool>.nf`. `include { }` for local,
  benchmark-specific processes (QC/metrics helpers — not shared with the rest of
  the lab) comes from `../modules/local/<name>.nf`. Never put benchmark-specific
  logic into a shared `nextflow_process_library` module.
- The workflow name declared inside the file MUST exactly match (a) the filename
  minus `.nf`, and (b) the alias used everywhere it's `include`d. A mismatch
  compiles fine in isolation but fails, or silently resolves to the wrong thing,
  the moment it's included elsewhere — this broke both existing subworkflows
  before this rule was written down.
- No stray top-level `workflow { }` in a subworkflow file. A bare `workflow` is an
  entry point; if two included files both have one, Nextflow ends up with more
  than one entry point in the same run. To test a subworkflow standalone, run
  `nextflow run <file>.nf` directly — it should fail only on the first missing
  required parameter, not a compile/syntax error. That failure is the expected,
  passing result; don't add a throwaway `workflow {}` to make it "runnable."

## take / main / emit

- `take:` lists every input channel with a one-line `//` comment giving its shape,
  e.g. `reads_ch // tuple (sampleid, r1, r2)`.
- Reference databases / shared resources are separate `..._ch` inputs (already
  `.collect()`ed by the caller), never folded into the per-sample tuple — same
  rule as the module convention.
- Every `emit:` gets a descriptive name and a shape comment, same as a module's
  `output:`.
- Preserve `sampleid` through every channel inside the subworkflow so channels can
  be `.join()`ed later. If a process's own output doesn't carry it, `.map` it back
  in immediately after that call — don't let it drop for more than one step.
- Combine channels from different processes with `.join()` on sampleid, not
  positional zipping. Channels don't always emit in the same order; `.join()`
  fails loudly on a missing key instead of silently misaligning rows.

## Metrics — a subworkflow that benchmarks a tool exposes a `metrics` output

This pipeline's whole point is comparing viral-inference tools, so a subworkflow
that runs one is expected to report on how well it did, not just pass its main
output downstream:

- Compute metrics from files the subworkflow's own processes already produced.
  Don't have a shared module write metrics-specific output — that pollutes a
  module the rest of the lab uses with this pipeline's concerns. Do the
  parsing/summarizing in a **local** process (`modules/local/`), calling a script
  in `bin/` for anything beyond trivial shell.
- Emit `metrics` as `tuple(sampleid, "<tab-separated row>")`. This keeps rows
  joinable across subworkflows with a plain `.join()` in the parent workflow — no
  ragged-shape tuples to unpack later. Document the column order in a comment
  next to the `emit:` line, e.g.
  `// (sampleid, "n_contigs\tn_viral\tmean_completeness\tmean_coverage")`.
- Any hard-coded QC threshold (minimum reads retained, minimum viral hits, etc.)
  is a `params.qc_*` value defined in the pipeline's own `.config`, never a
  literal buried in the subworkflow — someone re-running this benchmark on
  different data needs to change it without editing code.
- When a sample crosses a bad threshold, `log.warn` *inside the subworkflow*, at
  the point the metric is computed. That surfaces the problem live in the run
  console instead of only in a report someone has to remember to open later.
  Don't fail/exit the run over a QC threshold — benchmarking bad samples is often
  exactly the point.
- The parent workflow merges every subworkflow's `metrics` channel into one table
  (`.join()` chain + `collectFile`) — a subworkflow never writes its own final
  summary file.

## Resource metrics (the other kind)

Per-process CPU/memory/time/exit-status is handled once, centrally, via
`trace`/`report`/`timeline` in the repo-wide `nextflow.config` — a subworkflow
never needs its own resource-tracking code. If you add a per-sample process, give
it `tag "${sampleid}"` (in the module file, not the subworkflow) so trace/report
rows are identifiable by sample instead of by task hash.

## Checklist before considering a subworkflow done

1. Filename, workflow name, and every `include{}` alias that will reference it all
   match exactly.
2. No stray top-level `workflow {}` in the file.
3. `take:` inputs and `emit:` outputs each have a one-line shape comment.
4. `sampleid` survives every channel; channels are combined with `.join()`, not
   positional zip.
5. If this subworkflow benchmarks a tool, it emits `metrics` as
   `(sampleid, tab-separated row)`, computed by a local process/script, with
   `log.warn` on any `params.qc_*` threshold crossed.
6. Verified with `nextflow run <file>.nf` standalone — passes if the only error is
   a missing required parameter, not a compile/syntax error.
