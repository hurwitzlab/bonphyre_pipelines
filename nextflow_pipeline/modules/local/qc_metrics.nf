#!/usr/bin/env nextflow

// Benchmark/QC metric processes local to this pipeline (not shared via
// nextflow_modules, since these encode this repo's own benchmark logic —
// see subworkflows/CLAUDE.md).

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

// Summarize genomad + checkv + coverage output into one row of viral-inference yield metrics
process summarize_viral_filter {
    label "process_single"
    container "${params.container__metrics}"
    tag "${sampleid}"

    input:
        tuple val(sampleid), path(contigs), path(checkv_quality_summary), path(coverage)

    output:
        tuple val(sampleid), env('METRICS_ROW'), emit: summary

    shell:
    '''
    summarize_viral_filter.py \
        --contigs !{contigs} \
        --checkv !{checkv_quality_summary} \
        --coverage !{coverage} \
        --outfile summary.tsv

    METRICS_ROW=$(cat summary.tsv)
    '''
}
