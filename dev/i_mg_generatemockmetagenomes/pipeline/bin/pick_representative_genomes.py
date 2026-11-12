#!/usr/bin/env python
"""Pick one HumGut genome per taxid seen in any sample's Bracken output (highest prevalence_score).

Several HumGut genomes can share one taxid, but ISS needs one genome file per organism.
"""
import argparse
from pathlib import Path

import pandas as pd

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--bracken", type=Path, nargs="+", required=True, help="Every sample's Bracken file")
parser.add_argument("--humgut-tsv", type=Path, required=True, help="HumGut2.tsv (gtdb_tax_id, genome_file, prevalence_score)")
parser.add_argument("--out", type=Path, required=True)
args = parser.parse_args()

taxids = set()
for bracken_file in args.bracken:
    bracken = pd.read_csv(bracken_file, sep="\t", dtype={"taxonomy_id": str})
    taxids.update(bracken.loc[bracken["new_est_reads"] > 0, "taxonomy_id"])

humgut = pd.read_csv(args.humgut_tsv, sep="\t", dtype={"gtdb_tax_id": str})
humgut = humgut[humgut["gtdb_tax_id"].isin(taxids)]
humgut["n_candidates"] = humgut.groupby("gtdb_tax_id")["genome_file"].transform("size")

# Highest prevalence_score wins; ties broken on genome_file so reruns give the same pick
best = (
    humgut.sort_values(["prevalence_score", "genome_file"], ascending=[False, True])
    .drop_duplicates("gtdb_tax_id")
    .rename(columns={"gtdb_tax_id": "taxid"})
    .sort_values("taxid")
)
best[["taxid", "gtdb_name", "genome_file", "prevalence_score", "n_candidates"]].to_csv(
    args.out, sep="\t", index=False
)
print(f"{len(taxids)} taxids, {len(best)} representative genomes -> {args.out}")
