#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// Full output manifest for the i_mg_viralinference workflow
// (../workflows/i_mg_viralinference/i_mg_viralinference.nf), composed from
// each subworkflow's own manifest plus paths owned directly by the workflow.
// Same convention/caveats as manifest_s_i_mg_readqc.nf -- see that file's
// header comment.
include { getReadqcManifest } from './manifest_s_i_mg_readqc.nf'
include { getGenomadViralFilterManifest } from './manifest_s_i_mg_genomadviralfilter.nf'

// NOTE: the nextflow_crash_course example (example_manifest.nf) merges
// sub-manifests with Groovy's spread-map operator (`*:getX()` inside a map
// literal). That doesn't parse under Nextflow's strict script parser (tested
// against 26.04.6 -- "Unexpected input: '*'"), so this uses plain map `+`
// merging instead, which is equivalent (right-hand side wins on key clashes).
def getManifest() {
    def workflow_own_paths = [
        //
        // Assembly
        //
        // megahit is called directly in the workflow (not wrapped in a
        // subworkflow), so its output path is declared here rather than in a
        // subworkflow manifest.
        contigs:                   "assembly/contigs.fa",

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
