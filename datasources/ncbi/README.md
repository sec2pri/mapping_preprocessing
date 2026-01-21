# NCBI tsv Processing

This repository contains instructions for processing the NCBI files (gene_history.gz). These two files are updated daily (see [here](https://ftp.ncbi.nih.gov/gene/README).


from [NCBI's README](https://ftp.ncbi.nih.gov/gene/README):
```
NOTE: As files are added or modified in this ftp site, notification will be sent via the Gene News RSS feed.

You may subscribe to the Gene News RSS feed here:
            https://www.ncbi.nlm.nih.gov/feed/rss.cgi?ChanKey=genenews
```

## Steps

1. Download the relevant files from NCBI:
```bash
wget https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz 
wget https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz
```

2. Unzip the downloaded file:
```bash
 gzip -d *.gz
```

3. keeping rows with data for human and mice (later filtered out):
```bash
date_extension=$(date +%Y-%m-%d)
awk 'NR==1 || $1 == "9606" || $1 == "10090"'  gene_info > "gene_info_human_mice_${date_extension}"
awk 'NR==1 || $1 == "9606" || $1 == "10090"'  gene_history > "gene_history_human_mice_${date_extension}"
```

## Processing Scripts

R scripts can be used to process the files and create the prossesed mapping files. 
- [R Processing Scripts](https://github.com/sec2pri/mapping_preprocessing/blob/main/r/src/ncbi.R), the input for this script is the "NCBI" directory.  
