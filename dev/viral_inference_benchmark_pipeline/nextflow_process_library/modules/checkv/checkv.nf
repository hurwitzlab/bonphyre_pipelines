#!/usr/bin/env nextflow


// Estimating viral inference quality with CheckV
 process checkv {
    label "process_medium"
    label "publish_final"
    container "${params.container__checkv}"

    input:
        tuple val(sampleid), path(inferred_sequences)
        path(checkv_db)

    output:
        tuple val(sampleid), path("quality"), emit: quality_assessment

    shell:
    '''
    checkv end_to_end \
    !{inferred_sequences} \
    quality \
    --threads !{task.cpus} \
    --db !{checkv_db}
    '''
}

// Assess a sample's viral genome quality end-to-end with CheckV, handling empty input gracefully
// https://bitbucket.org/berkeleylab/checkv/src
// NOTE: shares container__checkv/checkv_outdir with `checkv` above — using both in the same
// pipeline run means they'd publish to the same output dir. Rename one pair before doing so.
process checkv_end_to_end {
    label "process_high"
    label "publish_final"
    container "${params.container__checkv}"

    input:
        tuple val(sampleid), path(genome)
        path(checkv_db_tarball)

    output:
        tuple val(sampleid), path("checkV/complete_genomes.tsv"), emit: complete_phage_genomes
        tuple val(sampleid), path("checkV/completeness.tsv"), emit: completeness
        tuple val(sampleid), path("checkV/contamination.tsv"), emit: contamination
        tuple val(sampleid), path("checkV/proviruses.fna"), emit: predicted_prophages
        tuple val(sampleid), path("checkV/quality_summary.tsv"), emit: quality_summary
        tuple val(sampleid), path("checkV/viruses.fna"), emit: predicted_phages

    shell:
    '''
    if [[ ! -s !{genome} ]]
    then
        mkdir checkV
        touch checkV/complete_genomes.tsv
        touch checkV/completeness.tsv
        touch checkV/contamination.tsv
        touch checkV/proviruses.fna
        touch checkV/quality_summary.tsv
        touch checkV/viruses.fna
        exit 0
    fi

    mkdir database
    tar -xvf !{checkv_db_tarball} -C database

    checkv end_to_end !{genome} checkV -t !{task.cpus} -d database
    '''
}
