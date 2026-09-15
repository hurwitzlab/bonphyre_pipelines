#!/usr/bin/env nextflow


//1. DSL: Using DSL-2
nextflow.enable.dsl=2


//2. If `true` this prevents a warning of undefined parameter
params.help = false

//4. 1 Help if --help is specified.
def helpMessage() {
    log.info """
       Usage:
           nextflow run main.nf --reads '/path/to/reads/*/R{1,2}.fastq.gz'

       Required arguments:
           --reads     Path to paired-end reads

       Optional arguments:
           --outdir    Output directory (default: ./results)
       """.stripIndent()
}

// NOTE: the banner (log.info), the --help check, and the --project_id check
// all used to sit here, at the top level of the script. Nextflow's strict
// syntax parser (this installed version: 26.04.6) doesn't allow that --
// "Statements cannot be mixed with script declarations" -- only declarations
// (include, def, process, workflow) are allowed outside a block. They now
// run as the first statements inside workflow {} below instead.

// Import processes from module files
include { s_i_mg_readqc } from '../../subworkflows/s_i_mg_readqc.nf'
include { megahit } from '../../../../nextflow_modules/modules/megahit.nf'
include { s_i_mg_genomadviralfilter } from '../../subworkflows/s_i_mg_genomadviralfilter.nf'

// megahit is called directly here (not wrapped in a subworkflow), so its
// publishDir is pointed at the manifest here too -- see workflow_own_paths
// in manifest_i_mg_viralinference.nf for why `contigs` lives at the
// workflow level rather than in a subworkflow manifest.
include { getManifest } from '../../manifests/manifest_i_mg_viralinference.nf'

workflow {

    //4. Help menu: print banner + parameters
    log.info """\

        I L L U M I N A  M G  V I R A L  I N F E R E N C E - N F   P I P E L I N E
================================================================================================
This pipeline performs viral inference from illumina-generated metagenomes.
List of parameters:

version : ${params.workflow_version}

publish @ ${params.outdir}

"""
    .stripIndent()

    // Show help message if the user specifies the --help flag at runtime
    if ( params.help ){
        // Invoke the function above which prints the help message
        helpMessage()
        // Exit out and do not run anything else
        exit 1
    }

    // --project_id is required (see i_mg_viralinference.config, where params.outdir
    // is built from it) -- a config file can't itself validate/exit, so this check
    // lives here instead.
    if ( !params.project_id ) {
        log.error "Missing required parameter --project_id (every run is namespaced under a project on the data lake, e.g. --project_id my_project)"
        exit 1
    }

    // Load reference files/databases as single collected values so they can be
    // broadcast to every sample in reads_ch without being consumed once.
    adapters_ch    = Channel.fromPath(params.illumina_adapters_file).collect()
    genomad_db_ch  = Channel.fromPath(params.genomad_db).collect()
    checkv_db_ch   = Channel.fromPath(params.checkv_db).collect()


    // Define input channel for paired-end reads.
    // fromFilePairs groups R1 and R2 files by sample ID, flat: true unpacks
    // them into separate elements rather than a list, and checkIfExists 
    // raises an error early if the glob pattern matches nothing.
    reads_ch = Channel
        .fromFilePairs(params.reads, flat: true, checkIfExists: true)
        // Destructure the tuple into named variables for readability,
        // and log each sample as it enters the channel for debugging.
        .map { sample_id, r1, r2 ->
            log.info "Found sample: ${sample_id}"
            return tuple(sample_id, r1, r2)
        }
	

    // Run read QC subworkflow: trim and filter reads
    s_i_mg_readqc(reads_ch, adapters_ch)

    // trimmomatic.clean_reads is already (sampleid, r1, r2) -- no unpaired reads to drop.
    paired_ch = s_i_mg_readqc.out.reads

    // megahit.nf's own output ("assembly/contigs.fa") is already kept in sync
    // with manifest.contigs above -- the module has nothing left to
    // subdivide, so publishDir (resolved centrally via conf/base.config's
    // publish_final withLabel: block -- see that file) just needs the
    // per-sample root.
    def pipeline_manifest = getManifest()
    assert pipeline_manifest.contigs == 'assembly/contigs.fa' : \
        "manifest.contigs changed (${pipeline_manifest.contigs}) but megahit.nf's own output path wasn't updated to match"
    params.megahit_outdir = { sid -> "${params.outdir}/${sid}" }

    // Assemble paired reads into contigs with MEGAHIT.
    megahit(paired_ch)

    // Run genomad viral inference + filtering (includes its own coverage/QC-metric steps)
    s_i_mg_genomadviralfilter(megahit.out.contigs, genomad_db_ch, checkv_db_ch, paired_ch)

    // Combine every subworkflow's per-sample metrics into one wide row per sample
    // and write it out as a single benchmark/QC summary table.
    all_metrics_ch = s_i_mg_readqc.out.metrics
        .join(s_i_mg_genomadviralfilter.out.metrics)
        .map { sampleid, readqc_row, viral_row -> "${sampleid}\t${readqc_row}\t${viral_row}" }

    all_metrics_ch.collectFile(
        name: 'metrics_summary.tsv',
        storeDir: "${params.outdir}/pipeline_info",
        newLine: true,
        seed: "sampleid\traw_reads\tclean_reads\tpct_reads_retained\tn_contigs\tn_viral\tmean_completeness\ttotal_viral_genes\ttotal_host_genes\tmean_coverage\tn_passed_filter\tn_viral_extracted\tn_provirus_extracted\tfilter_extract_match"
    )

}

