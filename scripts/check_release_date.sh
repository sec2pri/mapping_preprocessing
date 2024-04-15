#!/bin/bash
#
# Script: check_release_date.sh
# Description: A script to check whether the data sources 
# Author: Javier Millan Acosta
# Date: April 2024

# Check if the source argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <source> (chebi | hgnc | hmdb | ncbi | uniprot)"
    exit 1
fi

source="$1"

## Read config variables
. datasources/$source/config .
## Date of current version data
date_old=$(grep -E '^date=' datasources/$source/config | cut -d'=' -f2)

## Access the source to retrieve the latest release date
echo "Accessing the $source archive"
case $source in
    "chebi")
        wget -qO $source_index.html https://ftp.ebi.ac.uk/pub/databases/$source/archive/
        release=$(tail -4 $source_index.html | head -1 | grep -oP '(?<=a href="rel)\d\d\d')
        date_new=$(tail -4 $source_index.html | head -1 | grep -oP '<td align="right">\K[0-9-]+\s[0-9:]+(?=\s+</td>)' | awk '{print $1}')
        ;;
    "hgnc")
        echo "Accessing the hgnc data"
        wget -qO hgnc_index.html https://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/archive/quarterly/tsv/
        complete=$(grep -o 'hgnc_complete_set_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.txt' hgnc_index.html | tail -n 1)
        withdrawn=$(grep -o 'withdrawn_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.txt' hgnc_index.html | tail -n 1)
        date_new=$(echo "$complete" | awk -F '_' '{print $4}' | sed 's/\.txt//')
        echo "COMPLETE_NEW=$complete" >> $GITHUB_OUTPUT
        echo "WITHDRAWN_NEW=$withdrawn" >> $GITHUB_OUTPUT
        ;;
    "hmdb")
        echo "Accessing the hmdb data"
        sudo apt-get -qq install xml-twig-tools
        date_old=$(grep -E '^date=' datasources/hmdb/config | cut -d'=' -f2)
        wget -qO hmdb_metabolites.zip http://www.hmdb.ca/system/downloads/current/hmdb_metabolites.zip
        unzip -qo hmdb_metabolites.zip
        date_new=$(head -n 1 hmdb_metabolites.xml | grep -oP 'update_date>\K[0-9]{4}-[0-9]{2}-[0-9]{2}')
        
        ;;
    "ncbi")
        echo "Accessing the ncbi data"
        date_old=$(grep -E '^date=' datasources/ncbi/config | cut -d'=' -f2)
        last_modified=$(curl -sI https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz | grep -i Last-Modified)
        date_new=$(echo $last_modified | cut -d':' -f2- | xargs -I {} date -d "{}" +%Y-%m-%d)
        ;;
    "uniprot")
        echo "Accessing the uniprot data"
        wget -qO uniprot_index.html https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/
        date_new=$(grep -oP 'uniprot_sprot\.fasta\.gz</a></td><td[^>]*>\K[0-9]{4}-[0-9]{2}-[0-9]{2}' uniprot_index.html)
        ;;
    *)
        echo "Invalid source: $source"
        echo "Usage: $0 <source> (chebi | hgnc | hmdb | ncbi | uniprot)"
        exit 1
        ;;
esac

echo "RELEASE_NUMBER=$release" >> $GITHUB_OUTPUT
echo "DATE_OLD=$date_old" >> $GITHUB_OUTPUT
echo "DATE_NEW=$date_new" >> $GITHUB_OUTPUT

timestamp1=$(date -d "$date_new" +%s)
timestamp2=$(date -d "$date_old" +%s)

if [ "$timestamp1" -gt "$timestamp2" ]; then
    echo "New release available: $release"
    echo "NEW_RELEASE=true" >> $GITHUB_OUTPUT
else
    echo "No new release available"
fi

echo "Date of latest release: $date_new, Date of release of the current version: $date_old"

## Clean up
rm -f $source_index.html
