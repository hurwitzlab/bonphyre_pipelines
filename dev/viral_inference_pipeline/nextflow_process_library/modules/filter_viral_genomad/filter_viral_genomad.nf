#!/usr/bin/env nextflow

// Post-processing for geNomad viral inferences: filter calls with checkV +
// coverage, then extract the selected sequences as FASTA. Both processes run
// scripts that live in the consuming pipeline's own bin/ (genomad_filterviral.r,
// genomad_getselectionviral.py) -- Nextflow auto-adds bin/ to PATH, so they're
// invoked by name here rather than with a hardcoded path.

// Filter geNomad viral/proviral calls using checkV quality summary + coverage (genomad_filterviral.r)
 process filter_viral_contigs {
    label "process_single"
    label "publish_intermediate"
    container "${params.container__genomad_filterviral}"

    input:
        tuple val(sampleid), path(quality_summary), path(coverage_file), path(genomad_out)

    output:
        tuple val(sampleid), path("${sampleid}_selection1.csv"), emit: viral_selection

    shell:
    '''
    Rscript --no-save genomad_filterviral.r \
    !{quality_summary} \
    !{coverage_file} \
    !{sampleid}
    '''
}

// Extract the filtered viral/proviral contigs as FASTA from the assembly + checkV proviruses (genomad_getselectionviral.py)
 process extract_fasta_viral_selection {
    label "process_low"
    label "publish_final"
    container "${params.container__genomad_viralselection}"

    input:
        tuple val(sampleid), path(viral_selection), path(assembly), path(checkv_dir)

    output:
        tuple val(sampleid), path("viral_selection/${sampleid}_sel1_provirus.fa"), emit: provirus_fasta
        tuple val(sampleid), path("viral_selection/${sampleid}_map_provirus.csv"), emit: provirus_mapping
        tuple val(sampleid), path("viral_selection/${sampleid}_sel1_viral.fa"), emit: viral_fasta
        tuple val(sampleid), path("viral_selection/${sampleid}_map_virus.csv"), emit: viral_mapping

    shell:
    '''
    mkdir -p viral_selection

    python genomad_getselectionviral.py \
    -f !{viral_selection} \
    -a !{assembly} \
    -c1 !{checkv_dir} \
    -n !{sampleid} \
    -o viral_selection
    '''
}
