#!/usr/bin/env Rscript
# Parse outputs for benchmark of viral inference tools into one standard table
# output cols: sampleid | tool | contig | score | call
#   score = tool's viral score (plasmid score for geNomad plasmid rows)
#   call  = V (virus), P (plasmid), O (other / not called)

# load packages
suppressPackageStartupMessages({
  library(optparse)
  library(readr)
  library(dplyr)})

tools <- c("deepmicroclass2", "deepvirfinder", "genomad", "viralm", "virrep", "virsorter2")

# argument list
option_list <- list(
  make_option(c("-t", "--tool"), type = "character",
              help = paste("Tool:", paste(tools, collapse = ", "))),
  make_option(c("-i", "--input"), type = "character",
              help = "Tool output file, or the tool output directory (file found by name)"),
  make_option(c("-p", "--plasmid"), type = "character", default = NULL,
              help = "geNomad *_plasmid_summary.tsv (optional; found automatically when --input is a directory)"),
  make_option(c("-s", "--sampleid"), type = "character", default = "NA",
              help = "Sample id written to the sampleid column"),
  make_option(c("-o", "--output"), type = "character",
              help = "Output TSV"),
  make_option("--dvf_score", type = "double", default = 0.9,
              help = "DeepVirFinder min score for a V call [default %default]"),
  make_option("--dvf_pvalue", type = "double", default = 0.05,
              help = "DeepVirFinder max p-value for a V call [default %default]"),
  make_option("--virrep_score", type = "double", default = 0.5,
              help = "VirRep min score for a V call [default %default]"))

opt <- parse_args(OptionParser(option_list = option_list))

# missing input error
if (is.null(opt$tool) || is.null(opt$input) || is.null(opt$output)) {
  stop("--tool, --input and --output are required. Run with --help for usage.")
}
if (!opt$tool %in% tools) {
  stop("Unknown --tool '", opt$tool, "'. Choose one of: ", paste(tools, collapse = ", "))
}

# input can be the tool's output directory: find the file by its name pattern
patterns <- c(deepmicroclass2 = "classification\\.tsv$",
              deepvirfinder   = "_dvfpred\\.txt$",
              genomad         = "_virus_summary\\.tsv$",
              viralm          = "^result_.*\\.csv$",
              virrep          = "_score\\.tsv$",
              virsorter2      = "^final-viral-score\\.tsv$")

find_file <- function(dir, pattern) {
  hits <- list.files(dir, pattern = pattern, full.names = TRUE, recursive = TRUE)
  if (length(hits) != 1) stop("Expected 1 file matching '", pattern, "' in ", dir,
                              ", found ", length(hits), ": ", paste(hits, collapse = ", "))
  hits
}

if (dir.exists(opt$input)) {
  in_dir    <- opt$input
  opt$input <- find_file(in_dir, patterns[[opt$tool]])
  if (opt$tool == "genomad" && is.null(opt$plasmid) &&
      length(list.files(in_dir, "_plasmid_summary\\.tsv$", recursive = TRUE)) > 0) {
    opt$plasmid <- find_file(in_dir, "_plasmid_summary\\.tsv$")
  }
}

# contig ID = first word, before any '|' (VirSorter2 '||full', geNomad '|provirus_x_y')
clean_id <- function(x) sub("[[:space:]|].*$", "", x)

# parse, one function per tool -> tibble(contig, score, call)
parse_deepmicroclass2 <- function(f) {
  read_tsv(f, show_col_types = FALSE) %>%
    transmute(contig = clean_id(contig),
              score  = round(eukvir + prokvir, 4),
              call   = case_when(label %in% c("eukvir", "prokvir") ~ "V",
                                 label == "pls" ~ "P",
                                 TRUE ~ "O"))
}

parse_deepvirfinder <- function(f) {
  read_tsv(f, show_col_types = FALSE) %>%
    transmute(contig = clean_id(name),
              score,
              call = if_else(score >= opt$dvf_score & pvalue < opt$dvf_pvalue, "V", "O"))
}

parse_genomad <- function(f) {
  vir <- read_tsv(f, show_col_types = FALSE) %>%
    transmute(contig = clean_id(seq_name), score = virus_score, call = "V")
  pls <- if (is.null(opt$plasmid)) NULL else
    read_tsv(opt$plasmid, show_col_types = FALSE) %>%
      transmute(contig = clean_id(seq_name), score = plasmid_score, call = "P")
  bind_rows(vir, pls)
}

parse_viralm <- function(f) {
  read_csv(f, show_col_types = FALSE) %>%
    transmute(contig = clean_id(seq_name),
              score  = virus_score,
              call   = if_else(prediction == "virus", "V", "O"))
}

parse_virrep <- function(f) {
  read_tsv(f, show_col_types = FALSE) %>%
    transmute(contig = clean_id(seqname),
              score,
              call = if_else(score >= opt$virrep_score, "V", "O"))
}

parse_virsorter2 <- function(f) {
  read_tsv(f, show_col_types = FALSE) %>%
    transmute(contig = clean_id(seqname), score = max_score, call = "V")
}

parsed_inf <- get(paste0("parse_", opt$tool))(opt$input)

# one row per contig: several proviruses/partials per contig -> keep best call, then max score
parsed_inf <- parsed_inf %>%
  mutate(rank = match(call, c("V", "P", "O"))) %>%
  arrange(contig, rank, desc(score)) %>%
  distinct(contig, .keep_all = TRUE) %>%
  transmute(sampleid = opt$sampleid, tool = opt$tool, contig, score, call)

# save output
write_tsv(parsed_inf, opt$output)
