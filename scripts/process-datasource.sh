#!/bin/bash
set -e

DATASOURCE=$1
if [[ -z "$DATASOURCE" ]]; then
    echo "Error: Datasource parameter required"
    exit 1
fi

CONFIG_FILE="datasources/$DATASOURCE/config"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Extract config values using grep like in individual workflows
DATE_OLD=$(grep -E '^date=' "$CONFIG_FILE" | cut -d'=' -f2)
TO_CHECK_FROM_ZENODO=$(grep -E '^to_check_from_zenodo=' "$CONFIG_FILE" | cut -d'=' -f2)

case "$DATASOURCE" in
    chebi)
        # ChEBI workflow logic
        CURRENT_RELEASE=$(grep -E '^release=' "$CONFIG_FILE" | cut -d'=' -f2)
        
        echo 'Accessing the ChEBI archive'
        wget http://ftp.ebi.ac.uk/pub/databases/chebi/archive/ -O chebi_index.html
        DATE_NEW=$(tail -4 chebi_index.html | head -1 | grep -oP '<td align="right">\K[0-9-]+\s[0-9:]+(?=\s+</td>)' | awk '{print $1}')
        RELEASE_NUMBER=$(tail -4 chebi_index.html | head -1 | grep -oP '(?<=a href="rel)\d\d\d')
        rm chebi_index.html
        
        echo "DATE_NEW=$DATE_NEW" >> $GITHUB_ENV
        echo "DATE_OLD=$DATE_OLD" >> $GITHUB_ENV
        
        timestamp1=$(date -d "$DATE_NEW" +%s)
        timestamp2=$(date -d "$DATE_OLD" +%s)
        if [ "$timestamp1" -gt "$timestamp2" ]; then
            max_retries=5
            retry_count=0
            success=false
            while [ $retry_count -lt $max_retries ]; do
                response=$(curl -o /dev/null -s -w "%{http_code}" "http://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel${RELEASE_NUMBER}/SDF/ChEBI_complete_3star.sdf.gz")
                curl_exit_code=$?
                if [ $curl_exit_code -eq 0 ] && [ "$response" -eq 200 ]; then
                    echo "File is accessible, response code: $response"
                    echo "New release available: $RELEASE_NUMBER"
                    success=true
                    break
                else
                    echo "Attempt $((retry_count + 1)) failed. Response code: $response, curl exit code: $curl_exit_code"
                    echo "Retrying in 1 minute..."
                    sleep 60
                    retry_count=$((retry_count + 1))
                fi
            done
            if [ "$success" = false ]; then
                echo "Error: Unable to access latest ChEBI release (rel${RELEASE_NUMBER}) after $max_retries attempts"
                echo "ISSUE=true" >> $GITHUB_ENV
                exit 1
            fi
        else
            echo "No new release available"
            exit 0
        fi
        
        # Download data
        wget "http://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel${RELEASE_NUMBER}/SDF/ChEBI_complete_3star.sdf.gz"
        gunzip ChEBI_complete_3star.sdf.gz
        
        # Process data
        mkdir -p "datasources/chebi/recentData/"
        cd java && mvn clean install assembly:single && cd ..
        java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar org.sec2pri.chebi_sdf "ChEBI_complete_3star.sdf" "datasources/chebi/recentData/" "${RELEASE_NUMBER}"
        if [ $? -eq 0 ]; then
            echo "FAILED=false" >> $GITHUB_ENV
        else
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi
        
        # Diff
        old="datasources/chebi/data/$TO_CHECK_FROM_ZENODO"
        new="datasources/chebi/recentData/$TO_CHECK_FROM_ZENODO"
        
        wget -nc https://raw.githubusercontent.com/bridgedb/datasources/main/datasources.tsv
        CHEBI_ID=$(awk -F '\t' '$1 == "ChEBI" {print $10}' datasources.tsv)
        awk -F '\t' '{print $1}' $new > column1.txt
        awk -F '\t' '{print $2}' $new > column2.txt
        
        if grep -nqvE "$CHEBI_ID" "column1.txt"; then
            echo "All lines in the primary column match the pattern."
        else
            echo "Error: At least one line in the primary column does not match pattern."
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi
        
        if grep -nqvE "$CHEBI_ID" "column1.txt"; then
            echo "All lines in the secondary column match the pattern."
        else
            echo "Error: At least one line in the secondary column does not match pattern."
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi
        
        cat "$old" | sort | tr -d "\r" > ids_old.txt
        cat "$new" | sort | tr -d "\r" > ids_new.txt
        diff -u ids_old.txt ids_new.txt > diff.txt || true
        added=$(grep '^+CHEBI' "diff.txt" | sed 's/+//g') || true
        removed=$(grep '^-' "diff.txt" | sed 's/-//g') || true
        added_filtered=$(comm -23 <(sort <<< "$added") <(sort <<< "$removed"))
        removed_filtered=$(comm -23 <(sort <<< "$removed") <(sort <<< "$added"))
        added=$added_filtered
        removed=$removed_filtered
        ;;
        
    uniprot)
        # UniProt workflow logic
        echo 'Accessing the uniprot data'
        wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/ -O uniprot_index.html
        DATE_NEW=$(grep -oP 'uniprot_sprot\.fasta\.gz</a></td><td[^>]*>\K[0-9]{4}-[0-9]{2}-[0-9]{2}' uniprot_index.html)
        rm uniprot_index.html
        
        echo "DATE_NEW=$DATE_NEW" >> $GITHUB_ENV
        echo "DATE_OLD=$DATE_OLD" >> $GITHUB_ENV
        
        # Download data
        mkdir -p datasources/uniprot/data
        cd datasources/uniprot/data
        wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz
        wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/sec_ac.txt
        wget https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_sp.txt
        cd - > /dev/null
        
        # Process data
        Rscript r/src/uniprot.R "$DATE_NEW" "datasources/uniprot/data/uniprot_sprot.fasta.gz" "datasources/uniprot/data/delac_sp.txt" "datasources/uniprot/data/sec_ac.txt"
        if [ $? -eq 0 ]; then
            echo "FAILED=false" >> $GITHUB_ENV
        else
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi
        
        
        old="datasources/uniprot/data/$TO_CHECK_FROM_ZENODO"
        new="datasources/uniprot/recentData/$TO_CHECK_FROM_ZENODO"
        
        unzip datasources/uniprot/data/UniProt_secID2priID.zip -d datasources/uniprot/data/
        cat "$old" | sort | tr -d "\r" | cut -f 1,2 > ids_old.txt
        cat "$new" | sort | tr -d "\r" | cut -f 1,2 > ids_new.txt
        diff -u ids_old.txt ids_new.txt > diff.txt || true
        added=$(grep '^+' "diff.txt" | sed 's/+//g') || true
        removed=$(grep '^-' "diff.txt" | sed 's/-//g') || true
        added_filtered=$(comm -23 <(sort <<< "$added") <(sort <<< "$removed"))
        removed_filtered=$(comm -23 <(sort <<< "$removed") <(sort <<< "$added"))
        added=$added_filtered
        removed=$removed_filtered
        ;;
        
    ncbi)
        # NCBI workflow logic
        echo 'Accessing the ncbi data'
        last_modified=$(curl -sI https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz | grep -i Last-Modified)
        DATE_NEW=$(echo $last_modified | cut -d':' -f2- | xargs -I {} date -d "{}" +%Y-%m-%d)
        
        echo "DATE_NEW=$DATE_NEW" >> $GITHUB_ENV
        echo "DATE_OLD=$DATE_OLD" >> $GITHUB_ENV
        
        # Download data
        mkdir -p datasources/ncbi/data
        cd datasources/ncbi/data
        wget https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz
        wget https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz
        cd - > /dev/null
        
        # Process data
        cd java && mvn clean install assembly:single && cd ..
        mkdir -p "datasources/ncbi/recentData/"
        java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar org.sec2pri.ncbi_txt "$DATE_NEW" "datasources/ncbi/data/gene_history.gz" "datasources/ncbi/data/gene_info.gz" "datasources/ncbi/recentData/"
        if [ $? -eq 0 ]; then
            echo "FAILED=false" >> $GITHUB_ENV
        else
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi
        
        
        old="datasources/ncbi/data/$TO_CHECK_FROM_ZENODO"
        new="datasources/ncbi/recentData/$TO_CHECK_FROM_ZENODO"
        
        unzip -o datasources/ncbi/data/NCBI_secID2priID.zip -d datasources/ncbi/data/
        wget -nc https://raw.githubusercontent.com/bridgedb/datasources/main/datasources.tsv
        NCBI_ID=$(awk -F '\t' '$1 == "Entrez Gene" {print $10}' datasources.tsv)
        awk -F '\t' '{print $1}' $new > column1.txt
        awk -F '\t' '{print $2}' $new > column2.txt
        
        if grep -nqvE "$NCBI_ID" "column1.txt"; then
            echo "All lines in the primary column match the pattern."
        else
            echo "Error: At least one line in the primary column does not match pattern."
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi
        
        if grep -nqvE "$NCBI_ID" "column1.txt"; then
            echo "All lines in the secondary column match the pattern."
        else
            echo "Error: At least one line in the secondary column does not match pattern."
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi
        
        cat "$old" | sort | tr -d "\r" | cut -f 1,3 > ids_old.txt
        cat "$new" | sort | tr -d "\r" | cut -f 1,3 > ids_new.txt
        diff -u ids_old.txt ids_new.txt > diff.txt || true
        added=$(grep '^+' "diff.txt" | sed 's/+//g') || true
        removed=$(grep '^-' "diff.txt" | sed 's/-//g') || true
        added_filtered=$(comm -23 <(sort <<< "$added") <(sort <<< "$removed"))
        removed_filtered=$(comm -23 <(sort <<< "$removed") <(sort <<< "$added"))
        added=$added_filtered
        removed=$removed_filtered
        ;;
        
    hmdb)
        # HMDB workflow logic
        echo 'Accessing the hmdb data'
        wget http://www.hmdb.ca/system/downloads/current/hmdb_metabolites.zip
        unzip hmdb_metabolites.zip
        DATE_NEW=$(head hmdb_metabolites.xml | grep 'update_date' | sed 's/.*>\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/')
        
        echo "DATE_NEW=$DATE_NEW" >> $GITHUB_ENV
        echo "DATE_OLD=$DATE_OLD" >> $GITHUB_ENV
        
        # Process downloaded data
        mkdir hmdb
        mv hmdb_metabolites.xml hmdb
        cd hmdb
        xml_split -v -l 1 hmdb_metabolites.xml
        rm hmdb_metabolites.xml
        cd ..
        zip -r hmdb_metabolites_split.zip hmdb
        
        # Process data
        cd java && mvn clean install assembly:single && cd ..
        mkdir -p "datasources/hmdb/recentData/"
        java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar org.sec2pri.hmdb_xml "hmdb_metabolites_split.zip" "datasources/hmdb/recentData/"
        if [ $? -eq 0 ]; then
            echo "FAILED=false" >> $GITHUB_ENV
        else
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi
        
        
        old="datasources/hmdb/data/$TO_CHECK_FROM_ZENODO"
        new="datasources/hmdb/recentData/$TO_CHECK_FROM_ZENODO"
        
        wget -nc https://raw.githubusercontent.com/bridgedb/datasources/main/datasources.tsv
        HMDB_ID=$(awk -F '\t' '$1 == "HMDB" {print $10}' datasources.tsv)
        awk -F '\t' '{print $1}' $new > column1.txt
        awk -F '\t' '{print $2}' $new > column2.txt
        
        if grep -nqvE "$HMDB_ID" "column1.txt"; then
            echo "All lines in the primary column match the pattern."
        else
            echo "Error: At least one line in the primary column does not match pattern."
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi
        
        if grep -nqvE "$HMDB_ID" "column1.txt"; then
            echo "All lines in the secondary column match the pattern."
        else
            echo "Error: At least one line in the secondary column does not match pattern."
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi
        
        cat "$old" | sort | tr -d "\r" > ids_old.txt
        cat "$new" | sort | tr -d "\r" > ids_new.txt
        diff -u ids_old.txt ids_new.txt > diff.txt || true
        added=$(grep '^+' "diff.txt" | sed 's/+//g') || true
        removed=$(grep '^-' "diff.txt" | sed 's/-//g') || true
        added_filtered=$(comm -23 <(sort <<< "$added") <(sort <<< "$removed"))
        removed_filtered=$(comm -23 <(sort <<< "$removed") <(sort <<< "$added"))
        added=$added_filtered
        removed=$removed_filtered
        ;;
        
    hgnc)
        # HGNC workflow logic
        cat > download.js << 'EOF'
const puppeteer = require('puppeteer');
(async () => {
    const browser = await puppeteer.launch({headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox']});
    const page = await browser.newPage();
    await page.goto('https://www.genenames.org/download/archive/quarterly/tsv/', { waitUntil: 'networkidle0' });
    const content = await page.content();
    require('fs').writeFileSync('hgnc_index.html', content);
    await browser.close();
})();
EOF
        node download.js
        COMPLETE_NEW=$(grep -o 'hgnc_complete_set_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.txt' hgnc_index.html | tail -n 1)
        WITHDRAWN_NEW=$(grep -o 'withdrawn_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\.txt' hgnc_index.html | tail -n 1)
        DATE_NEW=$(echo "$COMPLETE_NEW" | awk -F '_' '{print $4}' | sed 's/\.txt//')
        rm hgnc_index.html download.js
        
        echo "DATE_NEW=$DATE_NEW" >> $GITHUB_ENV
        echo "DATE_OLD=$DATE_OLD" >> $GITHUB_ENV
        echo "COMPLETE_NEW=$COMPLETE_NEW" >> $GITHUB_ENV
        echo "WITHDRAWN_NEW=$WITHDRAWN_NEW" >> $GITHUB_ENV
        
        # Download data
        mkdir -p datasources/hgnc/data
        cd datasources/hgnc/data
        wget "https://storage.googleapis.com/public-download-files/hgnc/archive/archive/quarterly/tsv/${WITHDRAWN_NEW}"
        wget "https://storage.googleapis.com/public-download-files/hgnc/archive/archive/quarterly/tsv/${COMPLETE_NEW}"
        cd - > /dev/null
        
        # Process data
        Rscript r/src/hgnc.R "$DATE_NEW" "datasources/hgnc/data/${WITHDRAWN_NEW}" "datasources/hgnc/data/${COMPLETE_NEW}"
        if [ $? -eq 0 ]; then
            echo "FAILED=false" >> $GITHUB_ENV
        else
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi
        
        
        old="datasources/hgnc/data/$TO_CHECK_FROM_ZENODO"
        new="datasources/hgnc/recentData/$TO_CHECK_FROM_ZENODO"
        
        cat "$old" | sort | tr -d "\r" | cut -f 1,3 > ids_old.txt
        cat "$new" | sort | tr -d "\r" | cut -f 1,3 > ids_new.txt
        diff -u ids_old.txt ids_new.txt > diff.txt || true
        added=$(grep '^+' "diff.txt" | sed 's/+//g') || true
        removed=$(grep '^-' "diff.txt" | sed 's/-//g') || true
        added_filtered=$(comm -23 <(sort <<< "$added") <(sort <<< "$removed"))
        removed_filtered=$(comm -23 <(sort <<< "$removed") <(sort <<< "$added"))
        added=$added_filtered
        removed=$removed_filtered
        ;;
esac

# Common counting logic (same for all datasources)
count_removed=$(printf "$removed" | wc -l) || true
count_added=$(printf "$added" | wc -l) || true

if [ -z "$removed" ]; then
    count_removed=0
fi
if [ -z "$added" ]; then
    count_added=0
fi

echo "- Added id pairs: $count_added"
echo "- Removed id pairs: $count_removed"

echo "ADDED=$count_added" >> $GITHUB_ENV
echo "REMOVED=$count_removed" >> $GITHUB_ENV
count=$(expr $count_added + $count_removed) || true
echo "COUNT=$count" >> $GITHUB_ENV

if [[ $count -gt 0 ]]; then
    total_old=$(cat ids_old.txt | wc -l) || true
    change=$((100 * count / total_old))
    echo "CHANGE=$change" >> $GITHUB_ENV
fi

rm -f ids_old.txt ids_new.txt diff.txt column1.txt column2.txt datasources.tsv

echo "Processing completed for $DATASOURCE"
