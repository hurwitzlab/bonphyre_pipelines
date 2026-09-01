#!/usr/bin/env nextflow


// Calculate sequence abundance from mapping with coverm
 process coverm {
    container "${params.container__coverm}"
    publishDir "${params.coverm_outdir}", mode: 'copy'
                        
    input:
        path(mapped_sequences_dir)

    output:
        path("abundance_table.tsv"), emit: abundance_table

    shell:
    '''

    '''