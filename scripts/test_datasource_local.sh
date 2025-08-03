#!/bin/bash

# Test script for local development
# Usage: ./test_datasource_local.sh <datasource>

DATASOURCE="$1"

if [ -z "$DATASOURCE" ]; then
    echo "Usage: $0 <datasource>"
    echo "Available datasources: chebi ncbi hmdb uniprot hgnc"
    exit 1
fi

# Create mock GitHub environment
export GITHUB_ENV="test_env_vars.txt"
export GITHUB_OUTPUT="test_output_vars.txt"

# Clean up old files
rm -f "$GITHUB_ENV" "$GITHUB_OUTPUT"
touch "$GITHUB_ENV" "$GITHUB_OUTPUT"

echo "=== Testing $DATASOURCE locally ==="

# Check if required tools are available
case "$DATASOURCE" in
    "chebi"|"ncbi"|"hmdb")
        if ! command -v java &> /dev/null; then
            echo "ERROR: Java not found. Install Java 11+ for $DATASOURCE"
            exit 1
        fi
        if ! command -v mvn &> /dev/null; then
            echo "ERROR: Maven not found. Install Maven for $DATASOURCE"
            exit 1
        fi
        ;;
    "uniprot"|"hgnc")
        if ! command -v Rscript &> /dev/null; then
            echo "ERROR: R not found. Install R for $DATASOURCE"
            exit 1
        fi
        ;;
esac

if [ "$DATASOURCE" = "hgnc" ]; then
    if ! command -v node &> /dev/null; then
        echo "ERROR: Node.js not found. Install Node.js for HGNC"
        exit 1
    fi
    if ! npm list puppeteer &> /dev/null; then
        echo "ERROR: Puppeteer not found. Run 'npm install puppeteer' for HGNC"
        exit 1
    fi
fi

if [ "$DATASOURCE" = "hmdb" ]; then
    if ! command -v xml_split &> /dev/null; then
        echo "ERROR: xml-twig-tools not found. Install xml-twig-tools for HMDB"
        exit 1
    fi
fi

# Run the processing script
echo "Running process_datasource.sh for $DATASOURCE..."
chmod +x scripts/process_datasource.sh

if ./scripts/process_datasource.sh "$DATASOURCE"; then
    echo "=== SUCCESS ==="
    echo "Environment variables set:"
    cat "$GITHUB_ENV"
    echo "Output variables:"
    cat "$GITHUB_OUTPUT"
    
    echo "=== Generated files ==="
    ls -la datasources/$DATASOURCE/recentData/ 2>/dev/null || echo "No output files found"
    
else
    echo "=== FAILED ==="
    echo "Check the error messages above"
fi

# Cleanup
rm -f test_env_vars.txt test_output_vars.txt
