# Clear environment and load necessary libraries
rm(list = ls())
if (!"xml2" %in% installed.packages()) {
  install.packages("xml2")
}
library(xml2)

# Set variables
sourceName <- "HMDB"
inputDir <- "datasources/"

# Create output directory
outputDir <- paste0("datasources/", tolower(sourceName), "/recentData")
dir.create(outputDir, showWarnings = FALSE)

# Create list to save the mapping data

# Primary ID
listOfpri <- list()
# Secondary to primary ID
listOfsec2pri <- list()
# Name to synonyms
listOfname2synonym <- list()

counter <- 0
counter2 <- 0

# read HMDB XML files
folderPath <- paste0(inputDir, sourceName, "/hmdb_metabolites_split/hmdb/")
entries <- list.files(folderPath)

# Iterate through the folder
for (entry in entries) {
  if (entry != "hmdb_metabolites.xml") {
    document <- read_xml(paste0(folderPath, entry))

    # Extract primary ID
    priIdNode <- "accession"
    priIdList <- xml_find_all(document, priIdNode)
    priId <- xml_text(priIdList)
    listOfpri <- c(listOfpri, priId)

    # Extract secondary IDs
    secIdNode <- "secondary_accessions"
    secIdList <- xml_find_all(document, secIdNode)
    secIdValues <- unlist(lapply(xml_children(secIdList), function(node) xml_text(node)))

    if (is.null(secIdValues)) {
      listOfsec2pri <- c(listOfsec2pri, list(c(priId, NA)))
    } else if (length(secIdValues) == 1) {
      listOfsec2pri <- c(listOfsec2pri, list(c(priId, secIdValues)))
    } else if (length(secIdValues) > 1) {
      for (secID in secIdValues) {
        listOfsec2pri <- c(listOfsec2pri, list(c(priId, secID)))
      }
    }

    # Extract metabolite name
    priNameNode <- "name"
    priNameList <- xml_find_all(document, priNameNode)
    priName <- xml_text(priNameList)

    # Extract synonyms
    secSynonymNode <- "synonyms"
    secSynonymList <- xml_find_all(document, secSynonymNode)
    secSynonymValues <- unlist(lapply(xml_children(secSynonymList), function(node) xml_text(node)))

    if (is.null(secSynonymValues)) {
      listOfname2synonym <- c(listOfname2synonym, list(c(priId, priName, NA)))
    } else if (length(secSynonymValues) == 1) {
      listOfname2synonym <- c(listOfname2synonym, list(c(priId, priName, secSynonymValues)))
    } else if (length(secSynonymValues) > 1) {
      for (syn in secSynonymValues) {
        listOfname2synonym <- c(listOfname2synonym, list(c(priId, priName, syn)))
      }
    }

    # Progress update at every 5000th iteration
    counter <- counter + 1
    if (counter == 5000) {
      counter2 <- counter2 + 1
      cat(paste("5k mark ", counter2, ": ", priId), "\n")
      counter <- 0
    }
  }
}


# Write output TSV files
outputPriTsv <- file.path(outputDir, paste(sourceName, "_priIDs", ".tsv", sep = ""))
write.table(do.call(rbind, listOfpri), outputPriTsv, sep = "\t", row.names = FALSE)

outputSec2priTsv <- file.path(outputDir, paste(sourceName, "_secID2priID", ".tsv", sep = ""))
write.table(do.call(listOfsec2pri), outputSec2priTsv, sep = "\t", row.names = FALSE)

outputNameTsv <- file.path(outputDir, paste(sourceName, "_name2synonym", ".tsv", sep = ""))
write.table(do.call(listOfname2synonym), outputNameTsv, sep = "\t", row.names = FALSE)
