#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { genomad } from '../../../nextflow_modules/modules/genomad.nf' //params.genomad_path
include { checkv } from '../../../nextflow_modules/modules/checkv.nf'
include { bbwrap } from '../../../nextflow_modules/modules/bbmap.nf' //coverage
include { pileup } from '../../../nextflow_modules/modules/bbmap.nf' //coverage
include { summarize_viral_filter } from '../modules/local/qc_metrics.nf'
include { getGenomadViralFilterManifest } from '../manifests/manifest_s_i_mg_genomadviralfilter.nf'

workflow s_i_mg_genomadviralfilter {
    take:
        assembled_contigs   // tuple (sampleid, contigs.fa)
        genomad_db_ch       // path to genomad db, collected
        checkv_db_ch        // path to checkv db, collected
        reads_ch            // clean reads, tuple (sampleid, r1, r2)

    main:
        // Point genomad/checkv/pileup's publishDir (resolved centrally via
        // conf/base.config's publish_final/publish_intermediate withLabel:
        // blocks -- see that file) at this subworkflow's manifest-declared,
        // per-sample layout instead of a flat, tool-named directory.
        def viral_filter_manifest = getGenomadViralFilterManifest()
        params.genomad_outdir = { sid -> "${params.outdir}/${sid}/${new File(viral_filter_manifest.viral_summary_dir).parent}" }
        params.checkv_outdir  = { sid -> "${params.outdir}/${sid}/${new File(viral_filter_manifest.quality_dir).parent}" }
        params.pileup_outdir  = { sid -> "${params.outdir}/${sid}/${new File(viral_filter_manifest.coverage).parent}" }

        // Run genomad viral inference
        genomad(assembled_contigs, genomad_db_ch)

        // Extract the virus.fna file from the genomad summary directory for CheckV.
        // The summary dir contains multiple files — we only pass the virus sequences forward.
        virus_ch = genomad.out.inferences
            .map { sampleid, summary_dir ->
                tuple(sampleid, file("${summary_dir}/contigs_virus.fna"))
            }

        // Estimate viral inference quality with CheckV
        checkv(virus_ch, checkv_db_ch)

        // Estimate coverage: align clean reads back to the assembly, then pileup.
        // bbwrap needs (sampleid, contigs, r1, r2), so join contigs with reads by sampleid.
        bbwrap_ch = assembled_contigs
            .join(reads_ch)
            .map { sampleid, contigs, r1, r2 -> tuple(sampleid, contigs, r1, r2) }
        bbwrap(bbwrap_ch)
        pileup(bbwrap.out.mapped_files)

        // QC/benchmark metric: contigs assembled vs. flagged viral, mean CheckV
        // completeness, mean coverage — flags samples with poor viral yield.
        checkv_tsv_ch = checkv.out.quality_assessment
            .map { sampleid, checkv_dir -> tuple(sampleid, file("${checkv_dir}/quality_summary.tsv")) }

        metrics_input_ch = assembled_contigs
            .join(checkv_tsv_ch)
            .join(pileup.out.pileuped_files)

        metrics_ch = summarize_viral_filter(metrics_input_ch).summary
            .map { sampleid, row ->
                def (n_contigs, n_viral, mean_completeness, mean_coverage) = row.tokenize('\t')
                if (n_viral.toInteger() < params.qc_min_viral_contigs) {
                    log.warn "QC: sample ${sampleid} had only ${n_viral} contig(s) pass genomad/checkv out of ${n_contigs} assembled"
                }
                tuple(sampleid, row)
            }

    emit:
        checkv_output = checkv.out.quality_assessment
        metrics       = metrics_ch   // (sampleid, "n_contigs\tn_viral\tmean_completeness\tmean_coverage")
}
