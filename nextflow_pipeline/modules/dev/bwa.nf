#!/usr/bin/env nextflow


// Mapped reads to sequences with bwa
 process bwa {
    container "${params.container__bwa}"
    publishDir "${params.bwa_outdir}", mode: 'copy'
                        
    input:
        tuple val(sampleid), path(clean_r1), path(clean_r2), path(sequence_to_map)

    output:
        tuple val(sampleid), path("${sampleid}/"), path("${sampleid}/"), emit: mapped_files

    shell:
    '''

    '''
}