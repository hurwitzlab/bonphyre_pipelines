# Module conventions (nextflow_pipeline/modules)

Rules for writing/editing `.nf` module files in this directory, derived from the
existing modules (bbmap, bwa, checkv, coverm, deepvirfinder, genomad, marvel,
vibrant, virsorter2). Follow these for any new or edited module.

## File layout

- One file per tool, named `<tool>.nf` (lowercase, matches the binary/tool name).
- A tool with multiple steps gets multiple `process` blocks in the same file
  (e.g. `bbmap.nf` has `bbwrap` + `pileup`, `bwa.nf` has `bwa_index` + `bwa_mem`),
  not one file per process.
- File starts with `#!/usr/bin/env nextflow`, then a blank line.
- Do not add `nextflow.enable.dsl=2` to module files — that belongs in
  workflows/subworkflows, not individual modules.

## Process block

- One-line `//` comment directly above each `process` describing what it does
  in plain terms ("Infer viral sequences using X", "Align reads to contigs with X").
- Process name: lowercase, matches the tool/subcommand (`genomad`, `checkv`,
  `bwa_index`). Use `snake_case`, not `camelCase`.
- First line inside the block: `container "${params.container__<tool>}"`.
- If the process produces a result meant to persist (final per-sample output,
  a report, a summary), add:
  `publishDir "${params.<tool>_outdir}", mode: 'copy'`
  right after `container`. Skip `publishDir` for purely intermediate steps
  that only feed the next process (e.g. `bbwrap`'s raw alignment, `bwa_index`,
  `bwa_mem`'s raw `.sam`).

## Input / output

- Per-sample data flows as a tuple: `tuple val(sampleid), path(...)`.
- Reference databases / shared resources are separate `path(...)` inputs, not
  folded into the sample tuple (see `genomad`, `checkv`, `virsorter2`).
- Every output gets an explicit, descriptive `emit:` name — never leave it
  unnamed. Match the semantics, not the tool name: `viral_inferences`,
  `quality_assessment`, `count_table`, `sam_file`, `indexed_sequence`.
- Preserve `sampleid` through the output tuple whenever the process is
  per-sample, so downstream processes can keep joining on it.
- Be consistent about trailing slashes on directory-path outputs across a
  module set (pick one style, e.g. no trailing `/`, and use it everywhere).

## Shell block

- Use `shell:` + a `'''...'''` block with `!{...}` interpolation for
  Nextflow variables — this is the standard for every module here. Do **not**
  use `script:` + `"""..."""` with `${...}` interpolation (bwa_mem is the one
  exception in the current code and should be converted, not copied).
- Never put a `#` comment on a line that ends in a `\` continuation inside a
  shell block — the shell sees `\` + comment and breaks the command. Put
  comments on their own line above the command, or drop them.
- Thread/CPU count always comes from `task.cpus`, passed as whatever flag the
  tool uses (`-t`, `-c`, `-j`, `--threads`) — never hardcode a thread count.
- Always close every `process { ... }` block. Read the file back after
  writing it and confirm the final `}` is present — this repo has had modules
  committed with a missing closing brace.

## Params naming (used from `params.*` inside modules)

- Container: `container__<tool>` (double underscore).
- Output dir: `<tool>_outdir`.
- Tool options: `<tool>_<option>`, snake_case, matching the tool's own flag
  name where reasonable (e.g. `bbmap_kfilter`, `coverm_minident`,
  `vibrant_minlength`).
- Shared/global options (not tool-specific) go unprefixed, e.g.
  `params.viralinference_minlength` when several viral-inference tools share
  the same cutoff.
- Every param a module references must exist (or be addable) in the relevant
  workflow's `.config` file under `params { ... }` — don't invent a param
  name without adding it there too.

## Checklist before considering a module done

1. Shebang, comment, process name, container, (publishDir if terminal output).
2. Inputs as `tuple val(sampleid), path(...)` + separate db paths as needed.
3. Outputs all named via `emit:`, `sampleid` preserved.
4. `shell:` + `!{...}`, no `${...}` mixed in.
5. Threads from `task.cpus`.
6. No comments on `\`-continued shell lines.
7. Every `process` block's braces balance — count `{` vs `}`.
