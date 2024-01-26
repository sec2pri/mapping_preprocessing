# Clear environment and load necessary libraries
rm(list = ls())
if(!"downloader" %in% installed.packages()) {
   install.packages("downloader")
}
library(downloader)
if(!"dplyr" %in% installed.packages()) {
   install.packages("dplyr")
}
library(dplyr)

# Retrieve command-line arguments
args <- commandArgs(trailingOnly = TRUE)

# Set variables
sourceName = "ncbi"
sourceVersion = args[1]
gene_history = args[2]
gene_info = args[3]
inputDir = "mapping_preprocessing/datasources"

# Create output directory
outputDir <- paste0("mapping_preprocessing/datasources/", sourceName, "/data")
dir.create(outputDir, showWarnings = FALSE)

## Download the input files from NCBI (better to download and make a subset for human and mice in bash)
# fileUrl <- "https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz"
# download(fileUrl, paste(inputDir, sourceName, "gene_history.gz", sep = "/"), mode = "wb")
# 
# fileUrl <- "https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz"
# download(fileUrl, paste(inputDir, sourceName, "gene_info.gz", sep = "/"), mode = "wb")

# Read the file that includes the withdrawn ids
ncbiWDN <- data.table::fread(paste(inputDir, sourceName, gene_history, sep = "/"), sep = "\t") %>% 
  dplyr::filter(`#tax_id` == 9606) %>% #focusing on human
  dplyr::rename(primaryID = GeneID,
                secondaryID	= Discontinued_GeneID,
                secondarySymbol = Discontinued_Symbol,
                comment = Discontinue_Date) %>%
  dplyr::mutate(primaryID = ifelse (primaryID == "-", "Entry Withdrawn", primaryID),
                comment = paste0("Withdrawn date: ", comment, ". ")) %>%
  dplyr::select(primaryID, secondaryID, secondarySymbol, comment)

# Since the data for NCBI is coming form two files, it would be more accurate to add the required information for SSSOM format while prepossessing the files
# Add the proper predicate: 
## IAO:0100001 for IDs merged or 1:1 replacement to one and 
## oboInOwl:consider for IDs split or deprecated/withdrawn
ncbiWDN <- ncbiWDN %>% 
  dplyr::group_by(primaryID) %>%
  dplyr::mutate(primaryID_count = n(),
         primaryID_count = ifelse(primaryID == "Entry Withdrawn", NA, primaryID_count)) %>%
  dplyr::ungroup() %>%
  dplyr::group_by(secondaryID) %>% #each secondary ID used only once
  dplyr::mutate(secondaryID_count = n()) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(mapping_cardinality_sec2pri = ifelse(primaryID == "Entry Withdrawn", "1:0", #the secondary ID is Withdrawn,
                                                     ifelse(primaryID_count > 1 & secondaryID_count == 1, "n:1", #IDs merged, multiple sec to one pri
                                                            ifelse(primaryID_count == 1 & secondaryID_count == 1, "1:1", #the secondary ID replace by new ID
                                                                   ifelse(primaryID_count == 1 & secondaryID_count > 1, "1:n", #IDs splited, one sec to multiple pri
                                                                          ifelse(primaryID_count > 1 & secondaryID_count > 1, "n:n", #multiple secondary IDs merged into multiple primary IDs
                                                                                 NA))))),
                predicateID = ifelse(mapping_cardinality_sec2pri %in% c("1:0", "1:n", "n:n"), #the secondary ID that Split into multiple OR multiple secondary IDs merged/splited into multiple primary IDs or withdrawn
                                     "oboInOwl:consider", ifelse(
                                       mapping_cardinality_sec2pri %in% c("1:1", "n:1"), #the secondary ID replace by new ID OR multiple secondary IDs merged into one primary ID
                                       "IAO:0100001", NA
                                     )),
                comment = paste0(comment, ifelse(mapping_cardinality_sec2pri == "1:n", "ID (subject) is split into mutiple.", #the IDs Splits
                                                 ifelse(mapping_cardinality_sec2pri == "1:1", "ID (subject) is replaced.",  #the secondary ID replace by new ID
                                                        ifelse(mapping_cardinality_sec2pri == "n:n", "This ID (subject) and other ID(s) are merged/splited into multiple ID(Object).", 
                                                               ifelse(mapping_cardinality_sec2pri == "n:1", "This ID (subject) and other ID(s) are merged into one ID.", #multiple secondary IDs merged into one primary ID
                                                                      ifelse(mapping_cardinality_sec2pri == "1:0", "ID (subject) withdrawn/deprecated.", NA)))))),
                source = "https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz") %>%
  dplyr::select(primaryID, secondaryID, secondarySymbol, predicateID, mapping_cardinality_sec2pri, comment, source)
                
# Check if the primaryID is withdrawn
ncbiWDN <- ncbiWDN %>% 
  dplyr::mutate(comment = paste0(ifelse(primaryID %in% secondaryID, paste0(comment, " Object is also withdrawn."), comment),
                                 " Release: ", sourceVersion, "."))

# Read the file that includes the gene info
ncbi <- data.table::fread(paste(inputDir, sourceName, gene_info, sep = "/"), sep = "\t") %>%
  dplyr::filter(`#tax_id` == 9606) %>% #focusing on human
  dplyr::mutate(Symbol_from_nomenclature_authority = ifelse(Symbol_from_nomenclature_authority == Symbol, "-", Symbol_from_nomenclature_authority),
                Symbol = ifelse(Symbol_from_nomenclature_authority == "-", Symbol, paste0(Symbol, "|", Symbol_from_nomenclature_authority))) %>%
  dplyr::rename(primaryID = GeneID, primarySymbol = Symbol, secondarySymbol = Synonyms)

# Genes with different symbols in HGNC
nomenclature_symbol <- setdiff(unique(ncbi$Symbol_from_nomenclature_authority), "-")

ncbi <- ncbi %>%
  dplyr::select(primaryID, primarySymbol, secondarySymbol)
  
# Add primary symbol based on the gene info to ncbiWDN
ncbiWDN <- ncbiWDN %>%
  mutate(primarySymbol = ifelse(primaryID %in% ncbi$primaryID, ncbi$primarySymbol[match(ncbi$primaryID, primaryID)],
                                ifelse(primaryID %in% secondaryID, secondarySymbol, 
                                       ifelse(primaryID == "Entry Withdrawn", "Entry Withdrawn",
                                              NA)))) %>%
  dplyr::select(primaryID, primarySymbol, secondaryID, secondarySymbol, predicateID, mapping_cardinality_sec2pri, comment, source)

# Write output TSV file for secondary to primary ID mapping
outputSec2priTsv <- file.path(outputDir, paste(sourceName, "_secID2priID", ".tsv", sep = ""))
write.table(ncbiWDN, outputSec2priTsv, sep = "\t", row.names = FALSE, quote = FALSE)

# Add a row for each secondary symbol
s <- strsplit (ncbi$secondarySymbol, split = "\\|") # Consider a separate row for each secondary symbol in case there are multiple secondary symbol
ncbi <- data.frame(primaryID = rep (ncbi$primaryID, sapply (s, length)),
                   primarySymbol = rep (ncbi$primarySymbol, sapply (s, length)),
                   secondarySymbol = unlist(s)) %>% 
  dplyr::mutate(secondarySymbol = ifelse(secondarySymbol == "-", NA, secondarySymbol),
                comment = paste0(ifelse(is.na(secondarySymbol), "", 
                                 ifelse(secondarySymbol %in% nomenclature_symbol, "The secondary symbol is the nomenclature symbol",
                                        "Unofficial symbol for the gene")), " Release: ", sourceVersion, "."),
                predicateID = NA,
                mapping_cardinality_sec2pri = NA,
                source = "https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz")


# Write output TSV files
outputPriTsv <- file.path(outputDir, paste(sourceName, "_priIDs", ".tsv", sep = ""))
write.table(ncbi %>% dplyr::select(primaryID, primarySymbol) %>% unique(), outputPriTsv, sep = "\t", row.names = FALSE, quote = FALSE)

outputNameTsv <- file.path(outputDir, paste(sourceName, "_symbol2alia&prev", ".tsv", sep = ""))
write.table(ncbi %>% unique(), outputNameTsv, sep = "\t", row.names = FALSE, quote = FALSE)
