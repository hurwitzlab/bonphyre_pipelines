#!/usr/bin/env nextflow


// Estimating viral inference quality with CheckV
 process checkv {
    container "${params.container__checkv}"
    publishDir "${params.checkv_outdir}", mode: 'copy'
                        
    input:
        tuple val(sampleid), path(inferred_sequences)
        path(checkv_db)

    output:
        tuple val(sampleid), path("${sampleid}"), emit: quality_assessment

    shell:
    '''
    checkv end_to_end \
    !{inferred_sequences} \
    !{sampleid} \
    --threads !{task.cpus} \
    --db !{checkv_db}
    '''
}
