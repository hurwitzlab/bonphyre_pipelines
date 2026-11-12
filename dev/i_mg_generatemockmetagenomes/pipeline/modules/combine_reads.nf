#!/usr/bin/env nextflow

// Shuffle one condition's viral spike-in reads (art_illumina, joined per condition) together with a background read pair (combine_reads.py).
// Viral and background reads must have the same read length; the script exits nonzero otherwise.
process combine_reads {
    label "process_low"
    label "publish_intermediate"
    container "${params.container__combine_reads}"

    input:
        tuple val(sampleid), path(viral_r1), path(viral_r2), path(background_r1), path(background_r2)

    output:
        tuple val(sampleid), path("${sampleid}.1.fq.gz"), path("${sampleid}.2.fq.gz"), emit: reads

    shell:
    '''
    combine_reads.py \
    -R1 !{viral_r1} \
    -R2 !{viral_r2} \
    -B1 !{background_r1} \
    -B2 !{background_r2} \
    -o !{sampleid}
    '''
}
