#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// Output paths for s_i_mg_genomadviralfilter
// (../subworkflows/s_i_mg_genomadviralfilter.nf), relative to each sample's
// output directory. Same convention/caveats as manifest_s_i_mg_readqc.nf --
// see that file's header comment.
//
// Only paths this subworkflow's own processes actually produce are listed.
// `contigs` (the megahit assembly) is a `take:` input here, not something this
// subworkflow emits, so it belongs in the workflow-level manifest instead.
def getGenomadViralFilterManifest() {
    [
        // geNomad
        // Only contigs_virus.fna is referenced directly in the subworkflow code
        // (s_i_mg_genomadviralfilter.nf); the summary dir also contains other
        // geNomad end-to-end files not named here since they're unverified.
        genomad_summary_dir:      "viral_filter/genomad/contigs_summary",
        genomad_virus_fna:        "viral_filter/genomad/contigs_summary/contigs_virus.fna",

        // CheckV
        // quality_summary.tsv is referenced directly in the subworkflow code.
        // The other filenames are CheckV's standard end_to_end outputs (see the
        // sibling checkv_end_to_end process in nextflow_modules/modules/checkv.nf),
        // not yet referenced by this subworkflow but expected to exist in the dir.
        checkv_dir:                "viral_filter/checkv",
        checkv_quality_summary:    "viral_filter/checkv/quality_summary.tsv",
        checkv_completeness:       "viral_filter/checkv/completeness.tsv",
        checkv_contamination:      "viral_filter/checkv/contamination.tsv",
        checkv_complete_genomes:   "viral_filter/checkv/complete_genomes.tsv",
        checkv_proviruses:         "viral_filter/checkv/proviruses.fna",
        checkv_viruses:            "viral_filter/checkv/viruses.fna",

        // coverage (bbwrap + pileup)
        coverage:                  "viral_filter/coverage/pileup_coverage.txt",
    ]
}
