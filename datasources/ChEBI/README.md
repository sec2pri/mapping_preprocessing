# ChEBI Metabolites SDF Processing

This repository contains instructions for processing the ChEBI Metabolites SDF file. The **current version is 223, released on 2023-07-01** (see [here](https://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel223/)).

## Steps

1. Download the ChEBI Metabolites SDF file:
```bash
wget https://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel223/SDF/ChEBI_complete_3star.sdf.gz
```

2. Unzip the downloaded file:
```bash
gunzip ChEBI_complete_3star.sdf.gz
```

## Processing Scripts
Both Java and R scripts can be used to process the split SDF files and create the prossesed mapping files. Java is recommended for faster processing. Refer to the links below for more information on using Java or R scripts.

- [Java Processing Scripts](https://github.com/tabbassidaloii/create-bridgedb-secondary2primary/blob/main/src/org/bridgedb/sec2pri/ChEBI_SDF_sec2pri.java), also creates a derby file.
- [R Processing Scripts](https://github.com/tabbassidaloii/BridgeDb-Shiny/blob/main/Docker/app/datasources/ChEBI_processing.R).  
