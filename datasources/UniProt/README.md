# UniProt Processing

This repository contains instructions for processing the Uniprot relevant files. The **current version is Release 2023_03** (see [here](https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/)).

The files used for data extraction are as follows:

- **uniprot_sprot.fasta.gz**: Complete UniProtKB/Swiss-Prot data set in FASTA format.
Release:     28-Jun-2023

- **delac_sp.txt**: This file lists the accession numbers of UniProtKB/Swiss-Prot entries which have been deleted from the database.
Release:     2023_03 of 28-Jun-2023

- **sec_ac.txt**: This file lists all secondary accession numbers in UniProtKB (Swiss-Prot and TrEMBL), together with their corresponding current primary accession number(s).
Release:     28-Jun-2023

## Processing Scripts
To download and process the fasta and txt files and create the processed mapping files, you can use R scripts. For detailed information on using R scripts, please refer to the following link:

- [R Processing Scripts](https://github.com/tabbassidaloii/BridgeDb-Shiny/blob/main/Docker/app/datasources/UniProt_processing.R).  

