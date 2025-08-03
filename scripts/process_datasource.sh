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
        
        mkdir -p datasources/uniprot/data
        cd datasources/uniprot/data
        wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz
        wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/sec_ac.txt
        wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_sp.txt
        cd ../../..
        
        Rscript r/src/uniprot.R "$date_new" "datasources/uniprot/data/uniprot_sprot.fasta.gz" "datasources/uniprot/data/delac_sp.txt" "datasources/uniprot/data/sec_ac.txt"
        
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
        
    # Add other datasources following the same simple pattern...
    *)
        echo "Datasource $DATASOURCE not implemented yet"
        exit 1
        ;;
esac
