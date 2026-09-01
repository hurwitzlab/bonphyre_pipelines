#!/usr/bin/env nextflow


// Infer class of sequences using deepmicroclass 
 process deepmicroclassr {
    container "${params.container__deepmicroclass}"
    publishDir "${params.deepmicroclass_outdir}", mode: 'copy'
                        
    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("${sampleid}/"), emit: inferences

    shell:
    '''
    DeepMicroClass predict \
    --input !{contigs} \
    --output_dir !{sampleid} \
    [--model MODEL] \
    [--encoding {onehot,embedding}] \
    [--mode {hybrid,single}] \
    [--single-len SINGLE_LEN] \
    --device {cpu,cuda}

    '''