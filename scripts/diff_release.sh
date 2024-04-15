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

# Read config variables
#. datasources/$source/config .
#chmod +x datasources/$source/config
#. datasources/$source/config .
to_check_from_zenodo=$(grep -E '^to_check_from_zenodo=' datasources/$source/config | cut -d'=' -f2)
old="datasources/$source/data/$to_check_from_zenodo"
new="datasources/$source/recentData/$to_check_from_zenodo"
# remove headers
sed -i '1d' "$new"
sed -i '1d' "$old"
# sort them
cat "$old" | sort | tr -d "\r" > ids_old.txt
cat "$new" | sort | tr -d "\r" > ids_new.txt
echo "Performing diff between the sorted lists of IDs"
# Perform a diff between the sorted lists of IDs
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


# Perform source-specific steps
case $source in
    "chebi" "hmdb" "ncbi")
    # qc integrity of IDs
    wget -nc https://raw.githubusercontent.com/bridgedb/datasources/main/datasources.tsv
    echo _________________________________________________
    echo "Quality control for IDs"
    wget -nc https://raw.githubusercontent.com/bridgedb/datasources/main/datasources.tsv
    $source_ID=$(awk -F '\t' '$1 == "$source" {print $10}' datasources.tsv)
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
        ;;
esac
