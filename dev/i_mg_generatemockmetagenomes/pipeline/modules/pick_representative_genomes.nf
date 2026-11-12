#!/usr/bin/env nextflow

// Pick one HumGut genome per taxid seen in any sample's Bracken output, highest prevalence_score (04_pick_representative_genomes.py).
// Runs once over every sample's Bracken file, so no sampleid: the workflow collects them, e.g. bracken.out.bracken.map { it[1] }.collect()
process pick_representative_genomes {
    label "process_single"
    container "${params.container__pick_representative_genomes}"
    publishDir "${params.pick_representative_genomes_outdir}", mode: 'copy'

    input:
        path(bracken_files)
        path(humgut_tsv)

    output:
        path("representative_genomes.tsv"), emit: representative_genomes

    shell:
    '''
    pick_representative_genomes.py \
    --bracken !{bracken_files} \
    --humgut-tsv !{humgut_tsv} \
    --out representative_genomes.tsv
    '''
}
