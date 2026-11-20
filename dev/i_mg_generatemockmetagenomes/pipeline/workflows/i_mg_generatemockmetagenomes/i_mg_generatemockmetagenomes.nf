#!/usr/bin/env nextflow

// Help if --help is specified.
def helpMessage() {
    log.info """
       Usage:
           nextflow run i_mg_generatemockmetagenomes.nf --contigs '/path/to/contigs/*/contigs.fa' --reads '/path/to/reads/*/R{1,2}.fastq.gz' --project_id

       Required arguments:
           --contigs     Path to contigs
           --reads       Path to clean reads
           --project_id  Name of project id

       Optional arguments:
           --outdir    Output directory (default: ./results)
       """.stripIndent()
}


// Import processes from module files
// Subworkflows
// Processes
include { art } from '../../../nextflow_process_library/modules/art/art.nf'
include { bracken } from '../../../nextflow_process_library/modules/bracken/bracken.nf'
include { insilicoseq } from '../../../nextflow_process_library/modules/insilicoseq/insilicoseq.nf'
include { kraken2 } from '../../../nextflow_process_library/modules/kraken2/kraken2.nf'
include { build_fmt_abundance_profile } from '../../../pipeline/modules/build_fmt_abundance_profile.nf'
include { combine_reads } from '../../../pipeline/modules/combine_reads.nf'
include { extract_humgut_phoraged } from '../../../pipeline/modules/extract_humgut_phoraged.nf'
include { pick_refs } from '../../../pipeline/modules/pick_refs.nf'
include { pick_representative_genomes } from '../../../pipeline/modules/pick_representative_genomes.nf'

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
    genomad_db_ch       = Channel.fromPath(params.genomad_db, checkIfExists: true).collect()
    viralm_db_ch        = Channel.fromPath(params.viralm_db, checkIfExists: true).collect()
    virsorter2_db_ch    = Channel.fromPath(params.virsorter2_db, checkIfExists: true).collect()
    vibrant_db_ch       = Channel.fromPath(params.vibrant_db, checkIfExists: true).collect()

    // 2.2. Scripts
    virrep_script_ch    = Channel.fromPath(params.virrep_script, checkIfExists: true).collect()   // patched VirRep.py

    // 2.3. Contigs: tuple (sampleid, contigs), sampleid = name of the contigs' parent directory
    contigs_ch = Channel
        .fromPath(params.contigs, checkIfExists: true)
        .map { contigs -> tuple(contigs.parent.name, contigs) }

    // 2.4. Reads (marvel only, it bins from reads): tuple (sampleid, r1, r2)
    reads_ch = Channel.fromFilePairs(params.reads, flat: true, checkIfExists: true)

    // -----------------------------------------------------------------------------------------------------------------------------
    // 3. Pipeline
    // -----------------------------------------------------------------------------------------------------------------------------

    // deepmicroclass2
        deepmicroclass2(contigs_ch)

    // deepvirfinder
        deepvirfinder(contigs_ch)

    // genomad
        genomad(contigs_ch, genomad_db_ch)

    // marvel
        marvel(reads_ch)

    // vibrant
        vibrant(contigs_ch, vibrant_db_ch)

    // viralm
        viralm(contigs_ch, viralm_db_ch)

    // virrep
        virrep(contigs_ch, virrep_script_ch)

    // virsorter2
        virsorter2(contigs_ch, virsorter2_db_ch)
}
