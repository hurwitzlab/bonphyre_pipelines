# i_mg_viralinferencegenomad: Setup and Usage Guide

## 1. What this pipeline does

`i_mg_viralinferencegenomad` is a Nextflow pipeline for finding viruses in Illumina paired-end metagenomes. It runs these stages, in order:

| Stage | Tools | Output |
|---|---|---|
| 1. Read QC | BBDuk (adapter trimming), Trimmomatic (quality trimming), seqkit (read counts) | Clean reads per sample |
| 2. Assembly | MEGAHIT | Contigs per sample |
| 3. Viral identification and filtering | geNomad, CheckV, BBMap (bbwrap and pileup coverage), a custom R/Python filter | Viral and proviral sequences per sample |
| 4. Clustering | MMseqs2 (`easy-cluster`) | One clustered viral catalog across all samples |
| 5. Read mapping and abundance | BWA, samtools, CoverM | One abundance table (samples × viral clusters) |

Every stage also records QC metrics, which are combined into one summary table at the end (section 8).

## 2. Requirements

- **Nextflow** ≥ 22.10.0 (https://www.nextflow.io/docs/latest/install.html)
- **Java** 11 or later (Nextflow needs it)
- **Singularity or Apptainer.** Every tool runs inside a container, so you don't install any of the tools yourself.
- **A SLURM cluster** (recommended) or a single machine with enough memory. The largest steps request 72 GB of RAM, and 144 GB if they're retried.
- **Reference databases:** a geNomad database (`genomad download-database <dir>`), a CheckV database (`checkv download_database <dir>`), and an Illumina adapter FASTA (BBMap's `resources/adapters.fa` works).

> **On NC State's Hazel cluster**, Nextflow, Java and Apptainer are already available as BRC modules: `module use /usr/local/usrapps/brc/brc_modules/modules` then `module load nextflow java/17 apptainer`. Members of the Hurwitz lab also already have access to the databases and container images.

## 3. Which files do I have to edit?

That depends on who you are. Find your row, do what it says, and skip what you don't need in section 5.

| You are... | Files you edit | Profile you run with |
|---|---|---|
| **A member of BONPHYRE / the Hurwitz lab** | Only `workflows/i_mg_viralinferencegenomad/i_mg_viralinferencegenomad.config` | `-profile hazel` |
| **At NC State, but not in the Hurwitz lab** | The workflow config above, **plus** `conf/site.config` and the queue/account lines in `conf/base.config` | `-profile hazel` |
| **At a different organization** | The workflow config, `conf/site.config`, the queue/account lines in `conf/base.config`, **plus** a new profile in `nextflow.config` | `-profile <your_profile>` |

Why the split: the files are layered from "specific to this run" down to "specific to this computer" (section 4 explains each one). The Hurwitz lab's paths and cluster settings are already the defaults, so lab members only need to tell the pipeline about their own data. Other NC State users run on the same cluster (Hazel) but can't read the lab's database and container folders, and can't submit jobs to the lab's Slurm account, so they also point the pipeline at their own copies and their own account. Users elsewhere also need to describe their own cluster.

> **Why `base.config`?** It sends every job to the Hurwitz lab's Slurm queue and account (`queue = 'compute_partners'` and `clusterOptions = '--account=ivirus_cpu --qos=p_brc'`). If you're not in the lab, Slurm rejects those jobs, so you have to change these two lines (section 5.4).

## 4. How the configuration files work

### 4.1 The four files

```
nextflow_pipelines/
├── nextflow.config        ← HOW to run: one profile per cluster
├── conf/
│   ├── site.config        ← WHERE things are: databases, images, results
│   └── base.config        ← HOW MUCH: Slurm queue/account, CPU/memory/time
└── workflows/i_mg_viralinferencegenomad/
    ├── i_mg_viralinferencegenomad.nf       ← the workflow (never edit to run it)
    └── i_mg_viralinferencegenomad.config   ← WHAT to run: inputs, tools, settings
```

| File | Scope | What it holds |
|---|---|---|
| `i_mg_viralinferencegenomad.config` | This pipeline only | Pipeline name and version, the `reads` input, database file paths, the `container__*` image for every tool, every tool parameter (BBDuk k-mers, Trimmomatic cutoffs, MMseqs2 identity, CoverM metric...), and the QC warning thresholds. It's the file you run with `-c`, and it pulls in the other three. |
| `conf/site.config` | Every pipeline in the repo, on one computer | Four folder paths: `databases_dir` (root of the reference databases), `singularity_images_dir` (released `.sif` images), `singularity_images_dev` (images still in development) and `data_lake_dir` (where all results go). |
| `conf/base.config` | Every pipeline in the repo | The Slurm queue and account every job is submitted to (the Hurwitz lab's, by default), the CPU/memory/time for each resource label (`process_single`, `process_low`, `process_medium`, `process_high`), the retry rule, and the `publish_*` labels that decide where outputs are saved. |
| `nextflow.config` | Every pipeline in the repo | The **profiles**. A profile is a named block of settings for one kind of computer: which executor (Slurm, local...), how to turn on Singularity, the largest job allowed, and where the `work/` folder goes. `hazel` is NC State's cluster; `hazel_test` runs everything on the node you're logged in to, for quick tests. |

### 4.2 How they're loaded

You give Nextflow only the workflow config (`-c ...i_mg_viralinferencegenomad.config`). Its first lines pull in the rest:

```groovy
params.pipeline_name    = 'i_mg_viralinferencegenomad'
params.workflow_version = '1.0.0'

includeConfig '../../conf/site.config'   // where things are
includeConfig '../../conf/base.config'   // how much each job gets
includeConfig '../../nextflow.config'    // profiles

params.project_id = null
params.outdir = "${params.data_lake_dir}/${params.project_id}/" +
                "${params.pipeline_name}/${params.workflow_version}"

params {
    reads              = ...
    genomad_db         = "${params.databases_dir}/genomad_db/genomad_db/"
    container__genomad = "${params.singularity_images_dir}/...genomad...sif"
    ...
}
```

Three things follow from this order:

1. **Lower files define names that higher files use.** `site.config` sets `databases_dir` and `singularity_images_dir`. The workflow config never writes a full path itself: it builds every path from those names, e.g. `genomad_db = "${params.databases_dir}/genomad_db/genomad_db/"`. That's why moving to a new computer means changing four lines in `site.config` instead of every path in the workflow config.
2. **`site.config` comes first** because `outdir` is built from `data_lake_dir`, and `outdir` has to exist before anything that uses it. `nextflow.config` includes `site.config` and `base.config` again; loading a file twice is harmless.
3. **`-profile` picks one block** out of `nextflow.config`. Settings inside the chosen profile are applied on top of the defaults in `base.config`. For example, `hazel` adds `executor = 'slurm'` and a 128 GB memory ceiling.

### 4.3 Which value wins

When the same setting is defined in more than one place, Nextflow uses the one that comes **last**, and command-line values beat all files:

```
lowest   site.config / base.config
   ↓     nextflow.config (+ the -profile you chose)
   ↓     workflow config
   ↓     -params-file
highest  --flags on the command line
```

So for a one-off change you don't edit a file at all. `--trimmomatic_minlen 60` or `--reads '/my/reads/*_R{1,2}.fastq.gz'` overrides the value in the workflow config for that run only. Edit a file only to change a value **every time** you run.

### 4.4 Where results go

`outdir` is built for you, so you don't pass it:

```
<data_lake_dir>/<project_id>/i_mg_viralinferencegenomad/<workflow_version>/
```

`data_lake_dir` comes from `site.config`, `--project_id` from the command line (it's required; the run stops without it), and the name and version from the workflow config. Different projects, pipelines and versions never write over each other. With `-profile hazel`, Nextflow's `work/` folder also goes under the data lake: `<data_lake_dir>/nf_work`.

## 5. Setting it up

### 5.1 Get the code

The pipeline lives in the **bonphyre_pipelines** repo. Its tool modules (BBDuk, MEGAHIT, geNomad, and so on) live in a separate shared repo, **nextflow_process_library**. The two must be cloned **side by side** in the same parent folder, because the workflow loads modules through relative paths like `../../../nextflow_process_library/modules/genomad/genomad.nf`:

```
mkdir -p ~/nf_repos && cd ~/nf_repos
git clone https://github.com/hurwitzlab/bonphyre_pipelines.git
git clone https://github.com/hurwitzlab/nextflow_process_library.git
```

```
nf_repos/
├── bonphyre_pipelines/
│   └── nextflow_pipelines/        ← run from here
│       ├── build.sh  nextflow.config  conf/
│       ├── workflows/i_mg_viralinferencegenomad/
│       └── subworkflows/  modules/  bin/
└── nextflow_process_library/
    └── modules/<tool>/<tool>.nf
```

You can run the pipeline straight from this clone. If you'd rather have one small folder with only the files this pipeline needs (e.g. to copy to another cluster), see section 5.6.

### 5.2 Everyone: the workflow config

Open `nextflow_pipelines/workflows/i_mg_viralinferencegenomad/i_mg_viralinferencegenomad.config`.

- **`reads`**: a glob matching your paired FASTQ files (section 6). You can leave the default and pass `--reads` on the command line instead.
- **Tool parameters and QC thresholds**: the defaults work for most data. Change them here only if you want a different default every time.
- **Database paths** (`illumina_adapters_file`, `genomad_db`, `checkv_db`) and **containers** (`container__*`): Hurwitz lab members leave these alone. Everyone else checks that the part after `${params.databases_dir}/` or `${params.singularity_images_dir}/` matches the file and folder names in their own copies.

**BONPHYRE / Hurwitz lab members: you're done. Go to section 7.**

### 5.3 Everyone outside the Hurwitz lab: site.config

Open `nextflow_pipelines/conf/site.config` and point the four folders at places you can read and write:

```groovy
params {
    // folder holding adapters/, genomad_db/, checkv_db/
    databases_dir          = '/path/to/your/databases'
    // released .sif images, and images in development (can be the same folder)
    singularity_images_dir = '/path/to/your/sif/images'
    singularity_images_dev = '/path/to/your/sif/images'
    // results and Nextflow's work/ go under here
    data_lake_dir          = '/share/<group>/<you>'
}
```

Use absolute paths that start with `/`. Then change the Slurm queue and account (section 5.4). To make a `.sif` image from a public container (names are in the `container__*` lines of the workflow config):

```
singularity pull quay.io_biocontainers_megahit:1.2.9--h8b12597_0.sif \
    docker://quay.io/biocontainers/megahit:1.2.9--h8b12597_0
```

Keep using `-profile hazel`.

### 5.4 Everyone outside the Hurwitz lab: queue and account in base.config

Open `nextflow_pipelines/conf/base.config`. The first lines of the `process { }` block send every job to the Hurwitz lab's Slurm queue and account:

```groovy
process {
    queue          = 'compute_partners'
    clusterOptions = '--account=ivirus_cpu --qos=p_brc'
    ...
```

Change them to a partition and account you're allowed to submit to:

```groovy
    queue          = 'your_partition'
    clusterOptions = '--account=your_account'
```

If your cluster doesn't need either one, delete the two lines and Slurm uses your defaults. To see the partitions and accounts you can use, run `sinfo -s` and `sacctmgr show associations user=$USER format=account,partition,qos`. At NC State, you can also ask your PI or HPC support.

Leave the rest of `base.config` (resource labels, retries, publish labels) as it is.

### 5.5 Other organizations: add a profile to nextflow.config

Do 5.2, 5.3 and 5.4, then add a profile for your computer inside the `profiles { }` block of `nextflow_pipelines/nextflow.config`. Copy the `hazel` block, rename it, and change:

```groovy
profiles {
    hazel { ... }

    my_cluster {
        workDir = "${params.data_lake_dir}/nf_work"

        process {
            executor     = 'slurm'                   // or sge, pbs, lsf, local
            queue        = 'my_queue'                // if your site requires one
            beforeScript = 'module load apptainer'   // delete if already on PATH

            resourceLimits = [                       // largest job one node takes
                memory: 256.GB,
                cpus:   32,
                time:   72.h
            ]
        }

        singularity {
            enabled    = true
            autoMounts = true
            cacheDir   = '/scratch/<you>/sif_cache'   // writable, lots of space
        }
    }
}
```

Don't edit the workflow's `.nf` or `.config` to describe your cluster. That's what the profile is for, and it keeps the pipeline files identical everywhere. Run with `-profile my_cluster`.

### 5.6 Optional: build a self-contained copy

`build.sh` copies only the files this workflow uses, from both repos, into one folder you can move anywhere:

```
cd ~/nf_repos/bonphyre_pipelines/nextflow_pipelines
./build.sh i_mg_viralinferencegenomad ~/my_pipelines/viralinferencegenomad_build
```

Usage: `./build.sh [-n <pipeline_name>] <workflow_name> <output_dir>`. `<output_dir>` must not exist yet. Run `./build.sh --help` for details.

It follows every `include` and `includeConfig` from the workflow, copies just those files (plus any `bin/` script they call), moves `nextflow_process_library/` inside the copy, and rewrites the include paths to match. Then it runs Nextflow once as a smoke test:

```
viralinferencegenomad_build/
├── build_manifest.txt          ← every file that was copied
├── build_validation.log        ← output of the smoke test
└── i_mg_viralinferencegenomad/
    ├── pipeline/               ← same layout as nextflow_pipelines/; run from here
    └── nextflow_process_library/
```

In `build_validation.log`, errors about missing reads, databases or containers are **expected** (the smoke test has none of your data). `Script compilation failed` is a **real problem**: read the message under it. The config files in the copy work exactly as in section 4, so edit them in `pipeline/`. Keep `pipeline/` and `nextflow_process_library/` together. To pick up updates, `git pull` both repos and build into a new folder.

## 6. Preparing input data

The pipeline takes **paired-end, gzipped FASTQ files**. Each R1 and R2 pair must share a sample name:

```
reads/
├── sampleA_R1.fastq.gz
├── sampleA_R2.fastq.gz
├── sampleB_R1.fastq.gz
└── sampleB_R2.fastq.gz
```

The text before `_R1` / `_R2` becomes the sample ID, and the glob is `'/path/to/reads/*_R{1,2}.fastq.gz'`. If your files are named differently (e.g. `_1.fq.gz`), change the glob to `'*_{1,2}.fq.gz'`.

## 7. Running the pipeline

Run from `nextflow_pipelines/` (or `pipeline/` in a built copy):

```
nextflow run workflows/i_mg_viralinferencegenomad/i_mg_viralinferencegenomad.nf \
    -c workflows/i_mg_viralinferencegenomad/i_mg_viralinferencegenomad.config \
    -profile hazel \
    --reads '/path/to/reads/*_R{1,2}.fastq.gz' \
    --project_id my_project \
    -resume
```

- **`-c` is required.** It's how the workflow config, and through it every other config, gets loaded.
- **`--project_id` is required** and becomes part of the output path.
- **Put the `--reads` glob in single quotes** so Nextflow expands it, not your shell.
- **`-resume`** restarts a failed or interrupted run without redoing the steps that already finished. It's safe to always include it.
- To keep your settings in a file instead of flags, put them in a YAML file and add `-params-file my_params.yaml`.

On a cluster, don't run Nextflow on the login node. Submit the launch command itself as a small, long-running job. On Hazel, `nextflow_pipelines/submit_hazel.sh` does this: edit `--project_id` (and add `--reads`), then `sbatch submit_hazel.sh`. Nextflow then submits every pipeline step as its own Slurm job.

## 8. Outputs

All results go under one folder per run:

```
<data_lake_dir>/<project_id>/i_mg_viralinferencegenomad/1.0.0/
```

Inside it, there's one folder per sample, one `viral_catalog/` folder for the steps that combine all samples, and `pipeline_info/`. Each subfolder is named after the step (Nextflow process) that wrote it. Steps not listed here (bbwrap, seqkit, samtools sorting, the QC-metric steps) don't save anything to the output folder; their files stay in `work/`.

```
<sampleid>/
├── bbduk/                   ↪ <sampleid>_adapter_trimmed_r{1,2}.fastq.gz
├── trimmomatic/             <sampleid>_clean_r{1,2}.fastq.gz
├── megahit/assembly/        contigs.fa
├── genomad/                 contigs_summary/
├── checkv/                  quality/
├── pileup/                  coverage.txt
├── filter_viral_contigs/    ↪ <sampleid>_selection1.csv
├── extract_fasta_viral_selection/
│   └── viral_selection/     <sampleid>_sel1_viral.fa
│                            <sampleid>_sel1_provirus.fa
│                            <sampleid>_map_virus.csv
│                            <sampleid>_map_provirus.csv
└── index_bam/               <sampleid>.sorted.bam (+ .bai)

viral_catalog/
├── viral_catalog.fna
├── mmseqs_easy_cluster/     viral_catalog_rep_seq.fasta
│                            viral_catalog_cluster.tsv
├── bwa_index/               ↪ index of viral_catalog_rep_seq.fasta
└── coverm/                  viral_catalog.txt

pipeline_info/
└── metrics_summary.tsv
```

↪ = symlink into `work/` (see below). Everything else is a real copy.

What the main files are:

| File | What it is |
|---|---|
| `genomad/contigs_summary/`, `checkv/quality/`, `pileup/coverage.txt` | geNomad's virus and plasmid calls, CheckV's completeness and contamination estimates, and the read coverage of each contig. The viral filter uses all three. |
| `filter_viral_contigs/<sampleid>_selection1.csv` | The contigs that passed the viral filter. |
| `trimmomatic/<sampleid>_clean_r{1,2}.fastq.gz` | Clean reads after adapter and quality trimming. These are used for assembly and mapping. |
| `megahit/assembly/contigs.fa` | The sample's assembly. |
| `extract_fasta_viral_selection/viral_selection/*_sel1_viral.fa`, `*_sel1_provirus.fa` | The sample's viral and proviral sequences after the geNomad/CheckV/coverage filter. Sequence names start with the sample ID, so they stay unique once samples are combined. The `*_map_*.csv` files link each new name back to its original contig. |
| `viral_catalog/viral_catalog.fna` | Every sample's viral and proviral sequences, concatenated, before clustering. |
| `viral_catalog/mmseqs_easy_cluster/viral_catalog_cluster.tsv` | Which sequence belongs to which cluster (representative, member). |
| `viral_catalog/mmseqs_easy_cluster/viral_catalog_rep_seq.fasta` | The clustered viral catalog: one representative sequence per cluster of near-identical sequences (≥ 95% identity, ≥ 85% coverage by default). |
| `viral_catalog/coverm/viral_catalog.txt` | The abundance table. One row per catalog sequence and one column per sample. The values are read counts by default (`coverm_m`). |
| `index_bam/<sampleid>.sorted.bam` | The sample's clean reads mapped to the catalog, with unmapped reads removed. |
| `pipeline_info/metrics_summary.tsv` | Per-sample QC: raw and clean reads, % of reads kept, number of contigs, number of viral sequences, mean CheckV completeness, mean coverage, and % of reads that mapped to the catalog. |

Things to know:

- **Symlinked outputs (↪) break if you clear `work/`.** The pipeline doesn't delete `work/` (so `-resume` keeps working), and it gets large, mostly from each sample's SAM file. Once you've checked a run's results, clear it with `nextflow clean -f` or by deleting `<data_lake_dir>/nf_work`. If you need the adapter-trimmed reads, the filter table or the BWA index afterwards, copy them out first.
- **QC warnings appear in the console log** during the run, e.g. when a sample keeps fewer than 50% of its reads after trimming, yields no viral contigs, or has under 1% of its reads mapping to the catalog. The run doesn't stop for these, but check them. The thresholds are the `qc_*` parameters in the workflow config.
- **A sample that drops out partway shows `NA`** in the later columns of `metrics_summary.tsv`.

## 9. Resources and retries

Each step has a resource label (`process_single`, `process_low`, `process_medium`, `process_high`) defined in `conf/base.config`. A task that fails from running out of memory or time (exit codes 104 or 130–145) is retried **once** with double the CPU, memory and time. Your profile's `resourceLimits` caps what any job can ask for. To change how much a step requests, edit its label in `base.config`.

## 10. Troubleshooting

| Symptom | Likely cause |
|---|---|
| `Missing required parameter --project_id` | Add `--project_id <name>` |
| `No files match pattern` / reads not found | The `--reads` glob is wrong or wasn't quoted |
| Errors about undefined parameters (`params.reads`, `params.genomad_db`...) | `-c` was left off, so the workflow config never loaded |
| `Unknown config file` | The command wasn't run from `nextflow_pipelines/`, so the `-c` path is wrong |
| `Cannot find container` / `.sif` not found | A `container__*` file name doesn't exist in `singularity_images_dir` (`site.config`) |
| Database path not found | `databases_dir` in `site.config`, or the subfolder name in the workflow config, doesn't match your copy |
| Slurm rejects jobs: invalid account / QOS / partition | Change `queue` and `clusterOptions` in `conf/base.config` |
| `Unknown configuration profile` | The `-profile` name doesn't match a block in `nextflow.config` |
| Task killed with exit 137/140 | Not enough memory or time. Raise the label in `base.config` or the profile's `resourceLimits` |
| Tool can't write to `/tmp` | Bind your scratch folder in `singularity.runOptions` (the `hazel` profile shows how) |

To debug a failed task, open its `work/xx/yyyy…` folder (the path is printed in the error) and read `.command.sh`, `.command.err` and `.command.log`.
