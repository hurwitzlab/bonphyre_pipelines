#!/usr/bin/env nextflow


// Infering viruses and plasmids from assembled contigs with geNomad
 process genomad {
    container "${params.container__genomad}"
    publishDir "${params.genomad_outdir}", mode: 'copy'
                        
    input:
        tuple val(sampleid), path(contigs)
        path(genomad_db)

    output:
        tuple val(sampleid), path("${sampleid}/contigs_summary"), emit: inferences

    shell:
    '''
    genomad end-to-end \
    !{contigs} \
    !{sampleid} \
    !{genomad_db} \
    --threads !{task.cpus}
    '''
}
