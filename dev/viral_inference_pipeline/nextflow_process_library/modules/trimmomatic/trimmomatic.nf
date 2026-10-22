#!/usr/bin/env nextflow

// Quality-trim paired reads with trimmomatic
 process trimmomatic {
    label "publish_final"
    container "${params.container__trimmomatic}"

    input:
        tuple val(sampleid), path(bbduk_r1), path(bbduk_r2)

    output:
        tuple val(sampleid), path("clean_r1.fastq"), path("clean_r2.fastq"), emit: clean_reads

    shell:
    '''
    trimmomatic PE \
    -threads !{task.cpus} \
    !{bbduk_r1} \
    !{bbduk_r2} \
    clean_r1.fastq \
    unpaired_r1.fastq \
    clean_r2.fastq \
    unpaired_r2.fastq \
    LEADING:!{params.trimmomatic_leading} \
    TRAILING:!{params.trimmomatic_trailing} \
    SLIDINGWINDOW:!{params.trimmomatic_slidingwindow} \
    MINLEN:!{params.trimmomatic_minlen}
    '''
}
