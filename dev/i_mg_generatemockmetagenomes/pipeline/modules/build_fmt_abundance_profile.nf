#!/usr/bin/env nextflow

// Build one sample's ISS abundance file (genome path<TAB>abundance) from its Bracken counts (06_build_fmt_abundance_profile.py).
// genomes is every extracted phoraged .fna (extract_humgut_phoraged.out.genomes.flatten().collect()), staged in the
// work dir so --genomes-dir . finds them. Feeds create_mock_community_reads_draft_abundance_file with the same genomes.
process build_fmt_abundance_profile {
    label "process_single"
    label "publish_intermediate"
    container "${params.container__build_fmt_abundance_profile}"

    input:
        tuple val(sampleid), path(bracken)
        path(representative_genomes)
        path(genomes)

    output:
        tuple val(sampleid), path("${sampleid}_abundance.tsv"), emit: abundance_profile

    shell:
    '''
    build_fmt_abundance_profile.py \
    --sample-id !{sampleid} \
    --bracken !{bracken} \
    --representatives !{representative_genomes} \
    --genomes-dir . \
    --outdir .
    '''
}
