#!/bin/bash
#
# Script: test_new_release.sh
# Description: A script to test the data sources 
# Author: Javier Millan Acosta
# Date: April 2024

# Check if source argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <source> (chebi | hgnc | hmdb | ncbi | uniprot)" >&2
    exit 1
fi

source="$1"

# Read config variables
source_config="datasources/$source/config"
if [ ! -f "$source_config" ]; then
    echo "Error: Config file not found for $source" >&2
    exit 1
fi

source_config_vars=$(source "$source_config")

# Access the source to retrieve the latest release date
echo "Accessing the $source archive"
case $source in
    "chebi")
          echo "$DATE_NEW=$DATE_NEW" >> $GITHUB_ENV
          ##Download ChEBI SDF file
          echo $RELEASE_NUMBER
          # Store outputs from previous job in environment variables
          echo "RELEASE_NUMBER=$RELEASE_NUMBER" >> $GITHUB_ENV
          echo "CURRENT_RELEASE_NUMBER=$CURRENT_RELEASE_NUMBER" >> $GITHUB_ENV
          url_release="https://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel$RELEASE_NUMBER/SDF/"
          echo "URL_RELEASE=$url_release" >> $GITHUB_ENV
          wget -q "https://ftp.ebi.ac.uk/pub/databases/chebi/archive/rel${RELEASE_NUMBER}/SDF/ChEBI_complete_3star.sdf.gz"
          ##Unzip gz file:
          gunzip --quiet ChEBI_complete_3star.sdf.gz #TODO replace by config var
          ##Check file size if available
          ls
          ##Print file size
          # Set up vars from config file
          chmod +x datasources/chebi/config
          . datasources/chebi/config .
          ##Create temp. folder to store the data in
          mkdir -p mapping_preprocessing/datasources/chebi/data
          java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar org.sec2pri.chebi_sdf "$inputFile" "$outputDir"
        ;;
    "hgnc")
          ##Store outputs from previous job in environment variables
          echo "$DATE_NEW=$DATE_NEW" >> $GITHUB_ENV
          echo "$COMPLETE_NEW=$COMPLETE_NEW" >> $GITHUB_ENV
          echo "$WITHDRAWN_NEW=$WITHDRAWN_NEW" >> $GITHUB_ENV
          ##Create temp. folder to store the data in
          mkdir -p datasources/hgnc/data
          ##Download hgnc file
          wget -q https://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/archive/quarterly/tsv/${WITHDRAWN_NEW}
          wget -q https://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/archive/quarterly/tsv/${COMPLETE_NEW}
          mv $WITHDRAWN_NEW $COMPLETE_NEW datasources/hgnc/data
          ##Check file size if available
          ls -trlh datasources/hgnc/data
          sourceVersion=$DATE_NEW
          complete="datasources/hgnc/data/${COMPLETE_NEW}" 
          withdrawn="datasources/hgnc/data/${WITHDRAWN_NEW}"   
          Rscript r/src/hgnc.R $sourceVersion $withdrawn $complete
        ;;
    "hmdb")
          sudo apt-get install xml-twig-tools
          ##Store outputs from previous job in environment variables
          echo "$DATE_NEW=$DATE_NEW" >> $GITHUB_ENV
          ##Download hmdb file
          wget -q http://www.hmdb.ca/system/downloads/current/hmdb_metabolites.zip
          unzip hmdb_metabolites.zip
          mkdir hmdb
          mv hmdb_metabolites.xml hmdb
          cd hmdb
          xml_split -v -l 1 hmdb_metabolites.xml
          rm hmdb_metabolites.xml
          cd ../
          zip -r hmdb_metabolites_split.zip hmdb
          # Set up vars from config file
          to_check_from_zenodo=$(grep -E '^to_check_from_zenodo=' datasources/hmdb/config | cut -d'=' -f2)
          inputFile=hmdb_metabolites_split.zip
          mkdir datasources/hmdb/recentData/
          outputDir="datasources/hmdb/recentData/"
          java -cp java/target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar org.sec2pri.hmdb_xml "$inputFile" "$outputDir"
        ;;
    "uniprot")
          ##Store outputs from previous job in environment variables
          echo "$DATE_NEW=$DATE_NEW" >> $GITHUB_ENV
          ##Define files to be downloaded
          UNIPROT_SPROT_NEW=$(echo uniprot_sprot.fasta.gz)
          SEC_AC_NEW=$(echo sec_ac.txt)
          DELAC_SP_NEW=$(echo delac_sp.txt)
          ##Create temp. folder to store the data in
          mkdir -p datasources/uniprot/data
          ##Download uniprot file
          wget -q https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/${UNIPROT_SPROT_NEW}
          wget -q https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/${SEC_AC_NEW}
          wget -q https://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/docs/${DELAC_SP_NEW}
          mv $DELAC_SP_NEW $SEC_AC_NEW $UNIPROT_SPROT_NEW datasources/uniprot/data
          ##Check file size if available
          ls -trlh datasources/uniprot/data
          sourceVersion=$DATE_NEW
          uniprot_sprot=$(echo datasources/uniprot/data/uniprot_sprot.fasta.gz)
          sec_ac=$(echo datasources/uniprot/data/sec_ac.txt)
          delac_sp=$(echo datasources/uniprot/data/delac_sp.txt)
          Rscript r/src/uniprot.R $sourceVersion $uniprot_sprot $delac_sp $sec_ac 
        ;;
    "ncbi")
          ##Store outputs from previous job in environment variables
          echo "$DATE_NEW=$DATE_NEW" >> $GITHUB_ENV
          echo $DATE_NEW
          ##Create temp. folder to store the data in
          mkdir -p datasources/ncbi/data
          ##Download ncbi file
          wget -q https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz
          wget -q https://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz
          mv gene_info.gz gene_history.gz datasources/ncbi/data
          ##Check file size if available
          ls -trlh datasources/ncbi/data
          sourceVersion=$DATE_NEW
          gene_history="data/gene_history.gz" 
          gene_info="data/gene_info.gz"
          Rscript r/src/ncbi.R $sourceVersion $gene_history $gene_info
        ;;
    *)
        echo "Error: Invalid source: $source" >&2
        echo "Usage: $0 <source> (chebi | hgnc | hmdb | ncbi | uniprot)" >&2
        exit 1
        ;;
esac

# Check the exit status of the processing programs
if [ $? -eq 0 ]; then
    echo "Successful preprocessing of $source data."
    echo "FAILED=false" >> $GITHUB_ENV
else
    echo "Failed preprocessing of $source data."
    echo "FAILED=true" >> $GITHUB_ENV
fi
