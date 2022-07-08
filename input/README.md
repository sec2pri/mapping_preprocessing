Prepare input files for creating derby databases
----------
The input file can be in 2 different formats: (1) a text file with two columns (2) a zip file containing XML files

## Text file
The text file should containes two columns (`#did` = secondary identifier, `nextofkin` = primary identifier that replaces the identifier).

ENT_WDN stands for Entry withdrawn (deleted ids)  
### some examples of input preparation

#### uniport, perepare the input data (R script)
```{r}
#Download the ``uniport`` file containing the secondary and primary identifiers
require(downloader)
#Ids deleted from Swiss-Prot
fileUrl <- "https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_sp.txt"
download(fileUrl, "input/uniport_spDeleted2022041.txt", mode = "wb")
#ds deleted from TrEMBL
fileUrl <- "https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_tr.txt.gz"
download(fileUrl, "input/uniport_trDeleted2022041.gz", mode = "wb")
#Secondary ids together with their corresponding current primary ids
fileUrl <- "https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/docs/sec_ac.txt"
download(fileUrl, "input/uniportWithdrawn2022041.txt", mode = "wb")

# required libraries
library (dplyr)
library (tidyr)
uniport <- read.csv ("Dir to the database file/sec_ac.txt", sep = ",", skip = 31, header = F) %>%  # read only the table which starts on line 32 
  tidyr::separate (V1, c ('#did', 'nextofkin')) %>%
  mutate (`#did` = gsub (" ", "", `#did`),
          nextofkin = gsub (" ", "", nextofkin)) %>% 
  select (`#did`, nextofkin) 
uniport_sp <- read.csv ("Dir to the database file/delac_sp.txt", sep = ",", skip = 27, header = F) %>%  # read only the table which starts on line 28 
  rename (`#did`= V1) %>%
  mutate (`#did` = gsub (" ", "", `#did`),
          nextofkin = "ENT_WDN") 
uniport_tr <- read.csv ("Dir to the database file/delac_tr.gz", sep = ",", skip = 27, header = F) %>%  # read only the table which starts on line 28 
  rename (`#did`= V1) %>%
  mutate (`#did` = gsub (" ", "", `#did`),
          nextofkin = "ENT_WDN") 
rbind (uniport,uniport_sp, uniport_tr) %>% write.csv ("input/uniport.csv", row.names = F)
```

#### HGNC, perepare the input data (R script)
```{r}
#Download the ``HGNC`` file containing the secondary and primary identifiers
require(downloader)
#Secondary ids together with their corresponding current primary ids
fileUrl <- "http://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/tsv/withdrawn.txt"
download(fileUrl, "input/hgncWithdrawn20220414.txt", mode = "wb")
#Complete set including the previous names
fileUrl <- "http://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/tsv/hgnc_complete_set.txt"
download(fileUrl, "input/hgncCompleteSet20220509.txt", mode = "wb")

# required libraries
library (dplyr)
library (tidyr)
#File that includes the withdrawn ids
hgnc_WDN <- read.csv ("input/hgncWithdrawn20220414.txt", sep = "\t") %>%
  rename (HGNC_ID.SYMBOL.STATUS = MERGED_INTO_REPORT.S...i.e.HGNC_ID.SYMBOL.STATUS.) %>%
  mutate (HGNC_ID.SYMBOL.STATUS = ifelse (HGNC_ID.SYMBOL.STATUS == "", STATUS, HGNC_ID.SYMBOL.STATUS)) %>%
  select (HGNC_ID, WITHDRAWN_SYMBOL, HGNC_ID.SYMBOL.STATUS)
s <- strsplit (hgnc_WDN$HGNC_ID.SYMBOL.STATUS, split = ",") #Considering a separate row for each id in case an id is splited in multiple
hgnc_WDN <- data.frame (HGNC_ID = rep (hgnc_WDN$HGNC_ID, sapply (s, length)),
                        WITHDRAWN_SYMBOL = rep (hgnc_WDN$WITHDRAWN_SYMBOL, sapply (s, length)),
                        HGNC_ID.SYMBOL.STATUS = unlist (s))
length (grep ("Approved|Entry Withdrawn", hgnc_WDN$HGNC_ID.SYMBOL.STATUS)) == nrow (hgnc_WDN) #Checking if all the new ids are approved

hgnc_WDN <- hgnc_WDN %>%
  mutate (secID = gsub ("\\|.*", "", HGNC_ID),
          secSymbol = WITHDRAWN_SYMBOL,
          hgnc_id = ifelse (HGNC_ID.SYMBOL.STATUS == "Entry Withdrawn", "ENT_WDN", gsub ("\\|.*", "", HGNC_ID.SYMBOL.STATUS)),
          symbol = ifelse (HGNC_ID.SYMBOL.STATUS == "Entry Withdrawn", "ENT_WDN", gsub (".*\\|", "", gsub ("\\|App.*", "", HGNC_ID.SYMBOL.STATUS)))) %>%
  select (hgnc_id, symbol, secSymbol, secID)

#File that includes the complete set
hgnc <- read.csv ("input/hgncCompleteSet20220509.txt",
                  sep = "\t", as.is = T) %>%
  select (hgnc_id, symbol, alias_symbol, prev_symbol) %>% 
  mutate (alias_symbol = ifelse (alias_symbol == "", NA, alias_symbol),
          prev_symbol = ifelse (prev_symbol == "", NA, prev_symbol))

s <- strsplit (hgnc$alias_symbol, split = "\\|") #Considering a separate row for each id in case an id is splited in multiple (alias_symbol)
hgnc <- data.frame (hgnc_id = rep (hgnc$hgnc_id, sapply (s, length)),
                    symbol = rep (hgnc$symbol, sapply (s, length)),
                    prev_symbol = rep (hgnc$prev_symbol, sapply (s, length)),
                    alias_symbol = unlist (s))
s <- strsplit (hgnc$prev_symbol, split = "\\|") #considering a separate row for each id in case an id is splited in multiple (prev_symbol)
hgnc <- data.frame (hgnc_id = rep (hgnc$hgnc_id, sapply (s, length)),
                    symbol = rep (hgnc$symbol, sapply (s, length)),
                    alias_symbol = rep (hgnc$alias_symbol, sapply (s, length)),
                    prev_symbol = unlist (s, use.names = T))

hgnc <- rbind (hgnc [, c ("hgnc_id", "symbol", "alias_symbol")] %>%
                 rename (secSymbol = alias_symbol),
               hgnc [, c ("hgnc_id", "symbol", "prev_symbol")] %>%
                 rename (secSymbol = prev_symbol)) %>% unique () # %>%
  # mutate (secID = "")

#Fixing the row with NA
hgnc[hgnc$symbol == "A2M",]
hgnc_Sec <- hgnc %>% filter (!is.na (secSymbol))
hgnc_noSec <- hgnc %>% filter (is.na (secSymbol)) %>%
  filter (!hgnc_id %in% hgnc_Sec$hgnc_id)
hgnc <- rbind (hgnc_Sec, hgnc_noSec)
hgnc[hgnc$symbol == "A2M",]

#Merging the two datasets
hgnc_all <- merge (hgnc_WDN, hgnc, all = T, sort = F) %>% arrange (hgnc_id) %>%
  select (hgnc_id, secID, symbol, secSymbol) 

hgnc_all[hgnc_all$symbol == "A2M",]
hgnc_all$secSymbol[hgnc_all$secID == "HGNC:7625"] = "NA"

merge (hgnc_all  %>%
         filter (hgnc_id == "ENT_WDN") %>%
         mutate (hgnc_id = make.names (hgnc_id, unique = TRUE)),
       hgnc_all %>%
  filter (hgnc_id != "ENT_WDN") %>%
  mutate (hgnc_id = gsub (" ", "", hgnc_id)) %>%
  group_by (hgnc_id) %>%
  summarise (secID = paste0 (unique (na.omit (gsub (" ", "", secID))), collapse = "; "),
             symbol = paste0 (unique (na.omit (gsub (" ", "", symbol))), collapse = "; "),
             secSymbol = paste0 (unique (na.omit (gsub (" ", "", secSymbol))), collapse = "; ")) %>%
  ungroup (), all = T) %>% write.csv ("input/hgnc_all.csv", row.names = F)
```

## Zip file
Each entry would be a XML file in the zip file.
The zip file for HMDB can be generated as explained [here](https://github.com/bridgedb/create-bridgedb-metabolites#:~:text=make%20sure%20the%20HMDB%20data%20file%20is%20saved%20as%20hmdb_metabolites.zip%20and%20to%20create%20a%20new%20zip%20file%20will%20each%20metabolite%20in%20separate%20XML%20file%3A). The copy of the commands from `create-bridgedb-metabolites` repo is shown below: 

```script
mkdir hmdb
wget http://www.hmdb.ca/system/downloads/current/hmdb_metabolites.zip
unzip hmdb_metabolites.zip
cd hmdb
cp ../hmdb_metabolites.xml .
xml_split -v -l 1 hmdb_metabolites.xml
rm hmdb_metabolites.xml
cd ..
zip -r hmdb_metabolites_split.zip hmdb
```
 
