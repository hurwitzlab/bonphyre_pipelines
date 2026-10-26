#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// Output paths for s_i_mg_readqc (../subworkflows/s_i_mg_readqc.nf), relative to
// each sample's output directory (e.g. "${params.outdir}/<sampleid>/").
//
// This is the crash-course getManifest() convention (see nextflow_crash_course
// day2_material/manifests/example_manifest.nf), not Nextflow's built-in
// manifest {} config block. It IS wired into publishDir: s_i_mg_readqc.nf reads
// this map and sets params.bbduk_outdir/params.trimmomatic_outdir to per-sample
// closures built from these paths before calling those processes -- see that
// file and nextflow_process_library/modules/CLAUDE.md's publishDir Closure convention.
def getReadqcManifest() {
    [
        // fastq
        // Actual filenames are "<sampleid>_adapter_trimmed_r1.fastq.gz" etc.;
        // named generically here per this manifest's no-sampleid-in-filename convention.
        adapter_trimmed_r1:  "fastq/adapter_trimmed_r1.fastq.gz",
        adapter_trimmed_r2:  "fastq/adapter_trimmed_r2.fastq.gz",

        clean_r1:            "fastq/clean_r1.fastq.gz",
        clean_r2:            "fastq/clean_r2.fastq.gz",
    ]
}
