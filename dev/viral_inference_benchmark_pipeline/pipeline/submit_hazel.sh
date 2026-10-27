#!/bin/bash
#SBATCH --job-name=test
#SBATCH --output=%j.out
#SBATCH --error=%j.err
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G

set -euo pipefail
echo "Running in: $PWD" #to make sure we are running on the right place

# --- ENV ---
# BRC-provided software modules (nextflow, apptainer, etc.) live under this path
module use /usr/local/usrapps/brc/brc_modules/modules
module load nextflow/26.04.3 java/17 apptainer
export NXF_APPTAINER_CACHEDIR="$APPTAINER_CACHEDIR"

# --- Launch the pipeline ---
nextflow run workflows/viral_inference_benchmark/viral_inference_benchmak.nf \
    -c workflows/viral_inference_benchmak/viral_inference_benchmak.config \
    -profile hazel \
    --project_id test \
    -resume
