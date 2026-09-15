#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { genomad } from '../../../nextflow_modules/modules/genomad.nf' //params.genomad_path
include { checkv } from '../../../nextflow_modules/modules/checkv.nf'
include { bbwrap } from '../../../nextflow_modules/modules/bbmap.nf' //coverage
include { pileup } from '../../../nextflow_modules/modules/bbmap.nf' //coverage
include { filter_viral_contigs } from '../../../nextflow_modules/modules/filter_viral_genomad.nf' //filter viral contigs based on coverage
include { extract_fasta_viral_selection } from '../../../nextflow_modules/modules/filter_viral_genomad.nf' //extract fasta sequences from viral contigs that passed filter
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
        params.filter_viral_contigs_outdir = { sid -> "${params.outdir}/${sid}/${new File(viral_filter_manifest.viral_selection).parent}" }
        // extract_fasta_viral_selection writes into its own "viral_selection/" subdirectory,
        // so its outdir is one level up from that -- parent of parent, unlike the flat-file
        // outputs above.
        params.extract_fasta_viral_selection_outdir = { sid -> "${params.outdir}/${sid}/${new File(new File(viral_filter_manifest.virus_fasta).parent).parent}" }

        // 1. Run genomad viral inference
        genomad(assembled_contigs, genomad_db_ch)

        // 2. Estimate viral inference quality with CheckV
            // Channel prep: Extract the virus.fna file from the genomad summary directory for CheckV.
            // The summary dir contains multiple files — we only pass the virus sequences forward.
        virus_ch = genomad.out.inferences
            .map { sampleid, summary_dir ->
                tuple(sampleid, file("${summary_dir}/contigs_virus.fna"))
            }
        checkv(virus_ch, checkv_db_ch)


        // 3. Estimate coverage: align clean reads back to the assembly, then pileup.
            // Channel prep: bbwrap needs (sampleid, contigs, r1, r2), so join contigs with reads by sampleid.
        bbwrap_ch = assembled_contigs
            .join(reads_ch)
            .map { sampleid, contigs, r1, r2 -> tuple(sampleid, contigs, r1, r2) }
        bbwrap(bbwrap_ch)
        pileup(bbwrap.out.mapped_files)

        // 4. Filter the viral contigs based on length, viral genes (checkV out), and coverage (bbwrap-pileup out)
            // Channel prep 1: extract quality_summary.tsv from the checkV output dir --
            // genomad_filterviral.r reads it directly with read_tsv(), so it needs the
            // file itself, not the directory (also reused by METRICS below).
        checkv_tsv_ch = checkv.out.quality_assessment
            .map { sampleid, checkv_dir -> tuple(sampleid, file("${checkv_dir}/quality_summary.tsv")) }
            // Channel prep 2: 
        filter_viral_contigs_ch = checkv_tsv_ch
             .join(pileup.out.pileuped_files)
             .join(genomad.out.inferences)
             .map { sampleid, quality_summary, coverage_file, genomad_out -> tuple(sampleid, quality_summary, coverage_file, genomad_out) } // might not be necessary
        filter_viral_contigs(filter_viral_contigs_ch)

        // 5. Get the fasta sequences of the filtered viral contigs for downstream analysis.
            // Channel prep: extract_fasta_viral_selection also needs the checkV output
            // dir itself (proviruses.fna lives inside it), not just the assembly.
        extract_fasta_viral_selection_ch = filter_viral_contigs.out.viral_selection
             .join(assembled_contigs)
             .join(checkv.out.quality_assessment)
             .map { sampleid, viral_selection, contigs, checkv_dir -> tuple(sampleid, viral_selection, contigs, checkv_dir) }  // might not be necessary
        extract_fasta_viral_selection(extract_fasta_viral_selection_ch)


        // METRICS
        // QC/benchmark metric: contigs assembled vs. flagged viral, mean CheckV
        // completeness, mean coverage, and the final post-filter/extraction viral
        // yield — flags samples with poor viral yield.
        metrics_input_ch = assembled_contigs
            .join(checkv_tsv_ch)
            .join(pileup.out.pileuped_files)
            .join(filter_viral_contigs.out.viral_selection)
            .join(extract_fasta_viral_selection.out.viral_fasta)
            .join(extract_fasta_viral_selection.out.provirus_fasta)

        metrics_ch = summarize_viral_filter(metrics_input_ch).summary
            .map { sampleid, row ->
                def (n_contigs, n_viral, mean_completeness, total_viral_genes, total_host_genes, mean_coverage, n_passed_filter, n_viral_extracted, n_provirus_extracted, filter_extract_match) = row.tokenize('\t')
                if (n_viral.toInteger() < params.qc_min_viral_contigs) {
                    log.warn "QC: sample ${sampleid} had only ${n_viral} contig(s) pass genomad/checkv out of ${n_contigs} assembled"
                }
                if (n_passed_filter.toInteger() < params.qc_min_viral_contigs) {
                    log.warn "QC: sample ${sampleid} had only ${n_passed_filter} contig(s) pass the checkV+coverage filter out of ${n_viral} genomad/checkv calls"
                }
                tuple(sampleid, row)
            }

    emit:
        checkv_output   = checkv.out.quality_assessment
        metrics         = metrics_ch   // (sampleid, "n_contigs\tn_viral\tmean_completeness\ttotal_viral_genes\ttotal_host_genes\tmean_coverage\tn_passed_filter\tn_viral_extracted\tn_provirus_extracted\tfilter_extract_match")
        viral_selection = filter_viral_contigs.out.viral_selection          // (sampleid, selection1.csv) -- viruses/proviruses that passed the checkV+coverage filter
        viral_fasta     = extract_fasta_viral_selection.out.viral_fasta     // (sampleid, sel1_viral.fa) -- extracted viral sequences
        provirus_fasta  = extract_fasta_viral_selection.out.provirus_fasta  // (sampleid, sel1_provirus.fa) -- extracted proviral sequences
}
