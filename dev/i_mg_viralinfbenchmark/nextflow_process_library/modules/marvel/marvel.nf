#!/usr/bin/env nextflow


// Infering viral bins from reads with marvel
 process marvel {
    label "process_medium"
    label "publish_final"
    container "${params.container__marvel}"
                        
    input:
        tuple val(sampleid), path(clean_r1), path(clean_r2)

    output:
        tuple val(sampleid), path("bins_folder/Results/phage_genomes"), emit: viral_inferences

    shell:
    '''
    # 1.Generate bins from reads (spades and metabat)
    python3 generate_bins_from_reads.py \
    -1 !{clean_r1} \
    -2 !{clean_r2} \
    -t !{task.cpus}

    # 2. Predict phage bins
    # bins_folder/ is hardcoded output from generate_bins_from_reads.py
    python3 marvel_bins.py \
    -i bins_folder \
    -t !{task.cpus}
    '''
}
