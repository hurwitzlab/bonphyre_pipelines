#!/usr/bin/env python
"""Build one sample's ISS abundance file (genome path<TAB>abundance, no header).

Abundance is each representative genome's share of the sample's Bracken-corrected reads.
Genomes with no phoraged sequence are dropped and the rest renormalized.
"""
import argparse
from pathlib import Path

import pandas as pd

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--sample-id", required=True)
parser.add_argument("--bracken", type=Path, required=True, help="The sample's Bracken file")
parser.add_argument("--representatives", type=Path, required=True, help="representative_genomes.tsv (04)")
parser.add_argument("--genomes-dir", type=Path, required=True, help="Holds the extracted phoraged <genome_id>.fna files")
parser.add_argument("--outdir", type=Path, required=True)
args = parser.parse_args()

representatives = pd.read_csv(args.representatives, sep="\t", dtype={"taxid": str})
representatives["genome_id"] = representatives["genome_file"].str.replace(r"(\.fna)?(\.gz)?$", "", regex=True)
available = {p.stem for p in args.genomes_dir.glob("*.fna")}
args.outdir.mkdir(parents=True, exist_ok=True)

bracken = pd.read_csv(args.bracken, sep="\t", dtype={"taxonomy_id": str})
profile = (
    bracken[bracken["new_est_reads"] > 0]
    .merge(representatives, left_on="taxonomy_id", right_on="taxid")
    .loc[lambda d: d["genome_id"].isin(available)]
    .groupby("genome_id", as_index=False)["new_est_reads"].sum()
)
profile["abundance"] = profile["new_est_reads"] / profile["new_est_reads"].sum()
profile["genome_path"] = [str((args.genomes_dir / f"{g}.fna").resolve()) for g in profile["genome_id"]]

out = args.outdir / f"{args.sample_id}_abundance.tsv"
profile.sort_values("abundance", ascending=False)[["genome_path", "abundance"]].to_csv(out, sep="\t", index=False, header=False)
print(f"{args.sample_id}: {len(profile)} genomes -> {out}")
