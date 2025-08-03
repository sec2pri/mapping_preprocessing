#!/bin/bash

# Common diff analysis script for mapping preprocessing workflows
# Usage: ./diff_analysis.sh <datasource> <old_file> <new_file> [columns_to_compare]

set -e

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly DATASOURCES_URL="https://raw.githubusercontent.com/bridgedb/datasources/main/datasources.tsv"

# Input parameters
DATASOURCE="$1"
OLD_FILE="$2"
NEW_FILE="$3"
COLUMNS="${4:-1,2}"  # Default to columns 1,2

echo "Starting diff analysis for $DATASOURCE"

# Datasource configuration
declare -A DATASOURCE_CONFIG=(
    # [datasource]="id_pattern_name:default_columns:validation_columns"
    ["chebi"]="ChEBI:1,2:1,2"
    ["ncbi"]="Entrez Gene:1,3:1,2"
    ["hmdb"]="HMDB:1,2:1,2"
    ["hgnc"]="HGNC:1,3:1,2"
    ["uniprot"]="UniProt:1,2:"  # No validation for UniProt
)

# Function to get datasource configuration
get_datasource_config() {
    local datasource="$1"
    local key="$2"
    local config="${DATASOURCE_CONFIG[$datasource]}"
    
    if [ -z "$config" ]; then
        echo "Warning: Unknown datasource $datasource, using defaults" >&2
        case "$key" in
            "pattern_name") echo "" ;;
            "columns") echo "1,2" ;;
            "validation_cols") echo "1,2" ;;
        esac
        return
    fi
    
    IFS=':' read -r pattern_name default_cols validation_cols <<< "$config"
    
    case "$key" in
        "pattern_name") echo "$pattern_name" ;;
        "columns") echo "${COLUMNS:-$default_cols}" ;;
        "validation_cols") echo "$validation_cols" ;;
    esac
}

# Function to download and cache datasources.tsv
get_id_pattern() {
    local datasource="$1"
    local pattern_name
    pattern_name=$(get_datasource_config "$datasource" "pattern_name")
    
    if [ -z "$pattern_name" ]; then
        return 0
    fi
    
    # Download datasources.tsv if not exists or is old
    local datasources_file="datasources.tsv"
    if [ ! -f "$datasources_file" ] || [ $(find "$datasources_file" -mmin +60 2>/dev/null | wc -l) -gt 0 ]; then
        if command -v wget >/dev/null 2>&1; then
            wget -q "$DATASOURCES_URL" -O "$datasources_file" 2>/dev/null || true
        fi
    fi
    
    if [ -f "$datasources_file" ]; then
        awk -F '\t' -v name="$pattern_name" '$1 == name {print $10}' "$datasources_file"
    fi
}

# Function to validate ID patterns
validate_ids() {
    local file="$1"
    local pattern="$2"
    local datasource="$3"
    local validation_cols
    validation_cols=$(get_datasource_config "$datasource" "validation_cols")
    
    if [ -z "$pattern" ] || [ -z "$validation_cols" ]; then
        echo "Skipping ID validation for $datasource"
        return 0
    fi
    
    echo "Validating ID patterns for $datasource..."
    
    # Convert comma-separated columns to array
    IFS=',' read -ra cols <<< "$validation_cols"
    
    local validation_failed=false
    for col in "${cols[@]}"; do
        local temp_file="temp_col${col}.txt"
        awk -F '\t' "{print \$$col}" "$file" > "$temp_file"
        
        if ! grep -qvE "$pattern" "$temp_file"; then
            echo "✓ All IDs in column $col match the expected pattern"
        else
            echo "✗ Error: Some IDs in column $col do not match pattern $pattern"
            echo "First 5 non-matching entries:"
            grep -nvE "$pattern" "$temp_file" | head -5
            validation_failed=true
        fi
        rm -f "$temp_file"
    done
    
    if [ "$validation_failed" = true ]; then
        echo "FAILED=true" >> "$GITHUB_ENV"
        exit 1
    fi
}

# Function to safely count lines
safe_line_count() {
    local content="$1"
    if [ -z "$content" ]; then
        echo 0
    else
        echo "$content" | grep -c '^' || echo 0
    fi
}

# Function to perform diff analysis
perform_diff() {
    local old="$1"
    local new="$2"
    local cols="$3"
    
    echo "Extracting and sorting data (columns: $cols)..."
    cut -f "$cols" "$old" | sort | tr -d "\r" > ids_old.txt
    cut -f "$cols" "$new" | sort | tr -d "\r" > ids_new.txt
    
    echo "Performing diff analysis..."
    
    # Use comm for clean diff without headers
    local added removed
    added=$(comm -13 ids_old.txt ids_new.txt)
    removed=$(comm -23 ids_old.txt ids_new.txt)
    
    # Count changes reliably
    local count_added count_removed
    count_added=$(safe_line_count "$added")
    count_removed=$(safe_line_count "$removed")
    
    # Handle empty results for display
    local added_display removed_display
    added_display="${added:-None}"
    removed_display="${removed:-None}"
    
    # Output results
    echo "================================================"
    echo "                 REMOVED PAIRS                   "
    echo "================================================"
    echo "$removed_display"
    echo "================================================"
    echo "                 ADDED PAIRS                     "
    echo "================================================"
    echo "$added_display"
    echo "================================================"
    echo "SUMMARY:"
    echo "- Added pairs: $count_added"
    echo "- Removed pairs: $count_removed"
    
    # Calculate totals and percentage
    local total_changes total_old change_percent
    total_changes=$((count_added + count_removed))
    total_old=$(wc -l < "$old")
    change_percent=0
    
    if [ "$total_old" -gt 0 ]; then
        change_percent=$((100 * total_changes / total_old))
    fi
    
    echo "- Total old pairs: $total_old"
    echo "- Total changes: $total_changes"
    echo "- Change percentage: ${change_percent}%"
    
    # Export to environment for GitHub Actions
    if [ -n "$GITHUB_ENV" ]; then
        {
            echo "ADDED=$count_added"
            echo "REMOVED=$count_removed"
            echo "COUNT=$total_changes"
            echo "CHANGE=$change_percent"
        } >> "$GITHUB_ENV"
    fi
    
    # Cleanup
    rm -f ids_old.txt ids_new.txt
    
    echo "Diff analysis completed successfully"
}

# Main execution
main() {
    # Validate inputs
    if [ $# -lt 3 ]; then
        echo "Usage: $0 <datasource> <old_file> <new_file> [columns_to_compare]"
        exit 1
    fi
    
    # Validate input files exist
    if [ ! -f "$OLD_FILE" ]; then
        echo "Error: Old file $OLD_FILE not found"
        exit 1
    fi
    
    if [ ! -f "$NEW_FILE" ]; then
        echo "Error: New file $NEW_FILE not found"
        exit 1
    fi
    
    # Get datasource-specific configuration
    local datasource_lower
    datasource_lower=$(echo "$DATASOURCE" | tr '[:upper:]' '[:lower:]')
    COLUMNS=$(get_datasource_config "$datasource_lower" "columns")
    
    echo "Using columns: $COLUMNS for $DATASOURCE"
    
    # Get ID pattern and validate if applicable
    local id_pattern
    id_pattern=$(get_id_pattern "$datasource_lower")
    
    if [ -n "$id_pattern" ]; then
        echo "Found ID pattern for $DATASOURCE: $id_pattern"
        validate_ids "$NEW_FILE" "$id_pattern" "$datasource_lower"
    else
        echo "No ID pattern validation for $DATASOURCE"
    fi
    
    # Perform diff analysis
    perform_diff "$OLD_FILE" "$NEW_FILE" "$COLUMNS"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
