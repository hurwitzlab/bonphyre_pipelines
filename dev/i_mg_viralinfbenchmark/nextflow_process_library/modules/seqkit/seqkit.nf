#!/usr/bin/env nextflow

// Remove duplicate sequences from a protein FASTA using SeqKit
process deduplicate_sequences {
    label "process_medium"
    container "${params.container__seqkit}"

    input:
        path(query_faa)

    output:
        path "query_dedup.faa", emit: deduplicated_sequences

    shell:
    '''
    seqkit rmdup -j !{task.cpus} --by-seq !{query_faa} | seqkit seq -j !{task.cpus} --only-id > query_dedup.faa
    '''
}

// Keep sequences at least min_length bp long using SeqKit (for tools with no length option, e.g. seeker)
process filter_min_length {
    label "process_low"
    container "${params.container__seqkit}"

    input:
        tuple val(sampleid), path(contigs)
        val(min_length)

    output:
        tuple val(sampleid), path("${sampleid}_min${min_length}.fa"), emit: filtered_sequences

    shell:
    '''
    seqkit seq -j !{task.cpus} -m !{min_length} !{contigs} > !{sampleid}_min!{min_length}.fa
    '''
}
