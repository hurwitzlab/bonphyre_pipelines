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

    coverage_df = pd.read_csv(args.coverage, sep="\t")
    mean_coverage = pd.to_numeric(coverage_df["Median_fold"], errors="coerce").mean()

    with open(args.outfile, "w") as fh:
        fh.write(f"{n_contigs}\t{n_viral}\t{mean_completeness:.2f}\t{mean_coverage:.2f}\n")


if __name__ == "__main__":
    main()
