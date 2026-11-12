#!/usr/bin/env nextflow

// Extract the representative genomes from one phoraged HumGut tarball shard as <genome_id>.fna (extract_humgut_phoraged.py).
// One task per shard, e.g. Channel.fromPath("/rs1/shares/brc/admin/databases/humgut_phoraged/HumGut_phoraged_*.tar.gz").
// A shard may hold none of the needed genomes, so the output is optional.
process extract_humgut_phoraged {
    label "process_low"
    container "${params.container__extract_humgut_phoraged}"
    publishDir "${params.extract_humgut_phoraged_outdir}", mode: 'copy'

    input:
        path(shard)
        path(representative_genomes)
        path(humgut_tsv)

    output:
        path("phoraged/*.fna"), emit: genomes, optional: true

    shell:
    '''
    extract_humgut_phoraged.py \
    --shard !{shard} \
    --representatives !{representative_genomes} \
    --humgut-tsv !{humgut_tsv} \
    --outdir phoraged
    '''
}
