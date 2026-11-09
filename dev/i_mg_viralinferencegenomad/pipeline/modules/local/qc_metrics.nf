#!/usr/bin/env nextflow

// Metric and parsing processes local to this pipeline

// Count reads in a fastq file with seqkit, tagged by QC stage (e.g. "raw", "clean")
process seqkit_stats {
    label "process_single"
    container "${params.container__seqkit}"
    tag "${sampleid}_${stage}"

    input:
        tuple val(sampleid), path(reads)
        val(stage)

    output:
        tuple val(sampleid), env('READ_COUNT'), emit: read_count

    shell:
    '''
    seqkit stats -T !{reads} > stats.tsv
    READ_COUNT=$(tail -n 1 stats.tsv | cut -f4)
    '''
}

// Summarize genomad + checkv + coverage + filter/extract output into one row of viral-inference yield metrics
process summarize_viral_filter {
    label "process_single"
    container "${params.container__metrics}"
    tag "${sampleid}"

    input:
        tuple val(sampleid), path(contigs), path(checkv_quality_summary), path(coverage), path(viral_selection), path(viral_fasta), path(provirus_fasta)

    output:
        tuple val(sampleid), env('METRICS_ROW'), emit: summary

    shell:
    '''
    summarize_viral_filter.py \
        --contigs !{contigs} \
        --checkv !{checkv_quality_summary} \
        --coverage !{coverage} \
        --viral-selection !{viral_selection} \
        --viral-fasta !{viral_fasta} \
        --provirus-fasta !{provirus_fasta} \
        --outfile summary.tsv

    METRICS_ROW=$(cat summary.tsv)
    '''
}

