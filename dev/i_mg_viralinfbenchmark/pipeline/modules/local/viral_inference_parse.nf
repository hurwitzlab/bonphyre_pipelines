#!/usr/bin/env nextflow

// Parse + merge viral inference tool outputs (benchmark-specific, scripts in bin/)

// Parse one tool's output into a standard table: sampleid | tool | contig | score | call (V/P/O)
process parse_viral_inference {
    label "process_single"
    label "publish_intermediate"
    container "${params.container__parse_viralinference}"
    tag "${sampleid}_${tool}"

    input:
        tuple val(sampleid), val(tool), path(tool_out)   // tool_out = tool's output dir (or file)

    output:
        tuple val(sampleid), path("${sampleid}_${tool}_parsed.tsv"), emit: parsed

    shell:
    '''
    parse_viral_inference.r \
    --tool !{tool} \
    --input !{tool_out} \
    --sampleid !{sampleid} \
    --output !{sampleid}_!{tool}_parsed.tsv \
    --dvf_score !{params.dvf_min_score} \
    --dvf_pvalue !{params.dvf_max_pvalue} \
    --virrep_score !{params.virrep_min_score}
    '''
}

// Merge all parsed tables of a sample: long table + contig x tool V/P/O matrix (all contigs in the assembly)
process merge_viral_inference {
    label "process_single"
    label "publish_final"
    container "${params.container__parse_viralinference}"
    tag "${sampleid}"

    input:
        tuple val(sampleid), path(parsed), path(contigs)

    output:
        tuple val(sampleid), path("${sampleid}_viralinf_long.tsv"),  emit: long
        tuple val(sampleid), path("${sampleid}_viralinf_calls.tsv"), emit: calls

    shell:
    '''
    merge_viral_inference.r \
    --contigs !{contigs} \
    --sampleid !{sampleid} \
    --prefix !{sampleid}_viralinf \
    !{parsed}
    '''
}
