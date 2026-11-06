#!/usr/bin/env nextflow


// Index a reference sequence with bwa; emits the reference together with its index files
 process bwa_index {
    label "process_single"
    label "publish_intermediate_pooled"
    container "${params.container__bwa}"
    // One index for the whole run (e.g. a pooled viral catalog, or a host
    // genome): pooledid names that reference and is what the
    // publish_*_pooled labels pass to params.bwa_index_outdir. Drop it before
    // combining with per-sample reads for bwa_mem, e.g.
    // reads.combine(bwa_index.out.indexed_sequence.map { _id, ref, idx -> tuple(ref, idx) })

    input:
        tuple val(pooledid), path(reference_genome)

    output:
        tuple val(pooledid), path(reference_genome), path("${reference_genome}.{amb,ann,bwt,pac,sa}"), emit: indexed_sequence

    shell:
    '''
    bwa index !{reference_genome}
    '''
}

// Align paired-end reads to a reference indexed by bwa_index (see bwa_index for how to combine its output with reads)
process bwa_mem {
    label "process_high"
    container "${params.container__bwa}"

    input:
        // index_prefix is bwa_index's FASTA: bwa never reads it, but its name is the prefix of the
        // staged index files (genome.fa -> genome.fa.{amb,ann,bwt,pac,sa})
        tuple val(sampleid), path(clean_r1), path(clean_r2), path(index_prefix), path(index_files)

    output:
        tuple val(sampleid), path("${sampleid}.sam"), emit: sam_file

    shell:
    '''
    bwa mem -t !{task.cpus} !{index_prefix} !{clean_r1} !{clean_r2} > !{sampleid}.sam
    '''
}

// Align paired-end reads to a reference genome with bwa mem (indexing the reference first)
process bwa_align_paired_end {
    label "process_high"
    container "${params.container__bwa}"

    input:
        path(reference_genome)
        tuple val(sampleid), path(reads_r1), path(reads_r2)

    output:
        tuple val(sampleid), path("${sampleid}.sam"), emit: sam_file

    shell:
    '''
    bwa index !{reference_genome}
    bwa mem -t !{task.cpus} !{reference_genome} !{reads_r1} !{reads_r2} > !{sampleid}.sam
    '''
}

// Align single-end reads to a reference genome with bwa mem (indexing the reference first)
process bwa_align_single_end {
    label "process_high"
    container "${params.container__bwa}"

    input:
        path(reference_genome)
        tuple val(sampleid), path(reads_r1)

    output:
        tuple val(sampleid), path("${sampleid}.sam"), emit: sam_file

    shell:
    '''
    bwa index !{reference_genome}
    bwa mem -t !{task.cpus} !{reference_genome} !{reads_r1} > !{sampleid}.sam
    '''
}

// Align paired-end reads to a pre-built bwa index (packaged as a tarball)
process bwa_align_to_index {
    label "process_high"
    container "${params.container__bwa}"

    input:
        path(bwa_index_tarball)
        tuple val(sampleid), path(reads_r1), path(reads_r2)

    output:
        tuple val(sampleid), path("${sampleid}.sam"), emit: sam_file

    shell:
    '''
    mkdir index
    # The tarball (gzipped or not) must hold ref.fa and its bwa index files at its top level
    tar -xvf !{bwa_index_tarball} -C index
    if [ ! -f index/ref.fa ]; then
        echo "ERROR: !{bwa_index_tarball} has no ref.fa at its top level; expected ref.fa and its bwa index files (ref.fa.amb, .ann, .bwt, .pac, .sa)" >&2
        exit 1
    fi

    bwa mem -t !{task.cpus} index/ref.fa !{reads_r1} !{reads_r2} > !{sampleid}.sam
    '''
}
