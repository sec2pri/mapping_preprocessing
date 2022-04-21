Prepare input files for creating derby databases
----------
The input file should containes two columns (`#did` = secondary identifier, `nextofkin` = primary identifier that replaces the identifier).

### some examples of input preparation

#### Download the ``uniport`` file containing the secondary and primary identifiers
```script
https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/docs/sec_ac.txt #Secondary ids together with their corresponding current primary ids
# https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_sp.txt #Ids deleted from Swiss-Prot
# https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_tr.txt.gz #Ids deleted from TrEMBL
```
#### Perepare the input data (R script)
```{r}
# required libraries
library (dplyr)
library (tidyr)
uniport <- read.csv ("Dir to the database file/sec_ac.txt", sep = ",", skip = 31, header = F) %>%
  tidyr::separate (V1, c ('#did', 'nextofkin')) %>%
  mutate (`#did` = gsub (" ", "", `#did`),
          nextofkin = gsub (" ", "", nextofkin)) %>% 
  select (`#did`, nextofkin) 
uniport_sp <- read.csv ("Dir to the database file/delac_sp.txt", sep = ",", skip = 27, header = F) %>%
  rename (`#did`= V1) %>%
  mutate (`#did` = gsub (" ", "", `#did`),
          nextofkin = "ENT_WDN") 
uniport_tr <- read.csv ("Dir to the database file/delac_tr.gz", sep = ",", skip = 27, header = F) %>%
  rename (`#did`= V1) %>%
  mutate (`#did` = gsub (" ", "", `#did`),
          nextofkin = "ENT_WDN") 
rbind (uniport,uniport_sp, uniport_tr) %>% write.csv ("input/uniport.csv", row.names = F)
```

#### Download the ``HGNC`` file containing the secondary and primary identifiers
```script
http://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/tsv/withdrawn.txt
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
