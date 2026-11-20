#!/usr/bin/env nextflow

// Infer viral (phage) contigs with Seeker; predictions are written to stdout (publish_final, like deepvirfinder)
process seeker {
    label "process_medium"
    label "publish_final"
    container "${params.container__seeker}"

    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("seeker_predictions.tsv"), emit: viral_inferences

    shell:
    '''
    predict-metagenome !{contigs} > seeker_predictions.tsv
    '''
}
