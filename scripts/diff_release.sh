#!/bin/bash
#
# Script: diff_release.sh
# Description: A script to get the differences between versions
# Author: Javier Millan Acosta
# Date: April 2024

# Check if the source argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <source> ($source | hgnc | hmdb | ncbi | uniprot)"
    exit 1
fi
source="$1"
file_to_check=$(grep -E '^to_check_from_zenodo=' datasources/$source/config | cut -d'=' -f2)
file_to_check_zip="${file_to_check%.zip}.tsv"
# Unzip
if [[ $source == "uniprot" || $source == "ncbi" ]]; then
    unzip datasources/$source/data/$file_to_check_zip -d datasources/$source/data/
fi

# Read config variables
#. datasources/$source/config .
#chmod +x datasources/$source/config
#. datasources/$source/config .

old="datasources/$source/data/$file_to_check"
new="datasources/$source/recentData/$file_to_check"

# Check if the old file exists
if [ -f "$old" ]; then
    # Print the size of the old file
    du -sh "$old"
else
    echo "$old does not exist."
fi

# Check if the new file exists
if [ -f "$new" ]; then
    # Print the size of the new file
    du -sh "$new"
else
    echo "$new does not exist."
fi

# remove headers
sed -i '1d' "$new"
sed -i '1d' "$old"
# sort the ids
cat "$old" | sort | tr -d "\r" > ids_old.txt
cat "$new" | sort | tr -d "\r" > ids_new.txt

# Perform a diff between the sorted lists of IDs
echo "Performing diff between the sorted lists of IDs"
output_file=diff.txt
diff -u ids_old.txt ids_new.txt > $output_file || true
# retrieve new lines
added=$(grep '^+$source' "$output_file" | sed 's/-//g') || true
# retrieve removed lines
removed=$(grep '^-' "$output_file" | sed 's/-//g') || true
added_filtered=$(comm -23 <(sort <<< "$added") <(sort <<< "$removed"))
removed_filtered=$(comm -23 <(sort <<< "$removed") <(sort <<< "$added"))
added=$added_filtered
removed=$removed_filtered
# count them
count_removed=$(printf "$removed" | wc -l) || true
count_added=$(printf "$added" | wc -l) || true
# make sure we are not counting empty lines
if [ -z "$removed" ]; then
 count_removed=0
 removed="None"
fi
if [ -z "$added" ]; then
 count_added=0
 added="None"
fi

echo ________________________________________________
echo "                 removed pairs                    "
echo ________________________________________________
echo "$removed"
echo ________________________________________________
echo "                 added pairs                    "
echo ________________________________________________
echo "$added"
echo _________________________________________________
echo "What's changed:"
echo "- Added id pairs: $count_added"
echo "- Removed id pairs: $count_removed"
# Store to env to use in issue
echo "ADDED=$count_added" >> $GITHUB_ENV
echo "REMOVED=$count_removed" >> $GITHUB_ENV
count=$(expr $count_added + $count_removed) || true
echo "COUNT=$count" >> $GITHUB_ENV
total_old=$(cat "$old" | wc -l) || true 
change=$((100 * count / total_old))
echo "CHANGE=$change" >> $GITHUB_ENV 


# Perform id regex QC when applicable

case $source in
    "hmdb")
        source_ID=$(awk -F '\t' '$1 == "HMDB" {print $10}' datasources.tsv)
    ;;
    "chebi")
        source_ID=$(awk -F '\t' '$1 == "ChEBI" {print $10}' datasources.tsv)
    ;;
    "ncbi")
        source_ID=$(awk -F '\t' '$1 == "Entrez Gene" {print $10}' datasources.tsv)
    "hgnc" | "uniprot") # No QC set up for these sources
        exit 0
    ;;
esac

wget https://raw.githubusercontent.com/bridgedb/datasources/main/datasources.tsv
# Split the file into two separate files for each column
awk -F '\t' '{print $1}' $new > column1.txt
awk -F '\t' '{print $2}' $new > column2.txt
                  
# Use grep to check if any line in the primary column doesn't match the pattern
if grep -nqvE "$source_ID" "column1.txt"; then
    echo "All lines in the primary column match the pattern."
else
    echo "Error: At least one line in the primary column does not match pattern."
    grep -nvE "^$source_ID$" "column1.txt"
    echo "FAILED=true" >> $GITHUB_ENV
    exit 1
fi
                  
# Use grep to check if any line in the secondary column doesn't match the pattern
if grep -nqvE "$source_ID" "column1.txt"; then
    echo "All lines in the secondary column match the pattern."
            
else
    echo "Error: At least one line in the secondary column does not match pattern."
    grep -nqvE "$source_ID" "column2.txt"
    echo "FAILED=true" >> $GITHUB_ENV
    exit 1
fi
