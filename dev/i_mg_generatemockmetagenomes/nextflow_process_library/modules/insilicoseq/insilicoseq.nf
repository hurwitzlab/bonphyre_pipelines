#!/usr/bin/env nextflow

// Run InsilicoSeq to simulate mock community reads at a specified abundance distribution
process create_mock_community_reads_abundance_distribution {
    label "process_medium"
    container "${params.container__insilicoseq}"
    publishDir "${params.insilicoseq_outdir}", mode: 'copy'

    input:
        val(ordered_genomes)
        path(genome_dir)
        val(abundance)
        val(model)
        val(seed)
        val(n_reads)
        val(mode)

    output:
        path("reads_R1.fastq.gz"), emit: r1_reads
        path("reads_R2.fastq.gz"), emit: r2_reads
        path("reads_abundance.txt"), emit: reads_abundance

    shell:
    '''
    cp -r !{genome_dir}/* .
    genome_list="$(echo !{ordered_genomes} | tr ',' ' ')"
    iss generate --abundance !{abundance} \
                 --draft $genome_list \
                 --model !{model} \
                 --seed !{seed} \
                 --n_reads !{n_reads} \
                 --mode !{mode} \
                 --cpus !{task.cpus} \
                 --output reads
    gzip reads_R1.fastq
    gzip reads_R2.fastq
    '''
}

// Run InsilicoSeq to simulate mock community reads from a pre-defined abundance file
process create_mock_community_reads_abundance_file {
    label "process_medium"
    container "${params.container__insilicoseq}"
    publishDir "${params.insilicoseq_outdir}", mode: 'copy'

    input:
        val(ordered_genomes)
        path(genome_dir)
        path(reads_abundance)
        val(model)
        val(seed)
        val(n_reads)
        val(mode)

    output:
        path("reads_R1.fastq.gz"), emit: r1_reads
        path("reads_R2.fastq.gz"), emit: r2_reads

    shell:
    '''
    cp -r !{genome_dir}/* .
    genome_list="$(echo !{ordered_genomes} | tr ',' ' ')"
    iss generate --abundance_file !{reads_abundance} \
        --genomes $genome_list \
        --model !{model} \
        --seed !{seed} \
        --n_reads !{n_reads} \
        --mode !{mode} \
        --cpus !{task.cpus} \
        --output reads
    gzip reads_R1.fastq
    gzip reads_R2.fastq
    '''
}

// Build a per-genome abundance file and single-sequence genome directory from a set of genomes
process create_abundance_file {
    label "process_single"
    container "${params.container__insilicoseq}"

    input:
        val(ordered_genomes)
        path(genome_dir)
        val(abundance)

    output:
        path("reads_abundance.txt"), emit: reads_abundance
        path("single_genomes_dir"), emit: single_genomes_dir, type: 'dir'

    shell:
    '''
    mkdir single_genomes_dir
    echo !{ordered_genomes} | tr ',' '\n' > genome_list
    while read genome; do
        head -1 !{genome_dir}/$genome | sed 's/ .*//' | sed 's/^>//' >> reads_abundance1.txt
        head -1 !{genome_dir}/$genome > header
        egrep -v ">" !{genome_dir}/$genome > sequence
        cat header sequence > ./single_genomes_dir/$genome
    done <genome_list
    echo !{abundance} | tr ',' '\n' > reads_abundance2.txt
    paste reads_abundance1.txt reads_abundance2.txt > reads_abundance.txt
    '''
}

// Simulate paired metagenome reads with InSilicoSeq from draft genomes and an abundance file
process create_mock_community_reads_draft_abundance_file {
    label "process_high"
    label "publish_intermediate"
    container "${params.container__insilicoseq}"

    input:
        tuple val(sampleid), val(model), val(n_reads), val(seed), path(abundance_tsv), path(genomes)

    output:
        tuple val(sampleid), val(model), path("${sampleid}_R1.fastq.gz"), path("${sampleid}_R2.fastq.gz"), env(read_len), emit: reads

    shell:
    '''
    awk -F'\\t' -v OFS='\\t' '{ n = split($1, p, "/"); $1 = p[n]; print }' !{abundance_tsv} > abundance.tsv

    iss generate \
    --draft $(cut -f1 !{abundance_tsv}) \
    --abundance_file !{abundance_tsv} \
    --model !{model} \
    --n_reads !{n_reads} \
    --seed !{seed} \
    --cpus !{task.cpus} \
    --compress \
    --output !{sampleid}

    read_len=$( (zcat !{sampleid}_R1.fastq.gz || true) | awk 'NR == 2 { print length($0); exit }')
    '''
}
