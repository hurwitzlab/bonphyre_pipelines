#!/usr/bin/env nextflow


// Infer viral sequences from contigs using vibrant
 process vibrant {
    label "process_high"
    label "publish_final"
    container "${params.container__vibrant}"
                        
    input:
        tuple val(sampleid), path(contigs)

    output:
        tuple val(sampleid), path("VIBRANT_${contigs.baseName}/"), emit: viral_inferences

    shell:
    '''
    python3 ../VIBRANT_run.py \
    -i !{contigs} \
    -f !{params.vibrant_f} \
    -l !{params.vibrant_minlength} \
    -o !{params.vibrant_minorfspercontig} \
    -t !{task.cpus} \
    -folder .
    '''
}