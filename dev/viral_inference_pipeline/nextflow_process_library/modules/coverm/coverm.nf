#!/usr/bin/env nextflow

// Run with: assuming some upstream channel emits (sampleid, bam) tuples
//   bam_ch
//     .map { sampleid, bam -> bam }
//     .collect()
//     .map { bams -> tuple('count_table', bams) }   // pooledid
//     .set { all_bams }
//   coverm(all_bams)

// Estimating relative abundance of vOTUs with CoverM (merged across all BAMs)
process coverm {
    label "process_medium"
    label "publish_final_pooled"
    container "${params.container__coverm}"
    // Merges all sample BAMs into ONE count table: pooledid names that pooled
    // output (e.g. 'count_table'); it is both the output file name and what
    // the publish_*_pooled labels pass to params.coverm_outdir.

    input:
        tuple val(pooledid), path(bam_files)

    output:
        tuple val(pooledid), path("${pooledid}.txt"), emit: count_table

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
    > !{pooledid}.txt
    '''
}