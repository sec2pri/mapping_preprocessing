Prepare input files for creating derby databases
----------
The input file can be in 2 different formats: (1) a text file with two columns (2) a zip file containing XML files

## Text file
The text file should containes two columns (`#did` = secondary identifier, `nextofkin` = primary identifier that replaces the identifier).

ENT_WDN stands for Entry withdrawn (deleted ids)  
### some examples of input preparation

#### Download the ``uniport`` file containing the secondary and primary identifiers
```script
https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/docs/sec_ac.txt # Secondary ids together with their corresponding current primary ids
https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_sp.txt # Ids deleted from Swiss-Prot
https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_tr.txt.gz # Ids deleted from TrEMBL
```
#### Perepare the input data (R script)
```{r}
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

#### Download the ``HGNC`` file containing the secondary and primary identifiers
```script
http://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/tsv/withdrawn.txt # Secondary ids together with their corresponding current primary ids
```
#### Perepare the input data (R script)
```{r}
# required libraries
library (dplyr)
library (tidyr)

hgnc <- read.csv ("Dir to the database file/hgncWithdrawn20220414.txt", sep = "\t") %>%
  rename (HGNC_ID.SYMBOL.STATUS = MERGED_INTO_REPORT.S...i.e.HGNC_ID.SYMBOL.STATUS.) %>%
  mutate (HGNC_ID.SYMBOL.STATUS = ifelse (HGNC_ID.SYMBOL.STATUS == "", STATUS, HGNC_ID.SYMBOL.STATUS))
s <- strsplit (hgnc$HGNC_ID.SYMBOL.STATUS, split = ",") #considering a separate row for each id in case an id is splited in multiple
hgnc <- data.frame (HGNC_ID = rep (hgnc$HGNC_ID, sapply (s, length)),
                    STATUS = rep (hgnc$STATUS, sapply (s, length)),
                    WITHDRAWN_SYMBOL = rep (hgnc$WITHDRAWN_SYMBOL, sapply (s, length)),
                    HGNC_ID.SYMBOL.STATUS = unlist (s))
## Table of HGNC ids 
hgnc_ID <- hgnc %>% 
  mutate (HGNC_ID = gsub (".*:", "", HGNC_ID),
          HGNC_ID.SYMBOL.STATUS = gsub (".*:|\\|.*", "", HGNC_ID.SYMBOL.STATUS)) %>% 
    select (HGNC_ID, HGNC_ID.SYMBOL.STATUS) %>% 
    rename (`#did`= HGNC_ID, nextofkin = HGNC_ID.SYMBOL.STATUS) 
hgnc_ID %>% write.csv ("input/hgncID.csv", row.names = F)
## Table of gene symbols 
hgnc_SYMBOL <- hgnc %>% 
  mutate (HGNC_ID.SYMBOL.STATUS = gsub (".*\\|", "", gsub ("\\|App.*", "", HGNC_ID.SYMBOL.STATUS))) %>% 
  select (WITHDRAWN_SYMBOL, HGNC_ID.SYMBOL.STATUS) %>% 
  rename (`#did`= WITHDRAWN_SYMBOL, nextofkin = HGNC_ID.SYMBOL.STATUS) 
hgnc_SYMBOL %>% write.csv ("input/hgncSymbol.csv", row.names = F)
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
 
