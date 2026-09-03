#!/usr/bin/env nextflow


// Index a reference sequence with bwa
 process bwa_index {
    container "${params.container__bwa}"
                        
    input:
        path(sequence_to_map)

    output:
        path("${sequence_to_map}"), emit: indexed_sequence

    shell:
    '''
    bwa index \
    !{sequence_to_map} \
    -p !{sequence_to_map}

    '''
}

// Align reads to an indexed reference with bwa mem
process bwa_mem {
    container "${params.container__bwa}"

    input:
        tuple val(sampleid), path(clean_r1), path(clean_r2), path(indexed_sequence)

    output:
        tuple val(sampleid), path("${sampleid}.sam"), emit: sam_file

    shell:
    '''
    bwa mem \
    !{indexed_sequence} \
    !{clean_r1} \
    !{clean_r2} \
    -t !{task.cpus} > !{sampleid}.sam
    '''
}