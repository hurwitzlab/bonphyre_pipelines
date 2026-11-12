#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { bwa_index; bwa_mem } from '../../nextflow_process_library/modules/bwa/bwa.nf'
include { sam_to_bam; sort_bam; index_bam } from '../../nextflow_process_library/modules/samtools/samtools.nf'
include { coverm } from '../../nextflow_process_library/modules/coverm/coverm.nf'
include { mapping_stats } from '../modules/local/qc_metrics.nf'

workflow s_i_mg_abundancetable {
    take:
        reads_ch       // clean reads, tuple (sampleid, r1, r2)
        reference_ch   // ONE pooled reference to map against, tuple (pooledid, reference.fasta) -- e.g. mmseqs representative seqs

    main:
        // 1. Index the pooled reference once for the whole run
        bwa_index(reference_ch)

        // 2. Map every sample's clean reads to the indexed reference
            // Channel prep: drop pooledid and broadcast (reference, index_files) to every sample with combine.
            // Result: (sampleid, r1, r2, reference.fasta, [index files])
        bwa_mem_ch = reads_ch.combine(
            bwa_index.out.indexed_sequence.map { _pooledid, ref, idx -> tuple(ref, idx) }
        )
        bwa_mem(bwa_mem_ch)

        // 3. SAM -> BAM keeping mapped reads only (-F 4), sort by coordinate, index
        sam_to_bam(bwa_mem.out.sam_file)
        sort_bam(sam_to_bam.out.bam_file)
        index_bam(sort_bam.out.sorted_bam)

        // 4. One count table across all samples with coverm
            // Channel prep: gather every sample's sorted BAM (waits for ALL samples), sorted by
            // file name so the table's sample columns are in a reproducible order. The list is
            // wrapped in [ ] so combine keeps it as one element instead of flattening it.
            // Result: (pooledid, [sample1.sorted.bam, sample2.sorted.bam, ...])
        all_bams_ch = index_bam.out.mapped_files
            .map { _sampleid, bam, _bai -> bam }
            .toSortedList { a, b -> a.name <=> b.name }
        coverm_ch = reference_ch
            .map { pooledid, _ref -> pooledid }
            .combine(all_bams_ch.map { bams -> [bams] })
        coverm(coverm_ch)

        // METRICS
        // QC metric: % of each sample's clean reads that map to the reference (computed on the raw
        // bwa SAM, before unmapped reads are dropped) -- flags samples the catalog barely represents.
        metrics_ch = mapping_stats(bwa_mem.out.sam_file).mapping_counts
            .map { sampleid, row ->
                def (input_reads, mapped_reads) = row.tokenize('\t')
                def total = input_reads.toLong()
                def pct_mapped = total > 0 ? (mapped_reads.toLong() / total * 100).round(1) : 0
                if (pct_mapped < params.qc_min_pct_reads_mapped) {
                    log.warn "QC: sample ${sampleid} had only ${pct_mapped}% of reads map to the reference (mapped=${mapped_reads}, input=${input_reads})"
                }
                tuple(sampleid, "${input_reads}\t${mapped_reads}\t${pct_mapped}")
            }

    emit:
        bams        = index_bam.out.mapped_files   // (sampleid, sample.sorted.bam, sample.sorted.bam.bai)
        count_table = coverm.out.count_table       // (pooledid, pooledid.txt) -- rows = reference seqs, one column per sample, metric = params.coverm_m
        metrics     = metrics_ch                   // (sampleid, "mapping_input_reads\tmapped_reads\tpct_reads_mapped") -- reads counted individually (R1 + R2)
}
