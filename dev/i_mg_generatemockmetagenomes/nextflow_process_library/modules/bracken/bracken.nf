#!/usr/bin/env nextflow

// Re-estimate species abundance from a kraken2 report with bracken
 process bracken {
    label "process_single"
    label "publish_final"
    container "${params.container__bracken}"

    input:
        tuple val(sampleid), path(kreport)
        path(kraken2_db)

    output:
        tuple val(sampleid), path("${sampleid}.bracken"), emit: abundance_table

    shell:
    '''
    bracken \
    -d !{kraken2_db} \
    -i !{kreport} \
    -o !{sampleid}.bracken \
    -r !{params.bracken_readlen}
    '''
}

// Build Bracken's kmer-distribution file for a kraken2 database
process bracken_build {
    label "process_high"
    container "${params.container__bracken}"
    publishDir "${params.bracken_build_outdir}", mode: 'copy'

    input:
        path(kraken2_db)
        val(read_len)

    output:
        path("${kraken2_db}/database${read_len}mers.kmer_distrib"), emit: kmer_distrib

    shell:
    '''
    bracken-build \
    -d !{kraken2_db} \
    -t !{task.cpus} \
    -k !{params.bracken_build_kmer_len} \
    -l !{read_len}
    '''
}
