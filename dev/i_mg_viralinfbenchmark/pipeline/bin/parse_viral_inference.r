#!/usr/bin/env Rscript
# Parse outputs for benchmark of viral inference tools into one standard table
# output cols: sampleid | tool | contig | score | call
#   score  = tool's viral score (NA if the tool gives none, e.g. VirSorter2 lt2gene)
#   call   = 1 if the tool calls the contig viral, 0 if scored but not called

# load packages
suppressPackageStartupMessages({
  library(optparse)
  library(readr)
  library(dplyr)})

# contig ID = first word, before any '|' (VirSorter2 '||full', geNomad '|provirus_x_y')
clean_id <- function(x) sub("[[:space:]|].*$", "", x)

# tools: file pattern (used when --input is a directory) + parse function -> tibble(contig, score, call)
# to add a tool: add one entry here
tools <- list(
  deepmicroclass2 = list(
    pattern = "classification\\.tsv$",
    parse   = function(f) read_tsv(f, show_col_types = FALSE) %>%
      transmute(contig = clean_id(contig),
                score  = round(eukvir + prokvir, 4),   # class probs sum to 1 -> P(viral)
                call   = as.integer(label %in% c("eukvir", "prokvir")))),

  deepvirfinder = list(
    pattern = "_dvfpred\\.txt$",
    parse   = function(f) read_tsv(f, show_col_types = FALSE) %>%
      transmute(contig = clean_id(name), score,
                call = as.integer(score >= opt$dvf_score & pvalue < opt$dvf_pvalue))),

  genomad = list(
    pattern = "_virus_summary\\.tsv$",
    parse   = function(f) read_tsv(f, show_col_types = FALSE) %>%
      transmute(contig = clean_id(seq_name), score = virus_score, call = 1L)),

  viralm = list(
    pattern = "^result_.*\\.csv$",
    parse   = function(f) read_csv(f, show_col_types = FALSE) %>%
      transmute(contig = clean_id(seq_name), score = virus_score,
                call = as.integer(prediction == "virus"))),

  virrep = list(
    pattern = "_score\\.tsv$",
    parse   = function(f) read_tsv(f, show_col_types = FALSE) %>%
      transmute(contig = clean_id(seqname), score,
                call = as.integer(score >= opt$virrep_score))),

  seeker = list(
    pattern = "seeker_predictions\\.tsv$",
    parse   = function(f) read_tsv(f, show_col_types = FALSE) %>%
      transmute(contig = clean_id(name), score,                 # score = phage score
                call = as.integer(prediction == "Phage"))),

  virsorter2 = list(
    pattern = "^final-viral-score\\.tsv$",
    parse   = function(f) read_tsv(f, show_col_types = FALSE, na = c("", "NA", "nan")) %>%
      transmute(contig = clean_id(seqname), score = max_score, call = 1L))
)

# argument list
option_list <- list(
  make_option(c("-t", "--tool"), type = "character",
              help = paste("Tool:", paste(names(tools), collapse = ", "))),
  make_option(c("-i", "--input"), type = "character",
              help = "Tool output file, or the tool output directory (file found by name)"),
  make_option(c("-s", "--sampleid"), type = "character", default = "NA",
              help = "Sample id written to the sampleid column"),
  make_option(c("-o", "--output"), type = "character",
              help = "Output TSV"),
  make_option("--dvf_score", type = "double", default = 0.9,
              help = "DeepVirFinder min score for a viral call [default %default]"),
  make_option("--dvf_pvalue", type = "double", default = 0.05,
              help = "DeepVirFinder max p-value for a viral call [default %default]"),
  make_option("--virrep_score", type = "double", default = 0.5,
              help = "VirRep min score for a viral call [default %default]"))

opt <- parse_args(OptionParser(option_list = option_list))

# missing input error
if (is.null(opt$tool) || is.null(opt$input) || is.null(opt$output)) {
  stop("--tool, --input and --output are required. Run with --help for usage.")
}
if (!opt$tool %in% names(tools)) {
  stop("Unknown --tool '", opt$tool, "'. Choose one of: ", paste(names(tools), collapse = ", "))
}
tool <- tools[[opt$tool]]

# input can be the tool's output directory: find the file by its name pattern
if (dir.exists(opt$input)) {
  hits <- list.files(opt$input, pattern = tool$pattern, full.names = TRUE, recursive = TRUE)
  if (length(hits) != 1) stop("Expected 1 file matching '", tool$pattern, "' in ", opt$input,
                              ", found ", length(hits), ": ", paste(hits, collapse = ", "))
  opt$input <- hits
}

# parse; one row per contig: several proviruses/partials -> keep the call, then the max score
parsed_inf <- tool$parse(opt$input) %>%
  arrange(contig, desc(call), desc(score)) %>%
  distinct(contig, .keep_all = TRUE) %>%
  transmute(sampleid = opt$sampleid, tool = opt$tool, contig, score, call)

# save output
write_tsv(parsed_inf, opt$output)
