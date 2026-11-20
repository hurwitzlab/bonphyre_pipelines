#!/usr/bin/env nextflow

// Help if --help is specified.
def helpMessage() {
    log.info """
       Usage:
           nextflow run i_mg_viralinfbenchmark.nf --contigs '/path/to/contigs/*/contigs.fa' --reads '/path/to/reads/*/R{1,2}.fastq.gz' --project_id

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
include { deepmicroclass2 } from '../../../nextflow_process_library/modules/deepmicroclass2/deepmicroclass2.nf'
include { deepvirfinder } from '../../../nextflow_process_library/modules/deepvirfinder/deepvirfinder.nf'
include { genomad } from '../../../nextflow_process_library/modules/genomad/genomad.nf'
include { marvel } from '../../../nextflow_process_library/modules/marvel/marvel.nf'
include { filter_min_length } from '../../../nextflow_process_library/modules/seqkit/seqkit.nf'
include { seeker } from '../../../nextflow_process_library/modules/seeker/seeker.nf'
include { vibrant } from '../../../nextflow_process_library/modules/vibrant/vibrant.nf'
include { viralm } from '../../../nextflow_process_library/modules/viralm/viralm.nf'
include { virrep } from '../../../nextflow_process_library/modules/virrep/virrep.nf'
include { virsorter2 } from '../../../nextflow_process_library/modules/virsorter2/virsorter2.nf'
include { parse_viral_inference; merge_viral_inference } from '../../modules/local/viral_inference_parse.nf'

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

    // -----------------------------------------
    // 3.2. Viral inference tools
    // -----------------------------------------

    // deepmicroclass2
        deepmicroclass2(contigs_ch)

    // deepvirfinder
        deepvirfinder(contigs_ch)

    // genomad
        genomad(contigs_ch, genomad_db_ch)

    // marvel
        marvel(reads_ch)

    // seeker (no length option: filter contigs with seqkit first)
        filter_min_length(contigs_ch, params.seeker_minlength)
        seeker(filter_min_length.out.filtered_sequences)

    // vibrant
        vibrant(contigs_ch, vibrant_db_ch)

    // viralm
        viralm(contigs_ch, viralm_db_ch)

    // virrep
        virrep(contigs_ch, virrep_script_ch)

    // virsorter2
        virsorter2(contigs_ch, virsorter2_db_ch)

    // -----------------------------------------
    // 3.3. Parse + merge tool outputs
    // -----------------------------------------

    // tag each tool's output: tuple (sampleid, tool, output dir)
    parse_in_ch = deepmicroclass2.out.classification.map  { id, d -> tuple(id, 'deepmicroclass2', d) }
        .mix(deepvirfinder.out.viral_inferences.map       { id, d -> tuple(id, 'deepvirfinder',   d) })
        .mix(genomad.out.inferences.map                   { id, d -> tuple(id, 'genomad',         d) })
        .mix(seeker.out.viral_inferences.map              { id, d -> tuple(id, 'seeker',          d) })
        .mix(viralm.out.classification.map                { id, d -> tuple(id, 'viralm',          d) })
        .mix(virrep.out.viral_inferences.map              { id, d -> tuple(id, 'virrep',          d) })
        .mix(virsorter2.out.viral_inferences.map          { id, d -> tuple(id, 'virsorter2',      d) })

        parse_viral_inference(parse_in_ch)

    // all parsed tables of a sample + its contigs: tuple (sampleid, [parsed], contigs)
    merge_in_ch = parse_viral_inference.out.parsed
        .groupTuple()
        .join(contigs_ch)

        merge_viral_inference(merge_in_ch)
}

