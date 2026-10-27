#!/usr/bin/env Rscript
# Script to filter viral outputs from genomad using checkv and coverage information
# Author: Mery Touceda-Suarez from Alise Ponsero's work (https://github.com/aponsero/HPC_ViralDetection/blob/main/config_scripts/FilterViral.R)
# Date: February 18th 2026


library(tidyverse)

args<-commandArgs(TRUE)

## Input files and directories
genomad_checkV_file=args[1]
coverage_file=args[2]
name=args[3]  # sample name


# Read CheckV output
genomad_checkV <- read_tsv(genomad_checkV_file) %>% 
  mutate(genomad=TRUE)


# Read coverage file
coverage <- read_tsv(coverage_file) %>% 
  rename("ID"=`#ID`) %>%
  separate(ID, into=c("contig_id", "flag", "multi", "len"), sep=" ", remove = FALSE)


# selection CheckV 
# has to have either a viral gene or no host genes
genomad_checkV <- genomad_checkV %>% filter((viral_genes>0) | (host_genes==0))

# Coverage info and filter contigs <1500bp
merge_table <- left_join(genomad_checkV, coverage) 
merge_table <- merge_table %>% 
  # keep phages with > 5x coverage
  filter(Median_fold>=5) %>%
  relocate(contig_id, contig_length, genomad) %>%
  # filter length
  filter(contig_length > 1500)


# print table of viruses that passed filters
total_table <- paste(name, "selection1.csv", sep="_") # create name
write_csv(merge_table, total_table)
