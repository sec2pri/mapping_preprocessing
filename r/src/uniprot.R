# Clear environment and load necessary libraries
rm(list = ls())
if (!"downloader" %in% installed.packages()) {
  install.packages("downloader")
}
require(downloader)
if (!"dplyr" %in% installed.packages()) {
  install.packages("dplyr")
}
library(dplyr)
if (!"stringr" %in% installed.packages()) {
  install.packages("stringr")
}
library(stringr)
if (!"readr" %in% installed.packages()) {
  install.packages("readr")
}
library(readr)
if(!"data.table" %in% installed.packages()) {
  install.packages("data.table")
}
library(data.table)
if(!"R.utils" %in% installed.packages()) {
  install.packages("R.utils")
}

# Retrieve command-line arguments
args <- commandArgs(trailingOnly = TRUE)

# Set variables
sourceName = "uniprot"
sourceVersion = args[1]
uniprot_sprot = args[2]
delac_sp = args[3] 
sec_ac = args[4]
inputDir <- "datasources"

# Create output directory
outputDir <- paste0("datasources/", sourceName, "/recentData")
dir.create(outputDir, showWarnings = FALSE)

# Download the input files from UniProt
# if (!file.exists(paste(inputDir, sourceName, "uniprot_sprot_release-2023_03.fasta.gz", sep = "/"))) {
#   # uniprot_sprot.fasta.gz includes complete UniProtKB/Swiss-Prot data set in FASTA format
#   fileUrl <- "https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz"
#   download(fileUrl, paste(inputDir, sourceName, "/uniprot_sprot_release-2023_03.fasta.gz", sep = "/"), mode = "wb")
# }
# if (!file.exists(paste(inputDir, sourceName, "delac_sp_release-2023_03.txt", sep = "/"))) {
#   # Accession numbers deleted from Swiss-Prot are listed in the document file delac_sp.txt
#   fileUrl <- "https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_sp.txt"
#   download(fileUrl, paste(inputDir, sourceName, "/delac_sp_release-2023_03.txt", sep = "/"), mode = "wb")
# }
# if (!file.exists(paste(inputDir, sourceName, "sec_ac_release-2023_03.txt", sep = "/"))) {
#   # This file lists all secondary accession numbers in UniProtKB (Swiss-Prot and TrEMBL), together with their corresponding current primary accession number(s).
#   fileUrl <- "https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/sec_ac.txt"
#   download(fileUrl, paste(inputDir, sourceName, "/sec_ac_release-2023_03.txt", sep = "/"), mode = "wb")
# }

# Read the fasta file
# fastaFile <- paste(inputDir, sourceName, "uniprot_sprot_release-2023_03.fasta.gz", sep = "/")
fastaData <- readLines(uniprot_sprot)

# Extract the IDs using regular expressions
pattern <- "^>.*?\\|(.*?)\\|" # Updated pattern to match IDs at the start of lines
listOfpri <- str_extract(fastaData, pattern)
listOfpri <- str_remove_all(listOfpri, "^>.*?\\||\\|$") # Remove the '>' symbol and '|' characters from the extracted IDs
listOfpri <- listOfpri[!is.na(listOfpri)] # Filter out NAs

# Write output a TSV file for primary IDs
outputPriTsv <- file.path(outputDir, paste(sourceName, "_priIDs", ".tsv", sep = ""))
write.table(data.frame(primaryID = listOfpri), outputPriTsv, sep = "\t", row.names = FALSE, quote = FALSE)

# Read the secondary to primary IDs
uniportSec <- readr::read_table(sec_ac, skip = 31, col_names = c("secondaryID", "primaryID")
) %>%
  dplyr::mutate(
    secondaryID = gsub(" ", "", secondaryID),
    primaryID = gsub(" ", "", primaryID)
  ) %>%
  dplyr::select(secondaryID, primaryID)

uniportSec <- uniportSec %>%
  group_by(primaryID) %>%
  mutate(primaryID_count = n()) %>%
  group_by(secondaryID) %>%
  mutate(secondaryID_count = n()) %>%
  ungroup() %>%
  mutate(
    mapping_cardinality_sec2pri = ifelse((primaryID_count > 1 & secondaryID_count == 1), # IDs merged, multiple sec to one pri
      "n:1", ifelse(
        primaryID_count == 1 & secondaryID_count == 1, # the secondary ID replace by new ID
        "1:1", ifelse(
          primaryID_count == 1 & secondaryID_count > 1, # IDs splited, one sec to multiple pri
          "1:n", ifelse(
            primaryID_count > 1 & secondaryID_count > 1, # multiple secondary IDs merged into multiple primary IDs
            "n:n", NA
          )
        )
      )
    ),
    predicateID = ifelse(mapping_cardinality_sec2pri %in% c("1:n", "n:n"), # the secondary ID that Split into multiple OR multiple secondary IDs merged/splited into multiple primary IDs
      "oboInOwl:consider", ifelse(
        mapping_cardinality_sec2pri %in% c("1:1", "n:1"), # the secondary ID replace by new ID OR multiple secondary IDs merged into one primary ID
        "IAO:0100001", NA
      )
    ),
    comment = ifelse(mapping_cardinality_sec2pri == "1:n", # the IDs Splits
      paste0("ID (subject) is split into mutiple. Release: ", sourceVersion, "."), ifelse(
        mapping_cardinality_sec2pri == "1:1", # the secondary ID replace by new ID
        paste0("ID (subject) is replaced. Release: ", sourceVersion, "."), ifelse(
          mapping_cardinality_sec2pri == "n:n",
          paste0("This ID (subject) and other ID(s) are merged/splited into multiple ID(Object). Release: ", sourceVersion, "."), ifelse(
            mapping_cardinality_sec2pri == "n:1", # multiple secondary IDs merged into one primary ID
            paste0("This ID (subject) and other ID(s) are merged into one ID. Release: ", sourceVersion, "."), NA
          )
        )
      )
    ),
    source = "https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/sec_ac.txt"
  ) %>%
  dplyr::select(primaryID, secondaryID, predicateID, mapping_cardinality_sec2pri, comment, source)


# Read the deleted IDs
uniportSpDel <- readr::read_table(delac_sp, skip = 27, col_names = "secondaryID"
) %>%
  dplyr::mutate(
    secondaryID = gsub(" ", "", secondaryID),
    primaryID = "Entry Withdrawn",
    mapping_cardinality_sec2pri = "1:0",
    predicateID = "oboInOwl:consider",
    comment = paste0("ID (subject) withdrawn/deprecated. Release: ", sourceVersion, "."),
    source = "https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_sp.txt"
  ) %>%
  dplyr::select(primaryID, secondaryID, predicateID, mapping_cardinality_sec2pri, comment, source)

uniportSpDel <- uniportSpDel[1:(nrow(uniportSpDel) - 4), ] # Drop the last four rows

# Write output TSV file for secondary to primary ID mapping
outputSec2priTsv <- file.path(outputDir, paste(sourceName, "_secID2priID", ".tsv", sep = ""))
write.table(rbind(uniportSec, uniportSpDel), outputSec2priTsv, sep = "\t", row.names = FALSE, quote = FALSE)
