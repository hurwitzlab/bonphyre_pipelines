#!/usr/bin/env nextflow

// Classify sequence fragments as viral/non-viral with ViraLM (DNABERT-2 based)
//
// CAVEAT: same ENTRYPOINT caveat as deepmicroclass2.nf — the source script runs
// this container with `apptainer run`, relying on its ENTRYPOINT to interpret
// `--input ... --output ... --database ...`. Nextflow's container directive uses
// `apptainer exec` and will not invoke that ENTRYPOINT. The binary name below is
// a placeholder — confirm the real entrypoint command before relying on this
// module.
 process viralm {
    label "process_medium"
    label "publish_final"
    container "${params.container__viralm}"
    containerOptions '--nv'

    input:
        tuple val(sampleid), path(contigs)
        path(viralm_db)

    output:
        tuple val(sampleid), path("${sampleid}"), emit: classification

    shell:
    '''
    ViraLM \
    --input !{contigs} \
    --output !{sampleid} \
    --database !{viralm_db} \
    --len !{params.viralm_minlen} \
    --threshold !{params.viralm_threshold} \
    --force
    '''
}
