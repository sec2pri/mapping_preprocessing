# HGNC Processing

This repository contains instructions for processing the HGNC TSV files. The **current version is released on 2023-07-01**. You can access the files [here](https://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/archive/quarterly/tsv/).

The files used for data extraction are as follows:

- **hgnc_complete_set.txt**: This file contains the complete set of all approved gene symbol reports found on the GRCh38 reference and the alternative reference loci.

- **withdrawn.txt**: This file includes gene symbol reports that are no longer approved. It consists of symbols that have been withdrawn or merged/split into other reports.

## Processing Scripts
To download and process the TSV files and create the processed mapping files, you can use R scripts. For detailed information on using R scripts, please refer to the following link:

- [R Processing Scripts](https://github.com/tabbassidaloii/BridgeDb-Shiny/blob/main/Docker/app/datasources/HGNC_processing.R).  



