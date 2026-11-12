#!/usr/bin/env nextflow

// Classify paired reads taxonomically against a kraken2 database.
// The workflow shapes the reads into one tuple per sample, e.g. from a sample list
// with reads at <reads_dir>/<sample_id>/r1.fastq.gz and r2.fastq.gz:
//   Channel.fromPath(params.sample_list).splitText().map { it.trim() }
//       .map { id -> tuple(id, file("${params.reads_dir}/${id}/r1.fastq.gz"),
//                              file("${params.reads_dir}/${id}/r2.fastq.gz")) }
process kraken2 {
    label "process_high"
    label "publish_intermediate"
    container "${params.container__kraken2}"

    input:
        tuple val(sample_id), path(r1), path(r2)
        path(kraken2_db)

    output:
        tuple val(sample_id), path("${sample_id}.report"), emit: report
        tuple val(sample_id), path("${sample_id}.kraken"), emit: kraken

    shell:
    '''
    kraken2 \
    --db !{kraken2_db} \
    --threads !{task.cpus} \
    --paired \
    --use-names \
    --output !{sample_id}.kraken \
    --report !{sample_id}.report \
    !{r1} !{r2}
    '''
}
