#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// Full output manifest for the i_mg_viralinference workflow
// (../workflows/i_mg_viralinference/i_mg_viralinference.nf), composed from
// each subworkflow's own manifest plus paths owned directly by the workflow.
include { getReadqcManifest } from './manifest_s_i_mg_readqc.nf'
include { getGenomadViralFilterManifest } from './manifest_s_i_mg_genomadviralfilter.nf'
include { getMapingBWAManifest } from './manifest_s_i_mg_bwamapping.nf'

def getManifest() {
    def workflow_own_paths = [
        //
        // Assembly
        //
        contigs:                   "assembly/contigs.fa",

        //
        // Clustering
        //



        //
        // Pipeline-wide
        //
        // The one file per subworkflow-metrics convention explicitly does NOT
        // write to disk (see subworkflows/CLAUDE.md) -- only this merged,
        // run-wide summary table does, written once by the workflow itself.
        metrics_summary:           "pipeline_info/metrics_summary.tsv",
    ]

    getReadqcManifest() + getGenomadViralFilterManifest() + workflow_own_paths
}
