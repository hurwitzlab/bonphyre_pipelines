#!/usr/bin/env nextflow

// Cluster sequences into representative OTU-style clusters with mmseqs2 easy-cluster
process mmseqs_cluster {
    label "process_high"
    container "${params.container__mmseqs2}"
    // No sampleid here (clusters a whole sequence corpus, not per-sample) so
    // the Closure-based publishDir convention (which takes sampleid) doesn't
    // apply -- stays a plain path.
    publishDir "${params.mmseqs2_outdir}", mode: 'copy'

    input:
        path(all_seqs)

    output:
        path("${params.mmseqs2_prefix}_rep_seq.fasta"), emit: representative_seqs
        path("${params.mmseqs2_prefix}_cluster.tsv"), emit: clusters

    shell:
    '''
    mmseqs easy-cluster \
    !{all_seqs} \
    !{params.mmseqs2_prefix} \
    tmp \
    --min-seq-id !{params.mmseqs2_minseqid} \
    --cov-mode !{params.mmseqs2_covmode} \
    -c !{params.mmseqs2_c} \
    --threads !{task.cpus}
    '''
}

// Cluster a merged protein database into groups with mmseqs easy-cluster, then split the result into one fasta per cluster
process cluster_proteins {
    label "process_high"
    container "${params.container__mmseqs}"
    // No sampleid here (clusters a whole protein database, not per-sample)
    // so the Closure-based publishDir convention doesn't apply -- stays a
    // plain path.
    publishDir "${params.mmseqs_outdir}", mode: 'copy'

    input:
        path(protein_database)

    output:
        path("clusters.tar.gz"), emit: clustered_fasta_archive
        path("${params.mmseqs_prefix}_cluster.tsv"), emit: cluster_mapping
        path("${params.mmseqs_prefix}_rep_seq.fasta"), emit: representative_seqs
        path("log_mmseqs"), emit: mmseqs_log

    shell:
    '''
    # mmseqs produces:
    # !{params.mmseqs_prefix}_all_seqs.fasta, which has > record for group with no sequence (i.e. two sequential rows starting with >)
    # !{params.mmseqs_prefix}_cluster.tsv, which is a mapping of seq to cluster rep
    # !{params.mmseqs_prefix}_rep_seq.fasta, which are the rep sequences
    mmseqs easy-cluster !{protein_database} !{params.mmseqs_prefix} /tmp --min-seq-id !{params.mmseqs_minseqid} -c !{params.mmseqs_c} --threads !{task.cpus} 2>&1 > log_mmseqs

    # break up the mega fasta into one per cluster
    # file names not always normalized in above awk + sed command, so normalize again just in case
    mkdir clusters
    cd clusters
    awk 'BEGIN {h=""}
    /^>/ {
        if (h==$0) {
            close(file);
            f=h; sub(">", "", f); gsub(/[\\(\\)\\047\\057]/, "_", f);
            file=sprintf("%s.fasta", f);
        }
        h=$0; next;
    }
    {
        print h "\\n" $0 >> file
    }' "../!{params.mmseqs_prefix}_all_seqs.fasta"

    # create tarball in context of clusters (so only contains files)
    cd ..
    tar -cvzf clusters.tar.gz -C clusters .
    '''
}
