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

# Set variables
sourceName <- "hgnc"
sourceVersion <- "2023-07-01"
inputDir <- "mapping_preprocessing/datasources/"

# Create output directory
outputDir <- paste0("mapping_preprocessing/datasources/", sourceName, "/data")
dir.create(outputDir, showWarnings = FALSE)

# Download the input files from HGNC
if (!file.exists(paste(inputDir, sourceName, "/withdrawn_2023-07-01.txt", sep = "/"))) {
  fileUrl <- paste0("https://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/archive/quarterly/tsv/withdrawn_", sourceVersion, ".txt")
  download(fileUrl, paste(inputDir, sourceName, "/withdrawn_2023-07-01.txt", sep = "/"), mode = "wb")
}
if (!file.exists(paste(inputDir, sourceName, "/hgnc_complete_set_2023-07-01.txt", sep = "/"))) {
  fileUrl <- paste0("https://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/archive/quarterly/tsv/hgnc_complete_set_", sourceVersion, ".txt")
  download(fileUrl, paste(inputDir, sourceName, "/hgnc_complete_set_2023-07-01.txt", sep = "/"), mode = "wb")
}

# Read the file that includes the withdrawn ids
hgncWDN <- read.csv(paste(inputDir, sourceName, paste0("withdrawn_", sourceVersion, ".txt"), sep = "/"), sep = "\t") %>%
  dplyr::rename(
    HGNC_ID.SYMBOL.STATUS = MERGED_INTO_REPORT.S...i.e.HGNC_ID.SYMBOL.STATUS.,
    WITHDRAWN_HGNC_ID = HGNC_ID
  ) %>%
  dplyr::mutate(HGNC_ID.SYMBOL.STATUS = ifelse(HGNC_ID.SYMBOL.STATUS == "", STATUS, HGNC_ID.SYMBOL.STATUS)) %>%
  dplyr::select(WITHDRAWN_HGNC_ID, WITHDRAWN_SYMBOL, HGNC_ID.SYMBOL.STATUS)

# Since the data for HGNC is coming form to files, it would be more accurate to add the required information for SSSOM format while prepossessing the files
# Add the proper predicate:
## IAO:0100001 for IDs merged or 1:1 replacement to one and
## oboInOwl:consider for IDs split or deprecated

outputSec2priTsv <- hgncWDN %>%
  group_by(HGNC_ID.SYMBOL.STATUS) %>%
  mutate(
    primaryID_count = n(),
    primaryID_count = ifelse(HGNC_ID.SYMBOL.STATUS == "Entry Withdrawn", NA, primaryID_count)
  ) %>%
  group_by(WITHDRAWN_HGNC_ID) %>%
  ungroup() %>%
  mutate(
    predicateID = ifelse(grepl(", ", HGNC_ID.SYMBOL.STATUS), # the secondary ID that Split into multiple
      "oboInOwl:consider", ifelse(
        HGNC_ID.SYMBOL.STATUS == "Entry Withdrawn", # the secondary IDs Withdrawn
        "oboInOwl:consider", ifelse(
          primaryID_count == 1, # the secondary ID replace by new ID
          "IAO:0100001", ifelse(
            primaryID_count > 1, # multiple secondary IDs merged into one primary ID
            "IAO:0100001", NA
          )
        )
      )
    ),
    mapping_cardinality_sec2pri = ifelse(grepl(", ", HGNC_ID.SYMBOL.STATUS), # the IDs Splits
      "1:n", ifelse(
        HGNC_ID.SYMBOL.STATUS == "Entry Withdrawn",
        "1:0", ifelse(
          primaryID_count == 1, # the secondary ID replace by new ID
          "1:1", ifelse(
            primaryID_count > 1, # multiple secondary IDs merged into one primary ID
            "n:1", NA
          )
        )
      )
    ),
    comment = ifelse(grepl(", ", HGNC_ID.SYMBOL.STATUS), # the IDs Splits
      "ID (subject) is split into mutiple.", ifelse(
        HGNC_ID.SYMBOL.STATUS == "Entry Withdrawn",
        "ID (subject) withdrawn/deprecated.", ifelse(
          primaryID_count == 1, # the secondary ID replace by new ID
          "ID (subject) is replaced.", ifelse(
            primaryID_count > 1, # multiple secondary IDs merged into one primary ID
            "This ID (subject) and other ID(s) are merged into one ID.", NA
          )
        )
      )
    ),
    source = paste0("https://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/archive/quarterly/tsv/withdrawn_", sourceVersion, ".txt")
  )

# Add a row for each primary ID
s <- strsplit(hgncWDN$HGNC_ID.SYMBOL.STATUS, split = ", ") # Consider a separate row for each id in case an id was splited in multiple
hgncWDN <- data.frame(
  secondaryID = rep(hgncWDN$WITHDRAWN_HGNC_ID, sapply(s, length)),
  secondarySymbol = rep(hgncWDN$WITHDRAWN_SYMBOL, sapply(s, length)),
  HGNC_ID.SYMBOL.STATUS = unlist(s),
  predicateID = rep(hgncWDN$predicateID, sapply(s, length)),
  mapping_cardinality_sec2pri = rep(hgncWDN$mapping_cardinality_sec2pri, sapply(s, length)),
  comment = rep(hgncWDN$comment, sapply(s, length)),
  source = rep(hgncWDN$source, sapply(s, length))
)
length(grep("Approved|Entry Withdrawn", hgncWDN$HGNC_ID.SYMBOL.STATUS)) == nrow(hgncWDN) # Checking if all the new ids are approved

# Split HGNC_ID.SYMBOL.STATUS into 2 columns and add the status (Approved or Withdrawn) into comments
hgncWDN <- hgncWDN %>%
  mutate(
    primaryID = gsub("\\|.*", "", HGNC_ID.SYMBOL.STATUS),
    primarySymbol = gsub(".*\\|(.*?)\\|.*", "\\1", HGNC_ID.SYMBOL.STATUS),
    comment = ifelse(grepl("\\|Entry Withdrawn", HGNC_ID.SYMBOL.STATUS),
      paste0(comment, " Object is also withdrawn."), comment
    )
  ) %>%
  dplyr::select(primaryID, primarySymbol, secondaryID, secondarySymbol, predicateID, mapping_cardinality_sec2pri, comment, source)

# Write output TSV file for secondary to primary ID mapping
outputSec2priTsv <- file.path(outputDir, paste(sourceName, "_secID2priID", ".tsv", sep = ""))
write.table(hgncWDN, outputSec2priTsv, sep = "\t", row.names = FALSE, quote = FALSE)

# Read the file that includes the complete set
hgnc <- read.csv(paste(inputDir, sourceName, paste0("hgnc_complete_set_", sourceVersion, ".txt"), sep = "/"),
  sep = "\t", as.is = T
) %>%
  dplyr::select(hgnc_id, symbol, alias_symbol, prev_symbol) %>%
  dplyr::mutate(
    alias_symbol = ifelse(alias_symbol == "", NA, alias_symbol),
    prev_symbol = ifelse(prev_symbol == "", NA, prev_symbol)
  )

# Alias symbols
s <- strsplit(hgnc$alias_symbol, split = "\\|") # Consider a separate row for each id in case an id is splited in multiple (alias_symbol)
hgncAlias <- data.frame(
  primaryID = rep(hgnc$hgnc_id, sapply(s, length)),
  primarySymbol = rep(hgnc$symbol, sapply(s, length)),
  alias_symbol = unlist(s)
) %>%
  dplyr::rename(secondarySymbol = alias_symbol) %>%
  dplyr::mutate(
    comment = ifelse(is.na(secondarySymbol),
      "", "Alias symbol: Alternative symbols that have been used to refer to the gene. Aliases may be from literature, from other databases or may be added to represent membership of a gene group."
    ),
    predicateID = NA,
    mapping_cardinality_sec2pri = NA
  )

# Previous symbols (predicate: IAO:0100001 for previous symbols)
hgncPrev <- hgnc[, c("hgnc_id", "symbol", "prev_symbol")] %>%
  dplyr::mutate(
    comment = ifelse(is.na(prev_symbol),
      "", "Previous symbol: Any symbols that were previously HGNC-approved nomenclature."
    ),
    predicateID = ifelse(is.na(prev_symbol), NA, "IAO:0100001"),
    mapping_cardinality_sec2pri = NA
  ) %>%
  dplyr::rename(secondarySymbol = prev_symbol)
s <- strsplit(hgncPrev$secondarySymbol, split = "\\|") # consider a separate row for each id in case an id is splited in multiple (prev_symbol)
hgncPrev <- data.frame(
  primaryID = rep(hgncPrev$hgnc_id, sapply(s, length)),
  primarySymbol = rep(hgncPrev$symbol, sapply(s, length)),
  secondarySymbol = unlist(s, use.names = T),
  predicateID = rep(hgncPrev$predicateID, sapply(s, length)),
  mapping_cardinality_sec2pri = rep(hgncPrev$mapping_cardinality_sec2pri, sapply(s, length)),
  comment = rep(hgncPrev$comment, sapply(s, length))
)

hgnc <- rbind(hgncPrev, hgncAlias) %>%
  unique() %>%
  dplyr::mutate(source = paste0("https://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/archive/quarterly/tsv/hgnc_complete_set_", sourceVersion, ".txt")) %>%
  dplyr::select(primaryID, primarySymbol, secondarySymbol, predicateID, mapping_cardinality_sec2pri, comment, source)

# Check the symbols that are not present in hgnc file while they are in hgncWDN: all of those symbols are belong to HGNC IDs that were withdrawn and therefore not present in the complete set
hgncWDN[hgncWDN$primarySymbol %in% unique(hgncWDN$primarySymbol[!hgncWDN$primarySymbol %in% c(hgnc$primarySymbol, hgnc$secondarySymbol)])[-1], ]

# Remove the row with NA when the information is provided in another row
hgnc[hgnc$primarySymbol == "A2M", ]

hgncSec <- hgnc %>% filter(!is.na(secondarySymbol))
hgncSec[hgncSec$primarySymbol == "A2M", ]

hgncNoSec <- hgnc %>%
  filter(is.na(secondarySymbol)) %>%
  filter(!primaryID %in% hgncSec$primaryID)
hgncNoSec[hgncNoSec$primarySymbol == "A2M", ]

hgnc <- rbind(hgncSec, hgncNoSec)
hgnc[hgnc$primarySymbol == "A2M", ]

# Write output TSV files
outputPriTsv <- file.path(outputDir, paste(sourceName, "_priIDs", ".tsv", sep = ""))
write.table(hgnc %>% dplyr::select(primaryID, primarySymbol) %>% unique(), outputPriTsv, sep = "\t", row.names = FALSE, quote = FALSE)

outputNameTsv <- file.path(outputDir, paste(sourceName, "_symbol2alia&prev", ".tsv", sep = ""))
write.table(hgnc, outputNameTsv, sep = "\t", row.names = FALSE, quote = FALSE)
