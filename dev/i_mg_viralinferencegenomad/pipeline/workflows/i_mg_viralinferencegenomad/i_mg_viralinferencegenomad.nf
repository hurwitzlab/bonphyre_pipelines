#!/usr/bin/env nextflow

// Help if --help is specified.
def helpMessage() {
    log.info """
       Usage:
           nextflow run i_mg_viralinferencegenomad.nf --reads '/path/to/reads/*/R{1,2}.fastq.gz'

       Required arguments:
           --reads     Path to paired-end reads
           --project_id Project name; outputs go to <data_lake_dir>/<project_id>/...

       Optional arguments:
           --outdir    Output directory (default: ./results)
       """.stripIndent()
}


// Import processes from module files
// Subworkflows
include { s_i_mg_readqc } from '../../subworkflows/s_i_mg_readqc.nf'
include { s_i_mg_genomadviralfilter } from '../../subworkflows/s_i_mg_genomadviralfilter.nf'
include { s_i_mg_abundancetable } from '../../subworkflows/s_i_mg_abundancetable.nf'

// Processes
include { megahit } from '../../../nextflow_process_library/modules/megahit/megahit.nf'
include { mmseqs_easy_cluster } from '../../../nextflow_process_library/modules/mmseqs2/mmseqs2.nf'


workflow {
    // -----------------------------------------------------------------------------------------------------------------------------
    // 1. Set up
    // -----------------------------------------------------------------------------------------------------------------------------
        // Help menu: print banner + parameters
    log.info """\

        I L L U M I N A  M G  V I R A L  I N F E R E N C E - N F   P I P E L I N E
================================================================================================
This pipeline performs viral inference from illumina-generated metagenomes.
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

    // Make sure --project_id is provided (outdir is built from it)
    if ( !params.project_id ) {
        log.error "Missing required parameter --project_id (every run is namespaced under a project on the data lake, e.g. --project_id my_project)"
        exit 1
    }
    // -----------------------------------------------------------------------------------------------------------------------------
    // 2. Channel creation
    // -----------------------------------------------------------------------------------------------------------------------------
    // 2.1. Databases
    adapters_ch    = Channel.fromPath(params.illumina_adapters_file).collect()  //.collect() allows the channel to be broadcasted to every sample run
    genomad_db_ch  = Channel.fromPath(params.genomad_db).collect()
    checkv_db_ch   = Channel.fromPath(params.checkv_db).collect()


    // 2.2. Paired-end reads.
    // fromFilePairs groups R1 and R2 files by sample ID, flat: true unpacks
    // them into separate elements rather than a list, and checkIfExists 
    // raises an error early if the glob pattern matches nothing.
    reads_ch = Channel
        .fromFilePairs(params.reads, flat: true, checkIfExists: true)
        .view { sample_id, r1, r2 -> "Found sample: ${sample_id}" }  //for debugging
	
    // -----------------------------------------------------------------------------------------------------------------------------
    // 3. Pipeline
    // -----------------------------------------------------------------------------------------------------------------------------
    // Trim and filter reads
    s_i_mg_readqc(reads_ch, adapters_ch)

    // Assemble paired reads into contigs with MEGAHIT.
    megahit(s_i_mg_readqc.out.reads)

    // Run genomad viral inference + filtering (includes its own coverage/QC-metric steps)
    s_i_mg_genomadviralfilter(megahit.out.contigs, genomad_db_ch, checkv_db_ch, s_i_mg_readqc.out.reads)

    // Clustering: concatenate filtered viral + proviral seqs from all samples into one catalog, cluster with mmseqs2
        // Channel prep: headers are already "<sampleid>_viral_N"/"<sampleid>_provirus_N", so seq IDs are unique across samples.
        // collectFile waits for ALL samples; sorting by file name keeps the catalog order reproducible.
        // viral_catalog_id is the pooledid: names the catalog file, the mmseqs output files, and the <outdir>/<pooledid>/ folder.
    def viral_catalog_id = 'viral_catalog'
    viral_catalog_ch = s_i_mg_genomadviralfilter.out.viral_fasta
        .mix(s_i_mg_genomadviralfilter.out.provirus_fasta)
        .map { sampleid, fasta -> fasta }
        .collectFile(name: "${viral_catalog_id}.fna", storeDir: "${params.outdir}/${viral_catalog_id}", sort: { it.name })
    mmseqs_easy_cluster(viral_catalog_ch.map { catalog -> tuple(viral_catalog_id, catalog) })

        // Report catalog size before vs. after clustering (number of representative sequences = number of clusters)
    viral_catalog_ch
        .map { catalog -> catalog.countFasta() }
        .subscribe { n -> log.info "Viral catalog: ${n} sequences before clustering" }
    mmseqs_easy_cluster.out.representative_seqs
        .map { _pooledid, rep_seqs -> rep_seqs.countFasta() }
        .subscribe { n -> log.info "Viral catalog: ${n} representative sequences after clustering" }

    // Abundance table: index the clustered catalog (mmseqs representative seqs), map each sample's
    // clean reads to it with bwa mem, and build one table across all samples with coverm (metric = params.coverm_m).
    s_i_mg_abundancetable(s_i_mg_readqc.out.reads, mmseqs_easy_cluster.out.representative_seqs)


    // -----------------------------------------------------------------------------------------------------------------------------
    // 4. Pipeline metric collection
    // -----------------------------------------------------------------------------------------------------------------------------
    // Combine every subworkflow's per-sample metrics into one wide row per sample
    // and write it out as a single benchmark/QC summary table.
    all_metrics_ch = s_i_mg_readqc.out.metrics
    		   .join(s_i_mg_genomadviralfilter.out.metrics, remainder: true)
    		   .join(s_i_mg_abundancetable.out.metrics, remainder: true)
    		   .map { sampleid, readqc_row, viral_row, mapping_row ->
         	   	def readqc  = readqc_row  ?: (['NA'] * 3).join('\t')
         	   	def viral   = viral_row   ?: (['NA'] * 10).join('\t')
         	   	def mapping = mapping_row ?: (['NA'] * 3).join('\t')
         	   	"${sampleid}\t${readqc}\t${viral}\t${mapping}"
     		   }

     all_metrics_ch.collectFile(
         name: 'metrics_summary.tsv',
         storeDir: "${params.outdir}/pipeline_info",
         newLine: true,
         sort:     true,
         seed: "sampleid\traw_reads\tclean_reads\tpct_reads_retained\tn_contigs\tn_viral\tmean_completeness\ttotal_viral_genes\ttotal_host_genes\tmean_coverage\tn_passed_filter\tn_viral_extracted\tn_provirus_extracted\tfilter_extract_match\tmapping_input_reads\tmapped_reads\tpct_reads_mapped"
     )

}

