#!/usr/bin/env nextflow


// Infering viruses and plasmids from assembled contigs with geNomad
 process genomad {
    label "process_high"
    label "publish_final"
    container "${params.container__genomad}"

    input:
        tuple val(sampleid), path(contigs)
        path(genomad_db)

    output:
        tuple val(sampleid), path("contigs_summary"), emit: inferences

    shell:
    '''
    genomad end-to-end \
    !{contigs} \
    . \
    !{genomad_db} \
    --threads !{task.cpus}
    '''
}
