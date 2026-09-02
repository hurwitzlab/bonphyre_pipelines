#!/usr/bin/env nextflow

// Processes for all the tools in bbmap

// Align reads to contigs with bbwrap
 process bbwrap {
    container "${params.container__bbmap}"
                        
    input:
        tuple val(sampleid), path(contigs), path(clean_r1), path(clean_r2)

    output:
        tuple val(sampleid), path("${sampleid}_aln.sam.gz"), emit: mapped_files

    shell:
    '''
    bbwrap.sh \
    ref=!{contigs} \
    in=!{clean_r1} \
    in2=!{clean_r2} \
    out=!{sampleid}_aln.sam.gz \
    kfilter=!{params.bbwrap_kfilter} \
    subfilter=!{params.bbwrap_subfilter} \
    maxindel=!{params.bbwrap_maxindel}  \
    nodisk
    '''
}

// Calculate coverage with pileup
 process pileup {
    container "${params.container__bbmap}"
    publishDir "${params.bbmap_outdir}", mode: 'copy'
                        
    input:
        tuple val(sampleid), path(aligned_sam)

    output:
        tuple val(sampleid), path("${sampleid}_cov.txt"), emit: pileuped_files

    shell:
    '''
    pileup.sh \
    in=!{aligned_sam} \
    out=!{sampleid}_cov.txt
    '''

 }