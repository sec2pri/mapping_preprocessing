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

source "$CONFIG_FILE"

check_new_data() {
    case "$DATASOURCE" in
        chebi)
            wget -q http://ftp.ebi.ac.uk/pub/databases/chebi/archive/ -O archive_index.html
            DATE_NEW=$(tail -4 archive_index.html | head -1 | grep -oP '<td align="right">\K[0-9-]+\s[0-9:]+(?=\s+</td>)' | awk '{print $1}')
            RELEASE_NUMBER=$(tail -4 archive_index.html | head -1 | grep -oP '(?<=a href="rel)\d\d\d')
            rm archive_index.html
            
            if [[ $(date -d "$DATE_NEW" +%s) -gt $(date -d "$date" +%s) ]]; then
                for i in {1..5}; do
                    if curl -s -f "http://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel${RELEASE_NUMBER}/SDF/ChEBI_complete_3star.sdf.gz" > /dev/null; then
                        echo "NEW_RELEASE=true" >> $GITHUB_ENV
                        break
                    fi
                    [[ $i -eq 5 ]] && echo "ISSUE=true" >> $GITHUB_ENV && return 1
                    sleep 60
                done
            fi
            ;;
        uniprot)
            wget -q https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/ -O uniprot_index.html
            DATE_NEW=$(grep -oP 'uniprot_sprot\.fasta\.gz</a></td><td[^>]*>\K[0-9]{4}-[0-9]{2}-[0-9]{2}' uniprot_index.html)
            rm uniprot_index.html
            ;;
        ncbi)
            LAST_MODIFIED=$(curl -sI https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz | grep -i Last-Modified)
            DATE_NEW=$(echo $LAST_MODIFIED | cut -d':' -f2- | xargs -I {} date -d "{}" +%Y-%m-%d)
            ;;
        hmdb)
            wget -q http://www.hmdb.ca/system/downloads/current/hmdb_metabolites.zip
            unzip -q hmdb_metabolites.zip
            DATE_NEW=$(head hmdb_metabolites.xml | grep 'update_date' | sed 's/.*>\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/')
            rm hmdb_metabolites.xml hmdb_metabolites.zip
            ;;
        hgnc)
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
            echo "COMPLETE_NEW=$COMPLETE_NEW" >> $GITHUB_ENV
            echo "WITHDRAWN_NEW=$WITHDRAWN_NEW" >> $GITHUB_ENV
            ;;
    esac
    
    echo "DATE_NEW=$DATE_NEW" >> $GITHUB_ENV
    echo "DATE_OLD=$date" >> $GITHUB_ENV
}

download_data() {
    mkdir -p "datasources/$DATASOURCE/data"
    
    case "$DATASOURCE" in
        chebi)
            wget -q "http://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel${RELEASE_NUMBER}/SDF/ChEBI_complete_3star.sdf.gz"
            gunzip ChEBI_complete_3star.sdf.gz
            ;;
        uniprot)
            cd "datasources/$DATASOURCE/data"
            wget -q https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz
            wget -q https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/sec_ac.txt
            wget -q https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/delac_sp.txt
            cd - > /dev/null
            ;;
        ncbi)
            cd "datasources/$DATASOURCE/data"
            wget -q https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz
            wget -q https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz
            cd - > /dev/null
            ;;
        hmdb)
            wget -q http://www.hmdb.ca/system/downloads/current/hmdb_metabolites.zip
            unzip -q hmdb_metabolites.zip
            mkdir hmdb
            mv hmdb_metabolites.xml hmdb
            cd hmdb
            xml_split -v -l 1 hmdb_metabolites.xml
            rm hmdb_metabolites.xml
            cd ..
            zip -rq hmdb_metabolites_split.zip hmdb
            rm -rf hmdb
            ;;
        hgnc)
            cd "datasources/$DATASOURCE/data"
            wget -q "https://storage.googleapis.com/public-download-files/hgnc/archive/archive/quarterly/tsv/${WITHDRAWN_NEW}"
            wget -q "https://storage.googleapis.com/public-download-files/hgnc/archive/archive/quarterly/tsv/${COMPLETE_NEW}"
            cd - > /dev/null
            ;;
    esac
}

process_data() {
    mkdir -p "datasources/$DATASOURCE/recentData"
    
    case "$DATASOURCE" in
        chebi)
            cd java && mvn -q clean install assembly:single && cd ..
            java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar org.sec2pri.chebi_sdf "ChEBI_complete_3star.sdf" "datasources/$DATASOURCE/recentData/" "${RELEASE_NUMBER}"
            ;;
        uniprot)
            Rscript r/src/uniprot.R "$DATE_NEW" "datasources/$DATASOURCE/data/uniprot_sprot.fasta.gz" "datasources/$DATASOURCE/data/delac_sp.txt" "datasources/$DATASOURCE/data/sec_ac.txt"
            ;;
        ncbi)
            cd java && mvn -q clean install assembly:single && cd ..
            java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar org.sec2pri.ncbi_txt "$DATE_NEW" "datasources/$DATASOURCE/data/gene_history.gz" "datasources/$DATASOURCE/data/gene_info.gz" "datasources/$DATASOURCE/recentData/"
            ;;
        hmdb)
            cd java && mvn -q clean install assembly:single && cd ..
            java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar org.sec2pri.hmdb_xml "hmdb_metabolites_split.zip" "datasources/$DATASOURCE/recentData/"
            ;;
        hgnc)
            Rscript r/src/hgnc.R "$DATE_NEW" "datasources/$DATASOURCE/data/${WITHDRAWN_NEW}" "datasources/$DATASOURCE/data/${COMPLETE_NEW}"
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        echo "FAILED=false" >> $GITHUB_ENV
    else
        echo "FAILED=true" >> $GITHUB_ENV
        exit 1
    fi
}

validate_and_diff() {
    OLD_FILE="datasources/$DATASOURCE/data/$to_check_from_zenodo"
    NEW_FILE="datasources/$DATASOURCE/recentData/$to_check_from_zenodo"
    
    case "$DATASOURCE" in
        uniprot)
            unzip -q "datasources/$DATASOURCE/data/UniProt_secID2priID.zip" -d "datasources/$DATASOURCE/data/"
            cut -f1,2 "$OLD_FILE" | sort > old_sorted.txt
            cut -f1,2 "$NEW_FILE" | sort > new_sorted.txt
            ;;
        ncbi)
            unzip -oq "datasources/$DATASOURCE/data/NCBI_secID2priID.zip" -d "datasources/$DATASOURCE/data/"
            cut -f1,3 "$OLD_FILE" | sort > old_sorted.txt
            cut -f1,3 "$NEW_FILE" | sort > new_sorted.txt
            ;;
        hgnc)
            cut -f1,3 "$OLD_FILE" | sort > old_sorted.txt
            cut -f1,3 "$NEW_FILE" | sort > new_sorted.txt
            ;;
        *)
            sort "$OLD_FILE" > old_sorted.txt
            sort "$NEW_FILE" > new_sorted.txt
            ;;
    esac
    
    if [[ "$DATASOURCE" =~ ^(chebi|ncbi|hmdb)$ ]]; then
        wget -qc https://raw.githubusercontent.com/bridgedb/datasources/main/datasources.tsv
        case "$DATASOURCE" in
            chebi) PATTERN=$(awk -F '\t' '$1 == "ChEBI" {print $10}' datasources.tsv) ;;
            ncbi) PATTERN=$(awk -F '\t' '$1 == "Entrez Gene" {print $10}' datasources.tsv) ;;
            hmdb) PATTERN=$(awk -F '\t' '$1 == "HMDB" {print $10}' datasources.tsv) ;;
        esac
        
        awk -F '\t' '{print $1}' "$NEW_FILE" | grep -qvE "$PATTERN" && echo "FAILED=true" >> $GITHUB_ENV && exit 1
        awk -F '\t' '{print $2}' "$NEW_FILE" | grep -qvE "$PATTERN" && echo "FAILED=true" >> $GITHUB_ENV && exit 1
    fi
    
    ADDED=$(comm -13 old_sorted.txt new_sorted.txt | wc -l)
    REMOVED=$(comm -23 old_sorted.txt new_sorted.txt | wc -l)
    COUNT=$((ADDED + REMOVED))
    
    echo "ADDED=$ADDED" >> $GITHUB_ENV
    echo "REMOVED=$REMOVED" >> $GITHUB_ENV
    echo "COUNT=$COUNT" >> $GITHUB_ENV
    
    if [[ $COUNT -gt 0 ]]; then
        TOTAL_OLD=$(wc -l < old_sorted.txt)
        CHANGE=$((100 * COUNT / TOTAL_OLD))
        echo "CHANGE=$CHANGE" >> $GITHUB_ENV
    fi
    
    rm -f old_sorted.txt new_sorted.txt datasources.tsv
}

check_new_data

if [[ "$DATASOURCE" == "chebi" && "$NEW_RELEASE" != "true" ]]; then
    echo "No new ChEBI release available"
    exit 0
fi

download_data
process_data
validate_and_diff

echo "Processing completed for $DATASOURCE"
