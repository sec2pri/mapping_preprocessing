# Clear environment and load necessary libraries
rm(list = ls())
if(!"downloader" %in% installed.packages()){install.packages("downloader")}
require(downloader)
if(!"dplyr" %in% installed.packages()){install.packages("dplyr")}
library(dplyr)

# Set variables
sourceName <- "NCBI"
sourceVersion <- "2023-08-14"
inputDir <- "mapping_preprocessing/datasources"

# Create output directory
outputDir <- paste0 ("mapping_preprocessing/datasources/", sourceName, "/data")
dir.create(outputDir, showWarnings = FALSE)

## Download the input files from NCBI (better to download and make a subset for human and mice in bash)
# fileUrl <- "https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz"
# download(fileUrl, paste(inputDir, sourceName, "gene_history.gz", sep = "/"), mode = "wb")
# 
# fileUrl <- "https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz"
# download(fileUrl, paste(inputDir, sourceName, "gene_info.gz", sep = "/"), mode = "wb")

# Read the file that includes the withdrawn ids

##NCBI_WDN <- read.csv(paste(inputDir, sourceName, paste0("gene_history_human_mice_", sourceVersion), sep = "/"), sep = "\t") %>% 
