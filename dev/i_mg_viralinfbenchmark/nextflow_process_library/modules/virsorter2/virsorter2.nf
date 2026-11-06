#!/usr/bin/env nextflow


// Infer viral sequences using virsorter2
 process virsorter2 {
    label "process_high"
    label "publish_final"
    container "${params.container__virsorter2}"

    input:
        tuple val(sampleid), path(contigs)
        path(virsorter2_db)

    output:
        tuple val(sampleid), path("${sampleid}/"), emit: viral_inferences

    shell:
    '''
    virsorter run \
    --db-dir !{virsorter2_db} \
    -w !{sampleid} \
    -i !{contigs} \
    -j !{task.cpus} \
    all \
    --min-length !{params.viralinference_minlength}  # 1500
    '''
}

// Round one of VirSorter2 (sensitive pass) per: https://www.protocols.io/view/viral-sequence-identification-sop-with-virsorter2-bwm5pc86?step=3
process find_phages_sensitive {
    label "process_high"
    container "${params.container__virsorter2}"
    errorStrategy 'ignore'

    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("vs2-pass1/config.yaml"), emit: pass1_config
        tuple val(sampleid), path("vs2-pass1/final-viral-boundary.tsv"), emit: pass1_viral_boundary
        tuple val(sampleid), path("vs2-pass1/final-viral-combined.fa"), emit: pass1_viral_combined
        tuple val(sampleid), path("vs2-pass1/final-viral-score.tsv"), emit: pass1_viral_score

    shell:
    '''
    virsorter run \
              --keep-original-seq \
              -i !{contigs} \
              -w vs2-pass1 \
              --include-groups dsDNAphage,ssDNA \
              --min-length !{params.viralinference_minlength} \
              --min-score !{params.virsorter2_min_score} \
              --jobs !{task.cpus} \
              all
    '''
}

// Round two of VirSorter2 (specific pass) per: https://www.protocols.io/view/viral-sequence-identification-sop-with-virsorter2-bwm5pc86?step=3
process find_phages_specific {
    label "process_high"
    label "publish_final"
    container "${params.container__virsorter2}"
    errorStrategy 'ignore'

    input:
        tuple val(sampleid), path(prophages), path(viruses)

    output:
        tuple val(sampleid), path("vs2-pass2/config.yaml"), emit: pass2_config
        tuple val(sampleid), path("vs2-pass2/final-viral-combined.fa"), emit: viral_sequences
        tuple val(sampleid), path("vs2-pass2/final-viral-score.tsv"), emit: viral_scores

    shell:
    '''
    cat !{prophages} !{viruses} > combined.fna

    virsorter run \
              --seqname-suffix-off \
              --viral-gene-enrich-off \
              --provirus-off \
              --prep-for-dramv \
              -i combined.fna \
              -w vs2-pass2 \
              --include-groups dsDNAphage,ssDNA \
              --min-length !{params.viralinference_minlength} \
              --min-score !{params.virsorter2_min_score} \
              --jobs !{task.cpus} \
              all
    '''
}
