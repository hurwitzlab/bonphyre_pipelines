#!/usr/bin/env nextflow


// Infering viral sequences with seeker
 process seeker {
    label "process_medium"
    label "publish_final"
    container "${params.container__seeker}"
                        
    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("bins_folder/Results/phage_genomes"), emit: viral_inferences

    shell:
    '''
    predict-metagenome !{contigs}
    '''
}
