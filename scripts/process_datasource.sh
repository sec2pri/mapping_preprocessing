#!/bin/bash
set -e

DATASOURCE="$1"

case "$DATASOURCE" in
    "chebi")
        # EXACT COPY from original ChEBI workflow - check_new_release job
        . datasources/chebi/config .
        echo 'Accessing the ChEBI archive'
        wget http://ftp.ebi.ac.uk/pub/databases/chebi/archive/ -O chebi_index.html
        echo "CURRENT_RELEASE_NUMBER=$release" >> "$GITHUB_OUTPUT"
        
        date_new=$(tail -4 chebi_index.html | head -1 | grep -oP '<td align="right">\K[0-9-]+\s[0-9:]+(?=\s+</td>)' | awk '{print $1}')
        release_new=$(tail -4 chebi_index.html | head -1 | grep -oP '(?<=a href="rel)\d\d\d')
        date_old=$date
        echo "RELEASE_NUMBER=$release_new" >> "$GITHUB_OUTPUT"
        echo "DATE_OLD=$date_old" >> "$GITHUB_OUTPUT"
        echo "DATE_NEW=$date_new" >> "$GITHUB_OUTPUT"
        
        timestamp1=$(date -d "$date_new" +%s)
        timestamp2=$(date -d "$date_old" +%s)
        if [ "$timestamp1" -gt "$timestamp2" ]; then
            # Retry logic for checking file accessibility
            max_retries=5
            retry_count=0
            success=false

            while [ $retry_count -lt $max_retries ]; do
              response=$(curl -o /dev/null -s -w "%{http_code}" "http://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel${release_new}/SDF/ChEBI_complete_3star.sdf.gz")
              curl_exit_code=$?

              if [ $curl_exit_code -eq 0 ] && [ "$response" -eq 200 ]; then
              echo "File is accessible, response code: $response"
              echo "New release available: $release_new"
              echo "NEW_RELEASE=true" >> "$GITHUB_OUTPUT"
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
              echo "Error: Unable to access latest ChEBI release (rel${release_new}) after $max_retries attempts"
              echo "FAILED=true" >> "$GITHUB_ENV"
              echo "ISSUE=true" >> "$GITHUB_ENV"
              echo "NEW_RELEASE=false" >> "$GITHUB_OUTPUT"
              exit 1
            fi
        else
            echo "No new release available"
            echo "COUNT=0" >> "$GITHUB_ENV"
            exit 0
        fi
        echo "Date of latest release: $date_new", "Date of release of the current version: $date_old"
        rm chebi_index.html

        # EXACT COPY from original ChEBI workflow - test_sdf_processing job
        echo "DATE_NEW=$date_new" >> $GITHUB_ENV
        echo "RELEASE_NUMBER=$release_new" >> $GITHUB_ENV
        echo "CURRENT_RELEASE_NUMBER=$release" >> $GITHUB_ENV
        url_release="http://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel$release_new/SDF/"
        echo "URL_RELEASE=$url_release" >> $GITHUB_ENV
        wget "http://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel${release_new}/SDF/ChEBI_complete_3star.sdf.gz"
        gunzip ChEBI_complete_3star.sdf.gz
        ls
        chmod +x datasources/chebi/config
        . datasources/chebi/config .
        mkdir -p datasources/chebi/recentData

        inputFile="ChEBI_complete_3star.sdf" 
        mkdir new
        cd java
        mvn clean install assembly:single
        cd ../
        outputDir="datasources/chebi/recentData/"
        java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar org.sec2pri.chebi_sdf "$inputFile" "$outputDir" "${release_new}"
        if [ $? -eq 0 ]; then
            echo "Successful preprocessing of ChEBI data."
            echo "FAILED=false" >> $GITHUB_ENV
        else
            echo "Failed preprocessing of ChEBI data."
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi

        # EXACT COPY from original ChEBI workflow - RegEx and Diff test
        chmod +x datasources/chebi/config
        . datasources/chebi/config .
        old="datasources/chebi/data/$to_check_from_zenodo"
        new="datasources/chebi/recentData/$to_check_from_zenodo"
        wget -nc https://raw.githubusercontent.com/bridgedb/datasources/main/datasources.tsv
        CHEBI_ID=$(awk -F '\t' '$1 == "ChEBI" {print $10}' datasources.tsv)
        awk -F '\t' '{print $1}' $new > column1.txt
        awk -F '\t' '{print $2}' $new > column2.txt

        if ! grep -qvE "$CHEBI_ID" "column1.txt"; then
          echo "All lines in the primary column match the pattern."
        else
          echo "Error: At least one line in the primary column does not match pattern."
          grep -nvE "^$CHEBI_ID$" "column1.txt"
          echo "FAILED=true" >> $GITHUB_ENV
          exit 1
        fi

        if ! grep -qvE "$CHEBI_ID" "column1.txt"; then
          echo "All lines in the secondary column match the pattern."
        else
          echo "Error: At least one line in the secondary column does not match pattern."
          grep -nqvE "$CHEBI_ID" "column2.txt"
          echo "FAILED=true" >> $GITHUB_ENV
          exit 1
        fi

        cat "$old" | sort | tr -d "\r" > ids_old.txt
        cat "$new" | sort | tr -d "\r" > ids_new.txt
        echo "Performing diff between the sorted lists of IDs"
        output_file=diff.txt
        diff -u ids_old.txt ids_new.txt > $output_file || true
        added=$(grep '^+CHEBI' "$output_file" | sed 's/-//g') || true
        removed=$(grep '^-' "$output_file" | sed 's/-//g') || true
        added_filtered=$(comm -23 <(sort <<< "$added") <(sort <<< "$removed"))
        removed_filtered=$(comm -23 <(sort <<< "$removed") <(sort <<< "$added"))
        added=$added_filtered
        removed=$removed_filtered
        count_removed=$(printf "$removed" | wc -l) || true
        count_added=$(printf "$added" | wc -l) || true
        if [ -z "$removed" ]; then
         count_removed=0
         removed="None"
        fi
        if [ -z "$added" ]; then
         count_added=0
         added="None"
        fi
        echo "ADDED=$count_added" >> $GITHUB_ENV
        echo "REMOVED=$count_removed" >> $GITHUB_ENV
        count=$(expr $count_added + $count_removed) || true
        echo "COUNT=$count" >> $GITHUB_ENV
        total_old=$(cat "$old" | wc -l) || true 
        change=$((100 * count / total_old))
        echo "CHANGE=$change" >> $GITHUB_ENV

        rm -f chebi_index.html column1.txt column2.txt ids_old.txt ids_new.txt diff.txt
        ;;

    "ncbi")
        # EXACT COPY from original NCBI workflow - check_new_data job
        date_old=$(grep -E '^date=' datasources/ncbi/config | cut -d'=' -f2)
        echo 'Accessing the ncbi data'
        last_modified=$(curl -sI https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz | grep -i Last-Modified)
        date_new=$(echo $last_modified | cut -d':' -f2- | xargs -I {} date -d "{}" +%Y-%m-%d)
        echo "DATE_OLD=$date_old" >> $GITHUB_OUTPUT
        echo "DATE_NEW=$date_new" >> $GITHUB_OUTPUT
        echo "Date of latest release: $date_new", "Date of release of the current version: $date_old"

        # EXACT COPY from original NCBI workflow - test_new_data_processing job
        echo "$DATE_NEW=$DATE_NEW" >> $GITHUB_ENV
        mkdir -p datasources/ncbi/data
        wget https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz
        wget https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz
        mv gene_info.gz gene_history.gz datasources/ncbi/data
        ls -trlh datasources/ncbi/data

        cd java
        mvn clean install assembly:single
        cd ../
        sourceVersion=$DATE_NEW
        gene_history="datasources/ncbi/data/gene_history.gz"
        gene_info="datasources/ncbi/data/gene_info.gz"
        outputDir="datasources/ncbi/recentData/"
        mkdir -p "$outputDir"
        java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar \
            org.sec2pri.ncbi_txt "$sourceVersion" "$gene_history" "$gene_info" "$outputDir"
        
        ls -lh "$outputDir" || echo "Output directory missing"
        ls -lh "$outputDir/NCBI_secID2priID.tsv" || echo "Output file missing"
        if [ $? -eq 0 ]; then
            echo "Successful preprocessing of NCBI data."
            echo "FAILED=false" >> $GITHUB_ENV
        else
            echo "Failed preprocessing of NCBI data."
            echo "FAILED=true" >> $GITHUB_ENV
            exit 1
        fi

        # EXACT COPY from original NCBI workflow - Diff versions step
        to_check_from_zenodo=$(grep -E '^to_check_from_zenodo=' datasources/ncbi/config | cut -d'=' -f2)
        old="datasources/ncbi/data/$to_check_from_zenodo"
        new="datasources/ncbi/recentData/$to_check_from_zenodo"
        column_name="secondaryID"
        echo $column_name

        unzip -o datasources/ncbi/data/NCBI_secID2priID.zip -d datasources/ncbi/data/
        wget -nc https://raw.githubusercontent.com/bridgedb/datasources/main/datasources.tsv
        NCBI_ID=$(awk -F '\t' '$1 == "Entrez Gene" {print $10}' datasources.tsv)
        awk -F '\t' '{print $1}' $new > column1.txt
        awk -F '\t' '{print $2}' $new > column2.txt
                
        if ! grep -qvE "$NCBI_ID" "column1.txt"; then
          echo "All lines in the primary column match the pattern."
        else
          echo "Error: At least one line in the primary column does not match pattern."
          grep -nvE "^$NCBI_ID$" "column1.txt"
          echo "FAILED=true" >> $GITHUB_ENV
          exit 1
        fi
                
        if ! grep -qvE "$NCBI_ID" "column1.txt"; then
          echo "All lines in the secondary column match the pattern."
        else
          echo "Error: At least one line in the secondary column does not match pattern."
          grep -nqvE "$NCBI_ID" "column2.txt"
          echo "FAILED=true" >> $GITHUB_ENV
          exit 1
        fi

        cat "$old" | sort | tr -d "\r" | cut -f 1,3 > ids_old.txt
        cat "$new" | sort | tr -d "\r" | cut -f 1,3 > ids_new.txt

        echo "Performing diff between the sorted lists of IDs"
        output_file=diff.txt
        diff -u ids_old.txt ids_new.txt > $output_file || true
        added=$(grep '^+' "$output_file" | sed 's/+//g') || true
        removed=$(grep '^-' "$output_file" | sed 's/-//g') || true
        added_filtered=$(comm -23 <(sort <<< "$added") <(sort <<< "$removed"))
        removed_filtered=$(comm -23 <(sort <<< "$removed") <(sort <<< "$added"))
        added=$added_filtered
        removed=$removed_filtered
        count_removed=$(printf "$removed" | wc -l) || true
        count_added=$(printf "$added" | wc -l) || true

        if [ -z "$removed" ]; then
         count_removed=0
         removed="None"
        fi
        if [ -z "$added" ]; then
         count_added=0
         added="None"
        fi
        echo "ADDED=$count_added" >> $GITHUB_ENV
        echo "REMOVED=$count_removed" >> $GITHUB_ENV
        count=$(expr $count_added + $count_removed) || true
        echo "COUNT=$count" >> $GITHUB_ENV
        total_old=$(cat "$old" | wc -l) || true 
        change=$((100 * count / total_old))
        echo "CHANGE=$change" >> $GITHUB_ENV

        rm -f column1.txt column2.txt ids_old.txt ids_new.txt diff.txt
        ;;
        
    "hmdb")
        # Original HMDB logic with version checking
        date_old=$(grep -E '^date=' datasources/hmdb/config | cut -d'=' -f2)
        wget http://www.hmdb.ca/system/downloads/current/hmdb_metabolites.zip
        unzip hmdb_metabolites.zip
        date_new=$(head hmdb_metabolites.xml | grep 'update_date' | sed 's/.*>\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/')
        
        echo "DATE_OLD=$date_old" >> "$GITHUB_OUTPUT"
        echo "DATE_NEW=$date_new" >> "$GITHUB_OUTPUT"
        echo "DATE_NEW=$date_new" >> "$GITHUB_ENV"
        
        # Compare dates and set variable if date_new is more recent
        timestamp1=$(date -d "$date_new" +%s)
        timestamp2=$(date -d "$date_old" +%s)
        if [ "$timestamp1" -gt "$timestamp2" ]; then
            echo "New release available"
            echo "NEW_RELEASE=true" >> "$GITHUB_OUTPUT"
        else
            echo "No new release available"
            echo "NEW_RELEASE=false" >> "$GITHUB_OUTPUT"
            echo "COUNT=0" >> "$GITHUB_ENV"
            exit 0
        fi
        
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
            echo "Successful preprocessing of HMDB data."
            echo "FAILED=false" >> "$GITHUB_ENV"
        else
            echo "Failed preprocessing of HMDB data."
            echo "FAILED=true" >> "$GITHUB_ENV"
            exit 1
        fi
        
        # Compare versions with ID validation
        to_check_from_zenodo=$(grep -E '^to_check_from_zenodo=' datasources/hmdb/config | cut -d'=' -f2)
        old="datasources/hmdb/data/$to_check_from_zenodo"
        new="datasources/hmdb/recentData/$to_check_from_zenodo"
        
        # Save column headers before comparison
        save_column_headers "hmdb" "$new"
        
        # QC integrity of IDs (use headerless version)
        wget -nc https://raw.githubusercontent.com/bridgedb/datasources/main/datasources.tsv
        HMDB_ID=$(awk -F '\t' '$1 == "HMDB" {print $10}' datasources.tsv)
        
        # Split the file into two separate files for each column (skip header)
        tail -n +2 "$new" | awk -F '\t' '{print $1}' > column1.txt
        tail -n +2 "$new" | awk -F '\t' '{print $2}' > column2.txt

        # Use grep to check if any line in the primary column doesn't match the pattern
        if ! grep -qvE "$HMDB_ID" "column1.txt"; then
            echo "All lines in the primary column match the pattern."
        else
            echo "Error: At least one line in the primary column does not match pattern."
            grep -nvE "$HMDB_ID" "column1.txt"
            echo "FAILED=true" >> "$GITHUB_ENV"
            exit 1
        fi

        # Use grep to check if any line in the secondary column doesn't match the pattern
        if ! grep -qvE "$HMDB_ID" "column2.txt"; then
            echo "All lines in the secondary column match the pattern."
        else
            echo "Error: At least one line in the secondary column does not match pattern."
            grep -nvE "$HMDB_ID" "column2.txt"
            echo "FAILED=true" >> "$GITHUB_ENV"
            exit 1
        fi
        
        simple_diff "$old" "$new" "1,2"
        rm -f column1.txt column2.txt
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
        
        # Save column headers before comparison
        save_column_headers "hgnc" "$new"
        
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
        
        # Save column headers before comparison
        save_column_headers "uniprot" "$new"
        
        simple_diff "$old" "$new" "1,2"
        
        rm -f uniprot_index.html
        ;;
        
    *)
        echo "ERROR: Unknown datasource $DATASOURCE"
        exit 1
        ;;
esac
