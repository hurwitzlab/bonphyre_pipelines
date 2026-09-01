#!/usr/bin/env nextflow


// Infer viral sequences using virsorter2
 process virsorter2 {
    container "${params.container__virsorter2}"
    publishDir "${params.virsorter2_outdir}", mode: 'copy'
                        
    input:
        tuple val(sampleid), path(contigs)
        path(virsorter2_db)

    output:
        tuple val(sampleid), path("${sampleid}/"), emit: viral_inferences

    shell:
    '''
    virsorter run \
    -w !{sampleid} \
    -i !{contigs} \
    -j !{task.cpus} \
    all \
    --min-length !{params.viralinference_minlength}  # 1500
    '''