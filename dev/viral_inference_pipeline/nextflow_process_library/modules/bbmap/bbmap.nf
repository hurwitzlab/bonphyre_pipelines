#!/usr/bin/env nextflow

// Processes for all the tools in bbmap

// Align reads to contigs with bbwrap
 process bbwrap {
    label "process_medium"
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
    kfilter=!{params.bbmap_kfilter} \
    subfilter=!{params.bbmap_subfilter} \
    maxindel=!{params.bbmap_maxindel} \
    threads=!{task.cpus} \
    nodisk
    '''
}

// Calculate coverage with pileup
 process pileup {
    label "process_medium"
    label "publish_final"
    container "${params.container__bbmap}"

    input:
        tuple val(sampleid), path(aligned_sam)

    output:
        tuple val(sampleid), path("coverage.txt"), emit: pileuped_files

    shell:
    '''
    pileup.sh \
    in=!{aligned_sam} \
    out=coverage.txt \
    threads=!{task.cpus}
    '''

 }


// Trim adapters and low-quality bases from paired reads with bbduk
 process bbduk {
    label "process_medium"
    label "publish_intermediate"
    container "${params.container__bbmap}"

    input:
        tuple val(sampleid), path(raw_r1), path(raw_r2)
        path(adapters_file)

    output:
        tuple val(sampleid), path("adapter_trimmed_r1.fastq"), path("adapter_trimmed_r2.fastq"), emit: clean_reads

    shell:
    '''
    bbduk.sh \
    in1=!{raw_r1} \
    in2=!{raw_r2} \
    out1=adapter_trimmed_r1.fastq \
    out2=adapter_trimmed_r2.fastq \
    ref=!{adapters_file} \
    ktrim=!{params.bbduk_ktrim} \
    k=!{params.bbduk_k} \
    mink=!{params.bbduk_mink} \
    hdist=!{params.bbduk_hdist} \
    !{params.bbduk_additional_flags}
    '''
}

// Compute assembly quality statistics (N50, contig counts, GC%) with stats.sh
 process bbstats {
    label "process_single"
    label "publish_final"
    container "${params.container__bbmap}"

    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("${sampleid}_stats.tsv"), emit: assembly_stats

    shell:
    '''
    stats.sh \
    in=!{contigs} \
    format=6 \
    > !{sampleid}_stats.tsv
    '''
}
