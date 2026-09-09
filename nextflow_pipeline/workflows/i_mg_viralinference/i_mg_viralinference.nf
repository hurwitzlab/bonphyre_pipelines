#!/usr/bin/env nextflow


//1. DSL: Using DSL-2
nextflow.enable.dsl=2


//2. If `true` this prevents a warning of undefined parameter 
params.help = false

//4. Help menu: Function which prints help message text
log.info """\

        I L L U M I N A  M G  V I R A L  I N F E R E N C E - N F   P I P E L I N E
================================================================================================
This pipeline performs viral inference from illumina-generated metagenomes.
List of parameters:

version : ${params.workflow_version}

publish @ ${pub}
    
"""
.stripIndent()


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

// Show help message if the user specifies the --help flag at runtime
if ( params.help ){
    // Invoke the function above which prints the help message
    helpMessage()
    // Exit out and do not run anything else
    exit 1
}


// Import processes from module files
include { s_i_mg_readqc } from '../../subworkflows/s_i_mg_readqc.nf'
include { megahit } from '../../../../nextflow_modules/modules/megahit.nf'
include { s_i_mg_genomadviralfilter } from '../../subworkflows/s_i_mg_genomadviralfilter.nf'

workflow { 

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
        seed: "sampleid\traw_reads\tclean_reads\tpct_reads_retained\tn_contigs\tn_viral\tmean_completeness\tmean_coverage"
    )

}

