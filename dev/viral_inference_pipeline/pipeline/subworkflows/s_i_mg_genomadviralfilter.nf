#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { genomad } from '../../nextflow_process_library/modules/genomad/genomad.nf' //params.genomad_path
include { checkv } from '../../nextflow_process_library/modules/checkv/checkv.nf'
include { bbwrap } from '../../nextflow_process_library/modules/bbmap/bbmap.nf' //coverage
include { pileup } from '../../nextflow_process_library/modules/bbmap/bbmap.nf' //coverage
include { filter_viral_contigs } from '../../nextflow_process_library/modules/filter_viral_genomad/filter_viral_genomad.nf' //filter viral contigs based on coverage
include { extract_fasta_viral_selection } from '../../nextflow_process_library/modules/filter_viral_genomad/filter_viral_genomad.nf' //extract fasta sequences from viral contigs that passed filter

workflow s_i_mg_genomadviralfilter {
    take:
        assembled_contigs   // tuple (sampleid, contigs.fa)
        genomad_db_ch       // path to genomad db, collected
        checkv_db_ch        // path to checkv db, collected
        reads_ch            // clean reads, tuple (sampleid, r1, r2)

    main:
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


    emit:
        checkv_output   = checkv.out.quality_assessment
        viral_selection = filter_viral_contigs.out.viral_selection          // (sampleid, selection1.csv) -- viruses/proviruses that passed the checkV+coverage filter
        viral_fasta     = extract_fasta_viral_selection.out.viral_fasta     // (sampleid, sel1_viral.fa) -- extracted viral sequences
        provirus_fasta  = extract_fasta_viral_selection.out.provirus_fasta  // (sampleid, sel1_provirus.fa) -- extracted proviral sequences
}
