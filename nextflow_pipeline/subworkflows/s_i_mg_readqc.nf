#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { bbduk } from '../../../nextflow_modules/modules/bbduk.nf'
include { trimmomatic } from '../../../nextflow_modules/modules/trimmomatic.nf'

workflow s_i_mg_read_qc {
    take:
        reads_ch       // tuple (sampleid, r1, r2)
        adapters_ch    // path to adapters file, collected

    main:
        // Trim adapters with bbduk
        bbduk(reads_ch, adapters_ch)

        // Quality trim and filter the bbduk trimmed reads with trimmomatic
        trimmomatic(bbduk.out.trimmed_reads)

    emit:
        reads = trimmomatic.out.filtered_reads
}

// TO DO : add output here !! 