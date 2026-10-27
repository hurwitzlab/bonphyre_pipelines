#!/usr/bin/env nextflow

// Quality-trim paired reads with trimmomatic
 process trimmomatic {
    label "publish_final"
    label "process_low"
    container "${params.container__trimmomatic}"

    input:
        tuple val(sampleid), path(untrimmed_r1), path(untrimmed_r2)

    output:
        tuple val(sampleid), path("${sampleid}_clean_r1.fastq.gz"), path("${sampleid}_clean_r2.fastq.gz"), emit: clean_reads

    shell:
    '''
    trimmomatic PE \
    -threads !{task.cpus} \
    !{untrimmed_r1} \
    !{untrimmed_r2} \
    !{sampleid}_clean_r1.fastq.gz \
    !{sampleid}_unpaired_r1.fastq.gz \
    !{sampleid}_clean_r2.fastq.gz \
    !{sampleid}_unpaired_r2.fastq.gz \
    LEADING:!{params.trimmomatic_leading} \
    TRAILING:!{params.trimmomatic_trailing} \
    SLIDINGWINDOW:!{params.trimmomatic_slidingwindow} \
    MINLEN:!{params.trimmomatic_minlen}
    '''
}
