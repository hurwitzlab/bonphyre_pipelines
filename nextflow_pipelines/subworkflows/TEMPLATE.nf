#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { TOOLNAME } from '../../../nextflow_process_library/modules/TOOLNAME/TOOLNAME.nf'
// If this subworkflow reports benchmark metrics, add a summarizing process to
// modules/local/qc_metrics.nf (or a new modules/local/<name>.nf) and include it here.
// include { summarize_TOOLNAME } from '../modules/local/qc_metrics.nf'

// Name must match this filename (minus .nf) and every `include{}` alias used to call it.
workflow s_i_mg_SUBWORKFLOWNAME {
    take:
        input_ch   // tuple (sampleid, ...)
        db_ch      // path to reference db, collected

    main:
        TOOLNAME(input_ch, db_ch)

        // metrics_ch = summarize_TOOLNAME(TOOLNAME.out.descriptive_output_name).summary
        //     .map { sampleid, row ->
        //         def (col1, col2) = row.tokenize('\t')
        //         if (col1.toInteger() < params.qc_min_SOMETHING) {
        //             log.warn "QC: sample ${sampleid} ..."
        //         }
        //         tuple(sampleid, row)
        //     }

    emit:
        output  = TOOLNAME.out.descriptive_output_name   // (sampleid, ...)
        // metrics = metrics_ch                          // (sampleid, "col1\tcol2")
}
