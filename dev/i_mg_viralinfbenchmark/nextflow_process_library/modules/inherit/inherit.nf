#!/usr/bin/env nextflow


// Infering viral sequences with inherit
 process seeker {
    label "process_medium"
    label "publish_final"
    container "${params.container__inherit}"
                        
    input:
        tuple val(sampleid), path(contigs)
        path model

    output:
        tuple val(sampleid), path("${sampleid}_out"), emit: viral_inferences

    shell:
    '''
    inherit \
          --sequence !{contigs} \
          --withpretrain !{params.inherit_withpretrain} \
          --model !{model} \   
          --out !{sampleid}_out
    '''
}
