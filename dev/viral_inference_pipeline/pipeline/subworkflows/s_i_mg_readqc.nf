#!/usr/bin/env nextflow

include { bbduk } from '../../nextflow_process_library/modules/bbmap/bbmap.nf'
include { trimmomatic } from '../../nextflow_process_library/modules/trimmomatic/trimmomatic.nf'
include { seqkit_stats as seqkit_stats_raw; seqkit_stats as seqkit_stats_clean } from '../modules/local/qc_metrics.nf'

workflow s_i_mg_readqc {
    take:
        reads_ch       // tuple (sampleid, r1, r2)
        adapters_ch    // path to adapters file, collected

    main:
        // Trim adapters with bbduk
        bbduk(reads_ch, adapters_ch)

        // Quality trim and filter the bbduk trimmed reads with trimmomatic
        trimmomatic(bbduk.out.clean_reads)

        // QC metric: raw vs. post-trim read counts, to catch samples that lose
        // most of their reads during adapter/quality trimming.
        raw_counts_ch = seqkit_stats_raw(reads_ch.map { sampleid, r1, r2 -> tuple(sampleid, r1) }, 'raw')
        clean_counts_ch = seqkit_stats_clean(
            trimmomatic.out.clean_reads.map { sampleid, r1, r2 -> tuple(sampleid, r1) },
            'clean'
        )

        metrics_ch = raw_counts_ch.read_count
            .join(clean_counts_ch.read_count)
            .map { sampleid, raw_reads, clean_reads ->
                def pct_retained = clean_reads.toInteger() / raw_reads.toInteger() * 100
                if (pct_retained < params.qc_min_pct_reads_retained) {
                    log.warn "QC: sample ${sampleid} retained only ${pct_retained.round(1)}% of reads after read QC (raw=${raw_reads}, clean=${clean_reads})"
                }
                tuple(sampleid, "${raw_reads}\t${clean_reads}\t${pct_retained.round(1)}")
            }

    emit:
        reads   = trimmomatic.out.clean_reads   // (sampleid, r1, r2)
        metrics = metrics_ch                    // (sampleid, "raw_reads\tclean_reads\tpct_reads_retained")
}
