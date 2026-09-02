#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { genomad } from '../modules/genomad.nf' //params.genomad_path
include { checkv } from '../modules/checkv.nf'

workflow s_i_mg_genomad_viral_filter {
    take:
        assembled_contigs   // tuple (sampleid, contigs.fa)
        genomad_db_ch       // path to genomad db, collected
        checkv_db_ch        // path to checkv db, collected

    main:
        // Run genomad viral inference
        genomad(assembled_contigs, genomad_db_ch)

        // Extract the virus.fna file from the genomad summary directory for CheckV.
        // The summary dir contains multiple files — we only pass the virus sequences forward.
        virus_ch = genomad.out.inferences
            .map { sampleid, summary_dir ->
                tuple(sampleid, file("${summary_dir}/${sampleid}/contigs_virus.fna"))
            }

        // Estimate viral inference quality with CheckV
        checkv(virus_ch, checkv_db_ch)

    emit:
        checkv_output = checkv.out.quality_assessment
}


workflow {
    main:
    // TO DO: add here channels

    // Run the greeting workflow
    s_i_mg_genomad_viral_filter(names)

    publish:
    s_i_mg_genomad_viral_filter_output = s_i_mg_genomad_viral_filter.out
}


// TO DO: ADD COVERAGE AND MERGEANDFINAL!!!