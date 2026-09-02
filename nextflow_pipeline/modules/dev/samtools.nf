#!/usr/bin/env nextflow

// Convert SAM to BAM, excluding unmapped reads (-F 4)
process sam_to_bam {
    container "${params.container__bwa}"

    input:
        tuple val(sampleid), path(sam_file)

    output:
        tuple val(sampleid), path("${sampleid}.raw.bam"), emit: bam_file

    script:
    """
    samtools view -@ ${task.cpus} -F 4 -bo ${sampleid}.raw.bam ${sam_file}
    """
}

// Sort a BAM file by coordinate
process sort_bam {
    container "${params.container__bwa}"

    input:
        tuple val(sampleid), path(bam_file)

    output:
        tuple val(sampleid), path("${sampleid}.sorted.bam"), emit: sorted_bam

    script:
    """
    samtools sort -@ ${task.cpus} -m ${task.memory.toMega() / task.cpus as int}M -o ${sampleid}.sorted.bam ${bam_file}
    """
}


// Index a sorted BAM file
process index_bam {
    container "${params.container__bwa}"
    publishDir "${params.bwa_outdir}", mode: 'copy'

    input:
        tuple val(sampleid), path(sorted_bam)

    output:
        tuple val(sampleid), path("${sorted_bam}"), path("${sorted_bam}.bai"), emit: mapped_files

    script:
    """
    samtools index ${sorted_bam}
    """
}