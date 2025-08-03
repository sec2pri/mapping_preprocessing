#!/bin/bash

# Datasource configuration format:
# DATASOURCE_CONFIG="date_function|download_function|process_function|environment_function|columns|pattern"

# Common functions
setup_java() {
    if ! command -v java &> /dev/null; then
        log "Setting up Java"
        sudo apt-get update && sudo apt-get install -y openjdk-11-jdk maven
    fi
}

setup_r() {
    if ! command -v Rscript &> /dev/null; then
        log "Setting up R"
        sudo apt-get update && sudo apt-get install -y r-base
    fi
}

setup_node() {
    if ! command -v node &> /dev/null; then
        log "Setting up Node.js"
        sudo apt-get update && sudo apt-get install -y nodejs npm
        npm install puppeteer
    fi
}

build_java() {
    if [ ! -f "java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar" ]; then
        cd java && mvn clean install assembly:single && cd ..
    fi
}

# ChEBI Configuration
chebi_get_dates() {
    . datasources/chebi/config
    wget "http://ftp.ebi.ac.uk/pub/databases/chebi/archive/" -O index.html
    local date_new=$(tail -4 index.html | head -1 | grep -oP '<td align="right">\K[0-9-]+\s[0-9:]+(?=\s+</td>)' | awk '{print $1}')
    local release=$(tail -4 index.html | head -1 | grep -oP '(?<=a href="rel)\d\d\d')
    echo "RELEASE_NUMBER=$release" >> "$GITHUB_OUTPUT"
    echo "DATE_OLD=$date" >> "$GITHUB_OUTPUT"
    echo "DATE_NEW=$date_new" >> "$GITHUB_OUTPUT"
    rm index.html
}

chebi_download() {
    local release="${RELEASE_NUMBER:-$(grep RELEASE_NUMBER $GITHUB_OUTPUT | cut -d'=' -f2)}"
    wget "http://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel${release}/SDF/ChEBI_complete_3star.sdf.gz"
    gunzip ChEBI_complete_3star.sdf.gz
}

chebi_process() {
    build_java
    mkdir -p datasources/chebi/recentData
    local release="${RELEASE_NUMBER:-$(grep RELEASE_NUMBER $GITHUB_OUTPUT | cut -d'=' -f2)}"
    java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar \
        org.sec2pri.chebi_sdf "ChEBI_complete_3star.sdf" "datasources/chebi/recentData/" "$release"
}

# NCBI Configuration
ncbi_get_dates() {
    local date_old=$(grep -E '^date=' datasources/ncbi/config | cut -d'=' -f2)
    local last_modified=$(curl -sI https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz | grep -i Last-Modified)
    local date_new=$(echo $last_modified | cut -d':' -f2- | xargs -I {} date -d "{}" +%Y-%m-%d)
    echo "DATE_OLD=$date_old" >> "$GITHUB_OUTPUT"
    echo "DATE_NEW=$date_new" >> "$GITHUB_OUTPUT"
}

ncbi_download() {
    mkdir -p datasources/ncbi/data
    wget https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz
    wget https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz
    mv gene_info.gz gene_history.gz datasources/ncbi/data/
}

ncbi_process() {
    build_java
    mkdir -p datasources/ncbi/recentData
    local date_new=$(grep DATE_NEW $GITHUB_OUTPUT | cut -d'=' -f2)
    java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar \
        org.sec2pri.ncbi_txt "$date_new" \
        "datasources/ncbi/data/gene_history.gz" "datasources/ncbi/data/gene_info.gz" "datasources/ncbi/recentData/"
}

# HMDB Configuration
hmdb_get_dates() {
    sudo apt-get install xml-twig-tools
    local date_old=$(grep -E '^date=' datasources/hmdb/config | cut -d'=' -f2)
    wget http://www.hmdb.ca/system/downloads/current/hmdb_metabolites.zip
    unzip hmdb_metabolites.zip
    local date_new=$(head hmdb_metabolites.xml | grep 'update_date' | sed 's/.*>\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/')
    echo "DATE_OLD=$date_old" >> "$GITHUB_OUTPUT"
    echo "DATE_NEW=$date_new" >> "$GITHUB_OUTPUT"
    rm hmdb_metabolites.xml hmdb_metabolites.zip
}

hmdb_download() {
    sudo apt-get install xml-twig-tools
    wget http://www.hmdb.ca/system/downloads/current/hmdb_metabolites.zip
    unzip hmdb_metabolites.zip
    mkdir hmdb
    mv hmdb_metabolites.xml hmdb/
    cd hmdb && xml_split -v -l 1 hmdb_metabolites.xml && rm hmdb_metabolites.xml && cd ..
    zip -r hmdb_metabolites_split.zip hmdb
}

hmdb_process() {
    build_java
    mkdir -p datasources/hmdb/recentData
    java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar \
        org.sec2pri.hmdb_xml "hmdb_metabolites_split.zip" "datasources/hmdb/recentData/"
}

# UniProt Configuration
uniprot_get_dates() {
    local date_old=$(grep -E '^date=' datasources/uniprot/config | cut -d'=' -f2)
    wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/ -O index.html
    local date_new=$(grep -oP 'uniprot_sprot\.fasta\.gz</a></td><td[^>]*>\K[0-9]{4}-[0-9]{2}-[0-9]{2}' index.html)
    echo "DATE_OLD=$date_old" >> "$GITHUB_OUTPUT"
    echo "DATE_NEW=$date_new" >> "$GITHUB_OUTPUT"
    rm index.html
}

uniprot_download() {
    mkdir -p datasources/uniprot/data
    cd datasources/uniprot/data
    wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz
    wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/sec_ac.txt
    wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_sp.txt
    cd ../../..
}

uniprot_process() {
    local date_new=$(grep DATE_NEW $GITHUB_OUTPUT | cut -d'=' -f2)
    Rscript r/src/uniprot.R "$date_new" \
        "datasources/uniprot/data/uniprot_sprot.fasta.gz" \
        "datasources/uniprot/data/delac_sp.txt" \
        "datasources/uniprot/data/sec_ac.txt"
}

# HGNC Configuration
hgnc_get_dates() {
    setup_node
    local date_old=$(grep -E '^date=' datasources/hgnc/config | cut -d'=' -f2)
    
    cat <<EOF > download.js
const puppeteer = require('puppeteer');
(async () => {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage();
    await page.goto('https://www.genenames.org/download/archive/quarterly/tsv/', { waitUntil: 'networkidle0' });
    const content = await page.content();
    const fs = require('fs');
    fs.writeFileSync('hgnc_index.html', content);
    await browser.close();
})();
EOF
    
    node download.js
    local complete=$(grep -o 'hgnc_complete_set_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.txt' hgnc_index.html | tail -n 1)
    local withdrawn=$(grep -o 'withdrawn_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.txt' hgnc_index.html | tail -n 1)
    local date_new=$(echo "$complete" | awk -F '_' '{print $4}' | sed 's/\.txt//')
    echo "DATE_OLD=$date_old" >> "$GITHUB_OUTPUT"
    echo "DATE_NEW=$date_new" >> "$GITHUB_OUTPUT"
    echo "COMPLETE_NEW=$complete" >> "$GITHUB_OUTPUT"
    echo "WITHDRAWN_NEW=$withdrawn" >> "$GITHUB_OUTPUT"
    rm hgnc_index.html download.js
}

hgnc_download() {
    mkdir -p datasources/hgnc/data
    local complete=$(grep COMPLETE_NEW $GITHUB_OUTPUT | cut -d'=' -f2)
    local withdrawn=$(grep WITHDRAWN_NEW $GITHUB_OUTPUT | cut -d'=' -f2)
    wget "https://storage.googleapis.com/public-download-files/hgnc/archive/archive/quarterly/tsv/$withdrawn"
    wget "https://storage.googleapis.com/public-download-files/hgnc/archive/archive/quarterly/tsv/$complete"
    mv "$withdrawn" "$complete" datasources/hgnc/data/
}

hgnc_process() {
    local date_new=$(grep DATE_NEW $GITHUB_OUTPUT | cut -d'=' -f2)
    local complete=$(grep COMPLETE_NEW $GITHUB_OUTPUT | cut -d'=' -f2)
    local withdrawn=$(grep WITHDRAWN_NEW $GITHUB_OUTPUT | cut -d'=' -f2)
    Rscript r/src/hgnc.R "$date_new" \
        "datasources/hgnc/data/$withdrawn" \
        "datasources/hgnc/data/$complete"
}

# Configuration mappings
chebi_CONFIG="chebi_get_dates|chebi_download|chebi_process|setup_java|1,2|ChEBI"
ncbi_CONFIG="ncbi_get_dates|ncbi_download|ncbi_process|setup_java|1,3|Entrez Gene"
hmdb_CONFIG="hmdb_get_dates|hmdb_download|hmdb_process|setup_java|1,2|HMDB"
uniprot_CONFIG="uniprot_get_dates|uniprot_download|uniprot_process|setup_r|1,2|"
hgnc_CONFIG="hgnc_get_dates|hgnc_download|hgnc_process|setup_r|1,3|HGNC"
