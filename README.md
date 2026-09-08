# viral_inference_benchmark
Repository of the viral inference tool benchmark.

The Nextflow pipelines themselves live under `nextflow_pipeline/` — see
[`nextflow_pipeline/README.md`](nextflow_pipeline/README.md) for how to run
one, how the config layers work, and how tool modules are shared via the
sibling [`nextflow_modules`](https://github.com/hurwitzlab/nextflow_modules)
repo.

## Contributing

This repo gets edited concurrently — by different lab members, and often by
more than one Claude Code session at once. That's exactly how a subworkflow
ended up with a workflow name that didn't match its own filename or the
`include{}` alias used to call it, and how code referenced `.out.` emit
names (`megahit.out.assembled_contigs`, `trimmomatic.out.filtered_reads`)
that didn't actually exist on the process being called. Before editing a
subworkflow, module, or config here:

1. Check that the workflow name declared inside a subworkflow file matches
   its filename and every `include{}` alias that references it elsewhere —
   a mismatch compiles fine in isolation and only breaks (or silently calls
   the wrong thing) once something else includes it.
2. Check any `.out.<emit_name>` you reference actually exists — grep the
   `emit:` lines of the module/subworkflow you're calling rather than
   assuming a name.
3. Follow `nextflow_pipeline/subworkflows/CLAUDE.md` and `TEMPLATE.nf` for
   new subworkflows. Follow shared `nextflow_modules`' own
   `modules/CLAUDE.md` for tool modules there, and keep anything specific to
   this benchmark (QC/metrics logic, thresholds) in this repo's own
   `nextflow_pipeline/modules/local/` — never in the shared module repo.
4. Verify a changed subworkflow standalone with `nextflow run <file>.nf` —
   it should fail only on a missing required parameter, not a compile error.

## Working on this repo

Whatever you change here — a subworkflow, a config, `CLAUDE.md`, this
README, anything — **record it in `NOTEBOOK.md` before you're done**, not
just in the commit message. The commit says *what* changed; the notebook
says *why* and *what happened* (results, errors, decisions, flags for
whoever picks this up next), which is exactly the context a diff can't carry
on its own.

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

### A prompt to record your session

If you're using Claude Code (or a similar assistant) here, `/notebook` alone
does this. If you're prompting a general assistant, or want to be explicit
about what you expect, something like this works:

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
```
