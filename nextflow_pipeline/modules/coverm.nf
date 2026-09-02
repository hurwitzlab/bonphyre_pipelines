#!/usr/bin/env nextflow
//run with: 
//    // assuming some upstream channel emits (sampleid, bam) tuples
    // bam_ch
    //     .map { sampleid, bam -> bam }
    //     .collect()
    //     .set { all_bams }

    // coverm(all_bams)

// Estimating relative abundance of vOTUs with CoverM (merged across all BAMs)
process coverm {
    container "${params.container__coverm}"
    publishDir "${params.coverm_outdir}", mode: 'copy'

    input:
        path(bam_files)

    output:
        path("votus_count_table.txt"), emit: count_table

    shell:
    '''
    coverm !{params.coverm_sequence} \ # sequence type
    -b !{bam_files} \
    -t !{task.cpus} \
    -m !{params.coverm_m} \ #count
    --min-read-percent-identity !{params.coverm_minident} \ # 0.95
    --min-read-aligned-length !{params.coverm_minlen} \      # 45
    > votus_count_table.txt
    '''
}