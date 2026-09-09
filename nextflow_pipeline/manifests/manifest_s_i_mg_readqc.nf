#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// Output paths for s_i_mg_readqc (../subworkflows/s_i_mg_readqc.nf), relative to
// each sample's output directory (e.g. "${params.outdir}/<sampleid>/").
//
// This is the crash-course getManifest() convention (see nextflow_crash_course
// day2_material/manifests/example_manifest.nf), not Nextflow's built-in
// manifest {} config block. It is NOT wired into any publishDir yet -- today's
// modules still publish flat, tool-named dirs set by params.*_outdir in
// i_mg_viralinference.config (e.g. trimmomatic_outdir). This file declares the
// per-sample layout those publishDir paths would move to if/when this pipeline
// adopts the convention.
def getReadqcManifest() {
    [
        // fastq
        // bbduk.nf doesn't exist yet in nextflow_modules (see s_i_mg_readqc.nf) --
        // these two paths are provisional until that module lands.
        bbduk_trimmed_r1:    "fastq/bbduk_trimmed_r1.fastq",
        bbduk_trimmed_r2:    "fastq/bbduk_trimmed_r2.fastq",

        clean_r1:            "fastq/clean_r1.fastq",
        clean_r2:            "fastq/clean_r2.fastq",
    ]
}
