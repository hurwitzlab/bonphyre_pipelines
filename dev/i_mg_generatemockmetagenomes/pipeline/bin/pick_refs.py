#!/usr/bin/env python3
"""Pick random spike-in genomes for each sample dir and write its conditions (og design).

The og design is the PI's original single/equal/unequal ART samples. Each {type}/sample{n}/
(n = 1..--replicates) gets contigs.fasta, refs_log.txt and conditions.tsv
(condition<TAB>comma-separated per-genome coverages, in contigs.fasta order).
"""
import argparse
import random
from pathlib import Path

from Bio import SeqIO

COVERAGES = [0.1, 0.5, 1, 10]
EQUAL_CONDITIONS = lambda n: {f"{c:g}x": [c] * n for c in COVERAGES}
# {type: {condition: [per-genome coverages]}}; a type's genome count is its number of coverages
OG_DESIGN = {
    "single":   EQUAL_CONDITIONS(1),
    "equal2":   EQUAL_CONDITIONS(2),
    "equal3":   EQUAL_CONDITIONS(3),
    "equal4":   EQUAL_CONDITIONS(4),
    "unequal2": {"10x_1x": [10, 1], "1x_0.5x": [1, 0.5]},
    "unequal3": {"10x_1x_0.5x": [10, 1, 0.5], "1x_0.5x_0.1x": [1, 0.5, 0.1]},
}

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--replicates", type=int, required=True, help="Sample dirs per type")
parser.add_argument("--seed", type=int, required=True)
parser.add_argument("--accessions", type=Path, required=True, help="Genome pool, one accession per line")
parser.add_argument("--genomes-dir", type=Path, required=True, help="Holds <accession>.fasta for every accession")
parser.add_argument("--outdir", type=Path, required=True)
args = parser.parse_args()

random.seed(args.seed)
accessions = args.accessions.read_text().split()

n_samples = 0
for name, conditions in OG_DESIGN.items():
    n_viruses = len(next(iter(conditions.values())))
    for rep in range(1, args.replicates + 1):
        out_dir = args.outdir / name / f"sample{rep}"
        out_dir.mkdir(parents=True, exist_ok=True)
        refs = random.sample(accessions, n_viruses)

        (out_dir / "refs_log.txt").write_text("".join(f"{r}\n" for r in refs))
        records = [next(SeqIO.parse(str(args.genomes_dir / f"{r}.fasta"), "fasta")) for r in refs]
        SeqIO.write(records, str(out_dir / "contigs.fasta"), "fasta")

        with open(out_dir / "conditions.tsv", "w") as f:
            for condition, coverages in conditions.items():
                f.write(f"{condition}\t{','.join(f'{c:g}' for c in coverages)}\n")
        n_samples += 1

print(f"Wrote {n_samples} sample dirs under {args.outdir}")
