#!/usr/bin/env nextflow

// Help if --help is specified.
def helpMessage() {
    log.info """
       Usage:
           nextflow run viral_inference_benchmark.nf --reads '/path/to/reads/*/R{1,2}.fastq.gz'

       Required arguments:
           --reads     Path to paired-end reads
           --projectid Name of project id

       Optional arguments:
           --outdir    Output directory (default: ./results)
       """.stripIndent()
}


// Import processes from module files
// Subworkflows
include { s_i_mg_readqc } from '../../subworkflows/s_i_mg_readqc.nf'
//include { s_i_mg_genomadviralfilter } from '../../subworkflows/s_i_mg_genomadviralfilter.nf'

// Processes
include { megahit } from '../../../nextflow_process_library/modules/megahit/megahit.nf'


workflow {
    // -----------------------------------------------------------------------------------------------------------------------------
    // 1. Set up
    // -----------------------------------------------------------------------------------------------------------------------------
        // Help menu: print banner + parameters
    log.info """\

                                VIRAL INFERENCE BENCHMARK
================================================================================================
This pipeline runs and compares viral inference pipelines on ... 
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
    // -----------------------------------------------------------------------------------------------------------------------------
    // 2. Channel creation
    // -----------------------------------------------------------------------------------------------------------------------------
    // 2.1. Databases
    adapters_ch    = Channel.fromPath(params.illumina_adapters_file).collect()  //.collect() allows the channel to be broadcasted to every sample run
    //genomad_db_ch  = Channel.fromPath(params.genomad_db).collect()
    //checkv_db_ch   = Channel.fromPath(params.checkv_db).collect()


    // 2.2. Paired-end reads
    reads_ch = Channel
        .fromFilePairs(params.reads, flat: true, checkIfExists: true)
        .view { sample_id, r1, r2 -> "Found sample: ${sample_id}" }  //for debugging
	
    // -----------------------------------------------------------------------------------------------------------------------------
    // 3. Pipeline
    // -----------------------------------------------------------------------------------------------------------------------------

    // -----------------------------------------
    // 3.1. Assembly (for real datasets only)
    // -----------------------------------------

    // Trim and filter reads
    s_i_mg_readqc(reads_ch, adapters_ch)

    // Assemble paired reads into contigs with MEGAHIT.
    megahit(s_i_mg_readqc.out.reads)




    // -----------------------------------------
    // 3.2. Viral inference tools
    // -----------------------------------------
    //
}

