# NF pipelines work by Mery

The Nextflow pipelines themselves live under `nextflow_pipelines/` — see
[`nextflow_pipelines/README.md`](nextflow_pipelines/README.md) for how to run
one, how the config layers work, and how tool modules are shared via the
sibling [`nextflow_process_library`](https://github.com/hurwitzlab/nextflow_process_library)
repo.

## Contributing

This repo gets edited concurrently by different lab members, and often by
more than one Claude Code session at once. Before editing a
subworkflow, module, or config here:

1. Follow `nextflow_pipelines/subworkflows/CLAUDE.md` and `TEMPLATE.nf` for
   new subworkflows.
2. Follow shared `nextflow_process_library`'s own
   `modules/CLAUDE.md` for tool modules there, and keep anything specific to
   this benchmark (QC/metrics logic, thresholds) in this repo's own
   `nextflow_pipelines/modules/local/` — never in the shared module repo.
3. Verify a changed subworkflow standalone with `nextflow run <file>.nf` —
   it should fail only on a missing required parameter, not a compile error.
4. Whatever you change here — a subworkflow, a config, `CLAUDE.md`, this
   README, anything — **record it in `NOTEBOOK.md` before you're done** (see below), not
   just in the commit message. The commit says *what* changed; the notebook
   says *why* and *what happened* (results, errors, decisions, flags for
   whoever picks this up next). 

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

If you are using Claude code this is an suggested prompt: 
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
