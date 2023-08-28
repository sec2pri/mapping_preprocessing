# Clear environment and load necessary libraries
rm(list = ls())
library(readr)

# Set variables
sourceName <- "ChEBI"
inputDir <- "mapping_preprocessing/datasources/ChEBI/"

# Create output directory
outputDir <- "mapping_preprocessing/datasources/ChEBI/data"
dir.create(outputDir, showWarnings = FALSE)

# Create output tsv mapping files

# Primary ID
column_names <- c("primaryID", "secondaryID")
listOfpri <- data.frame(matrix(ncol = 1, nrow = 0)) # dataset of primary IDs
colnames(listOfpri) <- column_names[1]

# Secondary to primary ID
listOfsec2pri <- data.frame(matrix(ncol = 2, nrow = 0))  # dataset of the secondary to primary IDs
colnames(listOfsec2pri) <- column_names

# Name to synonyms
column_names <- c("primaryID", "name", "synonym")
listOfname2synonym <- data.frame(matrix(ncol = 3, nrow = 0))  # dataset of the name to synonym
colnames(listOfname2synonym) <- column_names

counter <- 0
counter2 <- 0

# read ChEBI SDF file
file <- read_lines(paste(inputDir, sourceName, "/ChEBI_complete_3star.sdf", sep = "/"))

# Iterate through the file
for (i in seq_along(file)) {
  dataRow <- file[i]
  
  # Extract primary ID
  if (grepl("^> <ChEBI ID>", dataRow)) {
    counter <- counter + 1
    dataRow <- file[i + 1]
    priId <- dataRow
    listOfpri <- rbind(listOfpri, priId)
  }
  
  # Extract metabolite name
  if (grepl("^> <ChEBI Name>", dataRow)) {
    dataRow <- file[i + 1]
    name <- dataRow
  }
  
  # Extract secondary IDs
  if (grepl("^> <Secondary ChEBI ID>", dataRow)) {
    dataRow <- file[i + 1]
    secId <- dataRow
    listOfsec2pri <- rbind(listOfsec2pri, c(priId,  secId))
    dataRow <- file[i + 2]
    while (grepl("^CHEBI:", dataRow)) {
      secId <- dataRow
      listOfsec2pri <- rbind(listOfsec2pri, c(priId,  secId))
      dataRow <- file[i + 1]
      i <- i + 1
    }
  }
  
  # Extract synonyms
  if (grepl("^> <Synonyms>", dataRow)) {
    dataRow <- file[i + 1]
    syn <- dataRow
    
    if (is.null(dataRow) && dataRow == "") {
      listOfname2synonym <- rbind(listOfname2synonym, c (priId, name, NA))
    } else {
      listOfname2synonym <- rbind(listOfname2synonym, c (priId, name, syn))
    }
    
    dataRow <- file[i + 2]
    while (!is.null(dataRow) && dataRow != "") {
      syn <- dataRow
      listOfname2synonym <- rbind(listOfname2synonym, c (priId, name, syn))
      dataRow <- file[i + 1]
      i <- i + 1
    }
  }
  
  # Progress update at every 5000th iteration
  if (counter == 5000) {
    counter2 <- counter2 + 1
    cat(paste("5k mark ", counter2, ": ", priId), "\n")
    counter <- 0
  }
}

# Write output TSV files
output_pri_Tsv <- file.path(outputDir, paste(sourceName, "_priIDs", ".tsv", sep = ""))
write.table(listOfpri, output_pri_Tsv, sep = "\t", row.names = FALSE)

output_sec2pri_Tsv <- file.path(outputDir, paste(sourceName, "_secID2priID", ".tsv", sep = ""))
write.table(listOfsec2pri, output_sec2pri_Tsv, sep = "\t", row.names = FALSE)

output_name_Tsv <- file.path(outputDir, paste(sourceName, "_name2synonym", ".tsv", sep = ""))
write.table(listOfname2synonym, output_name_Tsv, sep = "\t", row.names = FALSE)

