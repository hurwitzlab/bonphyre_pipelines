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


// Count primary reads going into bwa mem and how many of them mapped, from the raw bwa SAM
// (before sam_to_bam drops unmapped reads). Primary counts exclude secondary/supplementary
// alignments, so each read is counted once (R1 and R2 counted separately). Needs samtools >= 1.13.
process mapping_stats {
    label "process_single"
    container "${params.container__samtools}"
    tag "${sampleid}"

    input:
        tuple val(sampleid), path(sam_file)

    output:
        tuple val(sampleid), env('MAPPING_ROW'), emit: mapping_counts

    shell:
    '''
    samtools flagstat -@ !{task.cpus} -O tsv !{sam_file} > flagstat.tsv
    TOTAL=$(awk -F'\\t' '$3 == "primary"        { print $1 }' flagstat.tsv)
    MAPPED=$(awk -F'\\t' '$3 == "primary mapped" { print $1 }' flagstat.tsv)
    if [ -z "$TOTAL" ] || [ -z "$MAPPED" ]; then
        echo "ERROR: could not find 'primary'/'primary mapped' rows in samtools flagstat output (samtools >= 1.13 required)" >&2
        exit 1
    fi
    MAPPING_ROW="${TOTAL}	${MAPPED}"
    '''
}
