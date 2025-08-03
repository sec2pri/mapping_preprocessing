#!/bin/bash

# Helper functions for datasource operations

# Datasource configuration
declare -A DATASOURCE_URLS=(
    ["chebi_archive"]="http://ftp.ebi.ac.uk/pub/databases/chebi/archive/"
    ["ncbi_gene_history"]="https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz"
    ["ncbi_gene_info"]="https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz"
    ["hmdb_metabolites"]="http://www.hmdb.ca/system/downloads/current/hmdb_metabolites.zip"
    ["uniprot_base"]="https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete"
    ["hgnc_archive"]="https://www.genenames.org/download/archive/quarterly/tsv/"
    ["hgnc_storage"]="https://storage.googleapis.com/public-download-files/hgnc/archive/archive/quarterly/tsv"
)

# Function to get datasource dates
get_datasource_dates() {
    local datasource="$1"
    local date_old date_new
    
    case "$datasource" in
        "chebi")
            . datasources/chebi/config .
            wget "${DATASOURCE_URLS[chebi_archive]}" -O index.html
            date_new=$(tail -4 index.html | head -1 | grep -oP '<td align="right">\K[0-9-]+\s[0-9:]+(?=\s+</td>)' | awk '{print $1}')
            release=$(tail -4 index.html | head -1 | grep -oP '(?<=a href="rel)\d\d\d')
            date_old=$date
            echo "RELEASE_NUMBER=$release" >> $GITHUB_OUTPUT
            rm index.html
            ;;
        "ncbi")
            date_old=$(grep -E '^date=' datasources/ncbi/config | cut -d'=' -f2)
            last_modified=$(curl -sI "${DATASOURCE_URLS[ncbi_gene_history]}" | grep -i Last-Modified)
            date_new=$(echo $last_modified | cut -d':' -f2- | xargs -I {} date -d "{}" +%Y-%m-%d)
            ;;
        "hmdb")
            sudo apt-get install xml-twig-tools
            date_old=$(grep -E '^date=' datasources/hmdb/config | cut -d'=' -f2)
            wget "${DATASOURCE_URLS[hmdb_metabolites]}"
            unzip hmdb_metabolites.zip
            date_new=$(head hmdb_metabolites.xml | grep 'update_date' | sed 's/.*>\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/')
            rm hmdb_metabolites.xml hmdb_metabolites.zip
            ;;
        "uniprot")
            date_old=$(grep -E '^date=' datasources/uniprot/config | cut -d'=' -f2)
            wget "${DATASOURCE_URLS[uniprot_base]}/" -O index.html
            date_new=$(grep -oP 'uniprot_sprot\.fasta\.gz</a></td><td[^>]*>\K[0-9]{4}-[0-9]{2}-[0-9]{2}' index.html)
            rm index.html
            ;;
        "hgnc")
            setup_puppeteer
            date_old=$(grep -E '^date=' datasources/hgnc/config | cut -d'=' -f2)
            get_hgnc_files
            ;;
    esac
    
    echo "DATE_OLD=$date_old" >> $GITHUB_OUTPUT
    echo "DATE_NEW=$date_new" >> $GITHUB_OUTPUT
    echo "Date comparison: old=$date_old, new=$date_new"
}

# Helper function for HGNC Puppeteer setup
setup_puppeteer() {
    sudo apt-get update && sudo apt-get install -y nodejs npm
    npm install puppeteer
}

# Helper function to get HGNC files
get_hgnc_files() {
    cat <<EOF > download.js
const puppeteer = require('puppeteer');
(async () => {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage();
    await page.goto('${DATASOURCE_URLS[hgnc_archive]}', { waitUntil: 'networkidle0' });
    const content = await page.content();
    const fs = require('fs');
    fs.writeFileSync('hgnc_index.html', content);
    await browser.close();
})();
EOF
    
    node download.js
    complete=$(grep -o 'hgnc_complete_set_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.txt' hgnc_index.html | tail -n 1)
    withdrawn=$(grep -o 'withdrawn_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.txt' hgnc_index.html | tail -n 1)
    date_new=$(echo "$complete" | awk -F '_' '{print $4}' | sed 's/\.txt//')
    echo "COMPLETE_NEW=$complete" >> $GITHUB_OUTPUT
    echo "WITHDRAWN_NEW=$withdrawn" >> $GITHUB_OUTPUT
    rm hgnc_index.html download.js
}
