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
        // Viral inference (currently geNomad)
        // Only viral_contigs_fna is referenced directly in the subworkflow code
        // (s_i_mg_genomadviralfilter.nf); the summary dir also contains other
        // geNomad end-to-end files not named here since they're unverified.
        viral_summary_dir:  "viral_filter/contigs_summary",
        viral_contigs_fna:  "viral_filter/contigs_summary/contigs_virus.fna",

        // Quality assessment (currently CheckV)
        // quality_summary is referenced directly in the subworkflow code. The
        // other filenames are CheckV's standard end_to_end outputs (see the
        // sibling checkv_end_to_end process in nextflow_modules/modules/checkv.nf),
        // not yet referenced by this subworkflow but expected to exist in the dir.
        quality_dir:          "viral_filter/quality",
        quality_summary:      "viral_filter/quality/quality_summary.tsv",
        completeness:         "viral_filter/quality/completeness.tsv",
        contamination:        "viral_filter/quality/contamination.tsv",
        complete_genomes:     "viral_filter/quality/complete_genomes.tsv",
        proviruses:           "viral_filter/quality/proviruses.fna",
        viruses:              "viral_filter/quality/viruses.fna",

        // Coverage (currently bbwrap + pileup)
        coverage:            "viral_filter/coverage.txt",
    ]
}
