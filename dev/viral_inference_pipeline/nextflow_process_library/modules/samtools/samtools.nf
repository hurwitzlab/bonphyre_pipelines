#!/usr/bin/env nextflow

// Convert SAM to BAM, excluding unmapped reads (-F 4)
process sam_to_bam {
    label "process_single"
    container "${params.container__samtools}"

    input:
        tuple val(sampleid), path(sam_file)

    output:
        tuple val(sampleid), path("${sampleid}.raw.bam"), emit: bam_file

    shell:
    '''
    samtools view -@ !{task.cpus} -F 4 -bo !{sampleid}.raw.bam !{sam_file}
    '''
}

// Sort a BAM file by coordinate
process sort_bam {
    label "process_single"
    container "${params.container__samtools}"

    input:
        tuple val(sampleid), path(bam_file)

    output:
        tuple val(sampleid), path("${sampleid}.sorted.bam"), emit: sorted_bam

    shell:
    '''
    samtools sort -@ !{task.cpus} -m !{task.memory.toMega() / task.cpus as int}M -o !{sampleid}.sorted.bam !{bam_file}
    '''
}


// Index a sorted BAM file
process index_bam {
    label "process_single"
    label "publish_final"
    container "${params.container__samtools}"

    input:
        tuple val(sampleid), path(sorted_bam)

    output:
        tuple val(sampleid), path("${sorted_bam}"), path("${sorted_bam}.bai"), emit: mapped_files

    shell:
    '''
    samtools index !{sorted_bam}
    '''
}

// Index a sample's alignment file (BAM/SAM/CRAM), preserving it alongside its index
process index {
    label "process_single"
    label "publish_final"
    container "${params.container__samtools}"

    input:
        tuple val(sampleid), path(alignment_file)

    output:
        tuple val(sampleid), path("${alignment_file}"), path("${alignment_file}.bai"), emit: indexed_alignment

    shell:
    '''
    samtools index -@ !{task.cpus} -b !{alignment_file} !{alignment_file}.bai
    '''
}

// Convert a sample's alignment file (BAM/SAM/CRAM) to BAM and index it
process to_bam {
    label "process_single"
    container "${params.container__samtools}"

    input:
        tuple val(sampleid), path(alignment_file)

    output:
        tuple val(sampleid), path("${sampleid}.bam"),     emit: bam_file
        tuple val(sampleid), path("${sampleid}.bam.bai"), emit: bam_index

    shell:
    '''
    samtools view -@ !{task.cpus} -Sb !{alignment_file} > !{sampleid}.bam
    samtools index -@ !{task.cpus} -b !{sampleid}.bam !{sampleid}.bam.bai
    '''
}

// Keep only mapped reads from a sample's alignment file
process mapped_reads_to_bam {
    label "process_single"
    container "${params.container__samtools}"

    input:
        tuple val(sampleid), path(alignment_file)

    output:
        tuple val(sampleid), path("${sampleid}.mapped.bam"), emit: mapped_bam

    shell:
    '''
    samtools view -@ !{task.cpus} -b -F 4 !{alignment_file} > !{sampleid}.mapped.bam
    '''
}

// Keep only unmapped reads from a sample's alignment file
process unmapped_reads_to_bam {
    label "process_single"
    container "${params.container__samtools}"

    input:
        tuple val(sampleid), path(alignment_file)

    output:
        tuple val(sampleid), path("${sampleid}.unmapped.bam"), emit: unmapped_bam

    shell:
    '''
    samtools view -@ !{task.cpus} -b -f 4 !{alignment_file} > !{sampleid}.unmapped.bam
    '''
}

// Sort a sample's alignment file by coordinate
process sort_to_bam {
    label "process_single"
    container "${params.container__samtools}"

    input:
        tuple val(sampleid), path(alignment_file)

    output:
        tuple val(sampleid), path("${sampleid}.sorted.bam"), emit: sorted_bam

    shell:
    '''
    samtools sort -@ !{task.cpus} -O bam -o !{sampleid}.sorted.bam !{alignment_file}
    '''
}

// Sort a sample's alignment file by read name
process sort_by_name_to_bam {
    label "process_single"
    container "${params.container__samtools}"

    input:
        tuple val(sampleid), path(alignment_file)

    output:
        tuple val(sampleid), path("${sampleid}.sorted_by_name.bam"), emit: sorted_by_name_bam

    shell:
    '''
    samtools sort -@ !{task.cpus} -n -O bam -o !{sampleid}.sorted_by_name.bam !{alignment_file}
    '''
}

// Index a sample's FASTA, preserving it alongside its .fai index
process fasta_index {
    label "process_single"
    label "publish_final"
    container "${params.container__samtools}"

    input:
        tuple val(sampleid), path(fasta_file)

    output:
        tuple val(sampleid), path("${fasta_file}"), path("${fasta_file}.fai"), emit: indexed_fasta

    shell:
    '''
    samtools faidx --output !{fasta_file}.fai !{fasta_file}
    '''
}

// Convert a sample's name-sorted, paired-end BAM to FASTQ
process bam_to_fastq {
    label "process_single"
    container "${params.container__samtools}"

    input:
        tuple val(sampleid), path(sorted_bam)

    output:
        tuple val(sampleid), path("${sampleid}_R1.fq.gz"), emit: r1_reads
        tuple val(sampleid), path("${sampleid}_R2.fq.gz"), emit: r2_reads

    shell:
    '''
    samtools fastq -@ !{task.cpus} -1 !{sampleid}_R1.fq.gz -2 !{sampleid}_R2.fq.gz -0 /dev/null -s /dev/null !{sorted_bam}
    '''
}

// Convert a sample's name-sorted, single-end BAM to FASTQ
process bam_to_fastq_single_end {
    label "process_single"
    container "${params.container__samtools}"

    input:
        tuple val(sampleid), path(sorted_bam)

    output:
        tuple val(sampleid), path("${sampleid}_R1.fq.gz"),        emit: r1_reads        // no reads normally written
        tuple val(sampleid), path("${sampleid}_R2.fq.gz"),        emit: r2_reads        // no reads normally written
        tuple val(sampleid), path("${sampleid}_single.fq.gz"),    emit: single_end_reads // all single-end reads are written here

    shell:
    '''
    samtools fastq -@ !{task.cpus} \
                   -1 !{sampleid}_R1.fq.gz \
                   -2 !{sampleid}_R2.fq.gz \
                   -0 !{sampleid}_single.fq.gz \
                   -s /dev/null \
                   !{sorted_bam}
    '''
}
