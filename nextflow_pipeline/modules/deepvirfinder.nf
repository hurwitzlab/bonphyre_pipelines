#!/usr/bin/env nextflow


// Infer viral sequences using deepvirfinder 
 process deepvirfinder {
    container "${params.container__deepvirfinder}"
    publishDir "${params.deepvirfinder_outdir}", mode: 'copy'
                        
    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("${sampleid}/"), emit: viral_inferences

    shell:
    '''
    dvf.py \
    -i !{contigs} \
    -o !{sampleid}  \
    -l !{params.viralinference_minlength} \
    -c !{task.cpus}
    '''