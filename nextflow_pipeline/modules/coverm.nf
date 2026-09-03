#!/usr/bin/env nextflow

// Run with: assuming some upstream channel emits (sampleid, bam) tuples
//   bam_ch
//     .map { sampleid, bam -> bam }
//     .collect()
//     .set { all_bams }
//   coverm(all_bams)

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
    # coverm_sequence: sequence type
    # coverm_m: metric, e.g. count
    # coverm_minident: min-read-percent-identity, e.g. 0.95
    # coverm_minlen: min-read-aligned-length, e.g. 45
    coverm !{params.coverm_sequence} \
    -b !{bam_files} \
    -t !{task.cpus} \
    -m !{params.coverm_m} \
    --min-read-percent-identity !{params.coverm_minident} \
    --min-read-aligned-length !{params.coverm_minlen} \
    > votus_count_table.txt
    '''
}