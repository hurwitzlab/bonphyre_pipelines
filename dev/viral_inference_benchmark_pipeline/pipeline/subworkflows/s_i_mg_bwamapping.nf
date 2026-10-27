#!/usr/bin/env nextflow

include { bwa_align } from '../../nextflow_process_library/modules/bwa/bwa.nf'
include { sam_to_bam } from '../../nextflow_process_library/modules/samtools/samtools.nf'
include { coverm } from '../../nextflow_process_library/modules/coverm/coverm.nf'    //TODO: FIX

workflow s_i_mg_bwamapping {
    take:
        input_ch   // tuple (sampleid, clean_r1, clean_r2, sequencetomap)
        db_ch      // path to reference db, collected

    main:
        bwa_align(input_ch, db_ch)

        sam_to_bam(bwa_align.out.)  //TODO: complete

        coverm(sam_to_bam.out.collect())

        // metrics_ch = summarize_TOOLNAME(TOOLNAME.out.descriptive_output_name).summary
        //     .map { sampleid, row ->
        //         def (col1, col2) = row.tokenize('\t')
        //         if (col1.toInteger() < params.qc_min_SOMETHING) {
        //             log.warn "QC: sample ${sampleid} ..."
        //         }
        //         tuple(sampleid, row)
        //     }

    emit:
        output  = coverm.out.counttable 
        // metrics = metrics_ch                          // (sampleid, "col1\tcol2")
}
