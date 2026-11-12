#!/usr/bin/env nextflow

// Pick random INPHARED spike-in genomes per sample dir and write each dir's contigs.fasta, refs_log.txt and conditions.tsv (09_pick_refs.py).
// Runs once for the whole og design (no sampleid); the design (types, conditions, coverages) is built into pick_refs.py.
// Sample dirs are spike_in_samples/{type}/sample{n}/; the workflow can take the sample id from each file's parent dirs.
process pick_refs {
    label "process_single"
    container "${params.container__pick_refs}"
    publishDir "${params.pick_refs_outdir}", mode: 'copy'

    input:
        path(accessions_list)
        path(genomes_dir)
        val(replicates)
        val(seed)

    output:
        path("spike_in_samples/**/contigs.fasta"), emit: contigs
        path("spike_in_samples/**/refs_log.txt"), emit: refs_log
        path("spike_in_samples/**/conditions.tsv"), emit: conditions

    shell:
    '''
    pick_refs.py \
    --replicates !{replicates} \
    --seed !{seed} \
    --accessions !{accessions_list} \
    --genomes-dir !{genomes_dir} \
    --outdir spike_in_samples
    '''
}
