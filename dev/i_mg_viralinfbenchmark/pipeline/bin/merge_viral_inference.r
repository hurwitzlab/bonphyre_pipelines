#!/usr/bin/env Rscript
# Merge parsed outputs (parse_viral_inference.r) of the viral inference tools
# outputs: <prefix>_long.tsv  (sampleid | tool | contig | score | call)
#          <prefix>_calls.tsv (sampleid | contig | one V/P/O column per tool)

# load packages
suppressPackageStartupMessages({
  library(optparse)
  library(readr)
  library(dplyr)
  library(tidyr)})

# argument list
option_list <- list(
  make_option(c("-c", "--contigs"), type = "character", default = NULL,
              help = "Contigs FASTA; if given, every contig gets a row (O when no tool reports it)"),
  make_option(c("-s", "--sampleid"), type = "character", default = NULL,
              help = "Sample id for --contigs rows (required with --contigs)"),
  make_option(c("-o", "--prefix"), type = "character",
              help = "Output prefix"))

parser <- OptionParser(usage = "%prog [options] parsed1.tsv parsed2.tsv ...", option_list = option_list)
args   <- parse_args(parser, positional_arguments = c(1, Inf))
opt    <- args$options
files  <- args$args

# missing input error
if (is.null(opt$prefix)) stop("--prefix is required. Run with --help for usage.")
if (!is.null(opt$contigs) && is.null(opt$sampleid)) stop("--sampleid is required with --contigs.")

# import data
long <- bind_rows(lapply(files, read_tsv, show_col_types = FALSE,
                         col_types = cols(sampleid = "c", tool = "c", contig = "c",
                                          score = "d", call = "c")))

# wide table of calls; contigs a tool did not report -> O
calls <- long %>%
  select(sampleid, contig, tool, call) %>%
  pivot_wider(names_from = tool, values_from = call)

if (!is.null(opt$contigs)) {
  ids <- sub("^>([^[:space:]|]+).*$", "\\1", grep("^>", readLines(opt$contigs), value = TRUE))
  calls <- full_join(tibble(sampleid = opt$sampleid, contig = ids), calls,
                     by = c("sampleid", "contig"))
}

tool_cols <- setdiff(names(calls), c("sampleid", "contig"))
calls <- calls %>%
  mutate(across(all_of(tool_cols), ~ replace_na(.x, "O"))) %>%
  arrange(sampleid, contig)

# save output
write_tsv(long,  paste0(opt$prefix, "_long.tsv"))
write_tsv(calls, paste0(opt$prefix, "_calls.tsv"))
