#!/usr/bin/env nextflow

// Classify sequence fragments (virus/plasmid/chromosome/etc) with DeepMicroClass2
//
// CAVEAT: the source SLURM/LSF script runs this container with `apptainer run`,
// meaning it relies on the image's own ENTRYPOINT to turn `--contig ... --out_dir
// ... --model ...` into an actual command. Nextflow's container directive uses
// `apptainer exec`, which does NOT invoke the ENTRYPOINT. The binary name below
// is a placeholder — confirm the real entrypoint command (e.g. `apptainer
// inspect --deffile <sif>`) before relying on this module.
 process deepmicroclass2 {
    label "process_high"
    label "publish_final"
    container "${params.container__deepmicroclass2}"
    containerOptions '--nv'

    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("${sampleid}"), emit: classification

    shell:
    '''
    DeepMicroClass2 \
    --contig !{contigs} \
    --out_dir !{sampleid} \
    --model !{params.deepmicroclass2_model}
    '''
}
