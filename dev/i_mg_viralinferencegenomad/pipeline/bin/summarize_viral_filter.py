#!/usr/bin/env python3
# Summarize genomad/checkv/coverage outputs for one sample into a single row
# of viral-inference yield metrics, used by modules/local/qc_metrics.nf.
import argparse

import pandas as pd


def count_fasta_records(path):
    n = 0
    with open(path) as fh:
        for line in fh:
            if line.startswith(">"):
                n += 1
    return n


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--contigs", required=True, help="assembled contigs fasta")
    parser.add_argument("--checkv", required=True, help="CheckV quality_summary.tsv")
    parser.add_argument("--coverage", required=True, help="BBMap pileup coverage stats file")
    parser.add_argument(
        "--viral-selection", required=True,
        help="filter_viral_contigs output (genomad_filterviral.r's <sampleid>_selection1.csv)",
    )
    parser.add_argument(
        "--viral-fasta", required=True,
        help="extract_fasta_viral_selection viral output (<sampleid>_sel1_viral.fa)",
    )
    parser.add_argument(
        "--provirus-fasta", required=True,
        help="extract_fasta_viral_selection provirus output (<sampleid>_sel1_provirus.fa)",
    )
    parser.add_argument("--outfile", required=True)
    args = parser.parse_args()

    n_contigs = count_fasta_records(args.contigs)

    checkv_df = pd.read_csv(args.checkv, sep="\t")
    n_viral = len(checkv_df)
    mean_completeness = (
        pd.to_numeric(checkv_df["completeness"], errors="coerce").mean()
        if n_viral > 0
        else float("nan")
    )
    total_viral_genes = pd.to_numeric(checkv_df["viral_genes"], errors="coerce").sum()
    total_host_genes = pd.to_numeric(checkv_df["host_genes"], errors="coerce").sum()

    coverage_df = pd.read_csv(args.coverage, sep="\t")
    mean_coverage = pd.to_numeric(coverage_df["Median_fold"], errors="coerce").mean()

    n_passed_filter = len(pd.read_csv(args.viral_selection))
    n_viral_extracted = count_fasta_records(args.viral_fasta)
    n_provirus_extracted = count_fasta_records(args.provirus_fasta)
    filter_extract_match = n_passed_filter == (n_viral_extracted + n_provirus_extracted)

    with open(args.outfile, "w") as fh:
        fh.write(
            f"{n_contigs}\t{n_viral}\t{mean_completeness:.2f}\t"
            f"{total_viral_genes:.0f}\t{total_host_genes:.0f}\t{mean_coverage:.2f}\t"
            f"{n_passed_filter}\t{n_viral_extracted}\t{n_provirus_extracted}\t{filter_extract_match}\n"
        )


if __name__ == "__main__":
    main()
