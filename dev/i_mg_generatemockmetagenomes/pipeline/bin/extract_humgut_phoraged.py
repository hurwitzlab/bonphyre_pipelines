#!/usr/bin/env python
"""Extract the representative genomes (04) from one phoraged HumGut tarball shard, as <genome_id>.fna.

The shards name genomes by HumGut_name; HumGut2.tsv maps those to the genome_file names 04 uses.
Usage: extract_humgut_phoraged.py --shard HumGut_phoraged_0.tar.gz --representatives representative_genomes.tsv
                                  --humgut-tsv HumGut2.tsv --outdir phoraged
"""
import argparse
import gzip
import shutil
import tarfile
from pathlib import Path

import pandas as pd

SUFFIX = "_phoraged.fasta.gz"

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--shard", type=Path, required=True, help="One HumGut_phoraged_*.tar.gz shard")
parser.add_argument("--representatives", type=Path, required=True, help="representative_genomes.tsv (04)")
parser.add_argument("--humgut-tsv", type=Path, required=True, help="HumGut2.tsv (HumGut_name -> genome_file)")
parser.add_argument("--outdir", type=Path, required=True)
args = parser.parse_args()

representatives = pd.read_csv(args.representatives, sep="\t")
humgut = pd.read_csv(args.humgut_tsv, sep="\t", usecols=["HumGut_name", "genome_file"])
needed = dict(representatives.merge(humgut, on="genome_file")[["HumGut_name", "genome_file"]].values)

args.outdir.mkdir(parents=True, exist_ok=True)
n = 0
# Stream mode ("r|gz"): one pass through the shard instead of decompressing it once per member
with tarfile.open(args.shard, "r|gz") as tar:
    for member in tar:
        humgut_name = Path(member.name).name.removesuffix(SUFFIX)
        if humgut_name not in needed:
            continue
        genome_id = needed[humgut_name].removesuffix(".gz").removesuffix(".fna")
        out = args.outdir / f"{genome_id}.fna"
        if out.exists():
            continue
        with gzip.open(tar.extractfile(member), "rt") as fin, open(out, "w") as fout:
            shutil.copyfileobj(fin, fout)
        n += 1

print(f"{args.shard.name}: extracted {n} genomes")
