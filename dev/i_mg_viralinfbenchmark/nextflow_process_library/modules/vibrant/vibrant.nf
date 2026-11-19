#!/usr/bin/env nextflow


// Infer viral sequences from contigs using vibrant
 process vibrant {
    label "process_high"
    label "publish_final"
    container "${params.container__vibrant}"
                        
    input:
        tuple val(sampleid), path(contigs)
        path db

    output:
        tuple val(sampleid), path("VIBRANT_${contigs.baseName}/"), emit: results
        tuple val(sampleid), path("VIBRANT_${contigs.baseName}/VIBRANT_phages_*/*.phages_combined.fna"), emit: phages

    shell:
    '''
    VIBRANT_run.py \
    -i !{contigs} \
    -f !{params.vibrant_f} \
    -l !{params.vibrant_minlength} \
    -o !{params.vibrant_minorfspercontig} \
    -d ${db}/databases/ \\
    -m ${db}/files/
    -t !{task.cpus} \
    -folder .
    '''

}