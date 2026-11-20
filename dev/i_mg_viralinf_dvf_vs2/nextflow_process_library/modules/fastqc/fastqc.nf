#!/usr/bin/env nextflow

// Run FastQC on one or more FASTQ files (single-end or paired-end)
process fastqc {
    label "process_low"
    container "${params.container_fastqc}"

    input:
        tuple val(sampleid), path(r1), path(r2)

    output:
        tuple val(sampleid), path("${sampleid}_*_fastqc.zip"), emit: zip_files
        tuple val(sampleid), path("${sampleid}_*_fastqc.html"), emit: html_files

    shell:
    '''
    fastqc \
    !{r1} \
    !{r2} \
    --outdir . \
    --threads !{task.cpus}
    '''
}
