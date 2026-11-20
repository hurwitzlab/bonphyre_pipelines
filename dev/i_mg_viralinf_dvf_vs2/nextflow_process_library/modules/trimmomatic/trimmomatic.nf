!/usr/bin/env nextflow

// Run Trimmomatic 
process trimmomatic {
    label "process_medium"
    container "${params.container_trimmomatic}"

    input:
        tuple val(sampleid), path(r1), path(r2)
        path(adapters) from params.trimmomatic_adapters

    output:
        tuple val(sampleid), path("${sampleid}_R1_trimmed.fastq.gz"), emit: trimmed_r1
        tuple val(sampleid), path("${sampleid}_R2_trimmed.fastq.gz"), emit: trimmed_r2

shell:
    '''
    trimmomatic PE \
    -threads !{task.cpus} \
    !{untrimmed_r1} \
    !{untrimmed_r2} \
    !{sampleid}_R1_trimmed.fastq.gz \
    !{sampleid}_R1_unpaired.fastq.gz \
    !{sampleid}_R2_trimmed.fastq.gz \
    !{sampleid}_R2_unpaired.fastq.gz \
    ILLUMINACLIP:!{params.trimmomatic_adapters}:2:30:10 \
    LEADING: !{params.trimming_leading} \
    TRAILING: !{params.trimming_trailing} \
    SLIDINGWINDOW: !{params.trimming_slidingwindow} \
    MINLEN: !{params.trimming_minlen} \
    '''
}
