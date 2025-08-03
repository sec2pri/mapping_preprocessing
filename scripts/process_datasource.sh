#!/bin/bash
set -e

DATASOURCE="$1"

# Simple diff comparison using the original logic
simple_diff() {
    local old="$1"
    local new="$2"
    local columns="$3"
    
    # Extract and sort data
    cut -f "$columns" "$old" | sort | tr -d "\r" > ids_old.txt
    cut -f "$columns" "$new" | sort | tr -d "\r" > ids_new.txt
    
    # Use comm for clean comparison
    added=$(comm -13 ids_old.txt ids_new.txt)
    removed=$(comm -23 ids_old.txt ids_new.txt)
    
    # Count changes
    count_added=$(echo "$added" | grep -c '^' || echo 0)
    count_removed=$(echo "$removed" | grep -c '^' || echo 0)
    
    if [ -z "$added" ]; then count_added=0; added="None"; fi
    if [ -z "$removed" ]; then count_removed=0; removed="None"; fi
    
    echo "=== DIFF RESULTS ==="
    echo "Added: $count_added"
    echo "Removed: $count_removed"
    
    # Export results
    total_changes=$((count_added + count_removed))
    total_old=$(wc -l < "$old")
    change_percent=$((total_old > 0 ? 100 * total_changes / total_old : 0))
    
    {
        echo "ADDED=$count_added"
        echo "REMOVED=$count_removed"
        echo "COUNT=$total_changes"
        echo "CHANGE=$change_percent"
    } >> "$GITHUB_ENV"
    
    rm -f ids_old.txt ids_new.txt
}

case "$DATASOURCE" in
    "chebi")
        # Original ChEBI logic
        . datasources/chebi/config
        wget http://ftp.ebi.ac.uk/pub/databases/chebi/archive/ -O chebi_index.html
        date_new=$(tail -4 chebi_index.html | head -1 | grep -oP '<td align="right">\K[0-9-]+\s[0-9:]+(?=\s+</td>)' | awk '{print $1}')
        release=$(tail -4 chebi_index.html | head -1 | grep -oP '(?<=a href="rel)\d\d\d')
        date_old=$date
        
        echo "DATE_OLD=$date_old" >> "$GITHUB_OUTPUT"
        echo "DATE_NEW=$date_new" >> "$GITHUB_OUTPUT"
        echo "RELEASE_NUMBER=$release" >> "$GITHUB_OUTPUT"
        
        # Download and process
        wget "http://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel${release}/SDF/ChEBI_complete_3star.sdf.gz"
        gunzip ChEBI_complete_3star.sdf.gz
        
        cd java && mvn clean install assembly:single && cd ..
        mkdir -p datasources/chebi/recentData
        java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar \
            org.sec2pri.chebi_sdf "ChEBI_complete_3star.sdf" "datasources/chebi/recentData/" "$release"
        
        if [ $? -eq 0 ]; then
            echo "FAILED=false" >> "$GITHUB_ENV"
        else
            echo "FAILED=true" >> "$GITHUB_ENV"
            exit 1
        fi
        
        # Compare versions - original ChEBI uses basic diff
        . datasources/chebi/config
        old="datasources/chebi/data/$to_check_from_zenodo"
        new="datasources/chebi/recentData/$to_check_from_zenodo"
        simple_diff "$old" "$new" "1,2"
        
        rm -f chebi_index.html
        ;;
        
    "ncbi")
        # Original NCBI logic
        date_old=$(grep -E '^date=' datasources/ncbi/config | cut -d'=' -f2)
        last_modified=$(curl -sI https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz | grep -i Last-Modified)
        date_new=$(echo $last_modified | cut -d':' -f2- | xargs -I {} date -d "{}" +%Y-%m-%d)
        
        echo "DATE_OLD=$date_old" >> "$GITHUB_OUTPUT"
        echo "DATE_NEW=$date_new" >> "$GITHUB_OUTPUT"
        
        # Download data
        mkdir -p datasources/ncbi/data
        wget https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz
        wget https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz
        mv gene_info.gz gene_history.gz datasources/ncbi/data/
        
        # Process data
        cd java && mvn clean install assembly:single && cd ..
        mkdir -p datasources/ncbi/recentData
        java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar \
            org.sec2pri.ncbi_txt "$date_new" \
            "datasources/ncbi/data/gene_history.gz" "datasources/ncbi/data/gene_info.gz" "datasources/ncbi/recentData/"
        
        if [ $? -eq 0 ]; then
            echo "FAILED=false" >> "$GITHUB_ENV"
        else
            echo "FAILED=true" >> "$GITHUB_ENV"
            exit 1
        fi
        
        # Compare versions
        to_check_from_zenodo=$(grep -E '^to_check_from_zenodo=' datasources/ncbi/config | cut -d'=' -f2)
        old="datasources/ncbi/data/$to_check_from_zenodo"
        new="datasources/ncbi/recentData/$to_check_from_zenodo"
        unzip -o datasources/ncbi/data/NCBI_secID2priID.zip -d datasources/ncbi/data/ || true
        simple_diff "$old" "$new" "1,3"
        ;;
        
    "hmdb")
        # Original HMDB logic
        date_old=$(grep -E '^date=' datasources/hmdb/config | cut -d'=' -f2)
        wget http://www.hmdb.ca/system/downloads/current/hmdb_metabolites.zip
        unzip hmdb_metabolites.zip
        date_new=$(head hmdb_metabolites.xml | grep 'update_date' | sed 's/.*>\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/')
        
        echo "DATE_OLD=$date_old" >> "$GITHUB_OUTPUT"
        echo "DATE_NEW=$date_new" >> "$GITHUB_OUTPUT"
        
        # Process XML
        mkdir hmdb
        mv hmdb_metabolites.xml hmdb/
        cd hmdb && xml_split -v -l 1 hmdb_metabolites.xml && rm hmdb_metabolites.xml && cd ..
        zip -r hmdb_metabolites_split.zip hmdb
        
        # Process data
        cd java && mvn clean install assembly:single && cd ..
        mkdir -p datasources/hmdb/recentData
        java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar \
            org.sec2pri.hmdb_xml "hmdb_metabolites_split.zip" "datasources/hmdb/recentData/"
        
        if [ $? -eq 0 ]; then
            echo "FAILED=false" >> "$GITHUB_ENV"
        else
            echo "FAILED=true" >> "$GITHUB_ENV"
            exit 1
        fi
        
        # Compare versions
        to_check_from_zenodo=$(grep -E '^to_check_from_zenodo=' datasources/hmdb/config | cut -d'=' -f2)
        old="datasources/hmdb/data/$to_check_from_zenodo"
        new="datasources/hmdb/recentData/$to_check_from_zenodo"
        simple_diff "$old" "$new" "1,2"
        ;;
        
    "hgnc")
        # Original HGNC logic - no extra packages needed!
        date_old=$(grep -E '^date=' datasources/hgnc/config | cut -d'=' -f2)
        
        # Create Puppeteer script
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
        complete=$(grep -o 'hgnc_complete_set_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.txt' hgnc_index.html | tail -n 1)
        withdrawn=$(grep -o 'withdrawn_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.txt' hgnc_index.html | tail -n 1)
        date_new=$(echo "$complete" | awk -F '_' '{print $4}' | sed 's/\.txt//')
        
        echo "DATE_OLD=$date_old" >> "$GITHUB_OUTPUT"
        echo "DATE_NEW=$date_new" >> "$GITHUB_OUTPUT"
        echo "COMPLETE_NEW=$complete" >> "$GITHUB_OUTPUT"
        echo "WITHDRAWN_NEW=$withdrawn" >> "$GITHUB_OUTPUT"
        
        # Download data
        mkdir -p datasources/hgnc/data
        wget "https://storage.googleapis.com/public-download-files/hgnc/archive/archive/quarterly/tsv/$withdrawn"
        wget "https://storage.googleapis.com/public-download-files/hgnc/archive/archive/quarterly/tsv/$complete"
        mv "$withdrawn" "$complete" datasources/hgnc/data/
        
        # Process data
        Rscript r/src/hgnc.R "$date_new" "datasources/hgnc/data/$withdrawn" "datasources/hgnc/data/$complete"
        
        if [ $? -eq 0 ]; then
            echo "FAILED=false" >> "$GITHUB_ENV"
        else
            echo "FAILED=true" >> "$GITHUB_ENV"
            exit 1
        fi
        
        # Compare versions
        to_check_from_zenodo=$(grep -E '^to_check_from_zenodo=' datasources/hgnc/config | cut -d'=' -f2)
        old="datasources/hgnc/data/$to_check_from_zenodo"
        new="datasources/hgnc/recentData/$to_check_from_zenodo"
        simple_diff "$old" "$new" "1,3"
        
        rm -f hgnc_index.html download.js
        ;;
        
    "uniprot")
        # Original UniProt logic
        date_old=$(grep -E '^date=' datasources/uniprot/config | cut -d'=' -f2)
        wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/ -O uniprot_index.html
        date_new=$(grep -oP 'uniprot_sprot\.fasta\.gz</a></td><td[^>]*>\K[0-9]{4}-[0-9]{2}-[0-9]{2}' uniprot_index.html)
        
        echo "DATE_OLD=$date_old" >> "$GITHUB_OUTPUT"
        echo "DATE_NEW=$date_new" >> "$GITHUB_OUTPUT"
        
        # Download data
        mkdir -p datasources/uniprot/data
        cd datasources/uniprot/data
        wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz
        wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/sec_ac.txt
        wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_sp.txt
        cd ../../..
        
        # Process data
        Rscript r/src/uniprot.R "$date_new" \
            "datasources/uniprot/data/uniprot_sprot.fasta.gz" \
            "datasources/uniprot/data/delac_sp.txt" \
            "datasources/uniprot/data/sec_ac.txt"
        
        if [ $? -eq 0 ]; then
            echo "FAILED=false" >> "$GITHUB_ENV"
        else
            echo "FAILED=true" >> "$GITHUB_ENV"
            exit 1
        fi
        
        # Compare versions
        to_check_from_zenodo=$(grep -E '^to_check_from_zenodo=' datasources/uniprot/config | cut -d'=' -f2)
        old="datasources/uniprot/data/$to_check_from_zenodo"
        new="datasources/uniprot/recentData/$to_check_from_zenodo"
        unzip -q datasources/uniprot/data/UniProt_secID2priID.zip -d datasources/uniprot/data/ || true
        simple_diff "$old" "$new" "1,2"
        
        rm -f uniprot_index.html
        ;;
        
    *)
        echo "ERROR: Unknown datasource $DATASOURCE"
        exit 1
        ;;
esac
