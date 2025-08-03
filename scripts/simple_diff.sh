#!/bin/bash
set -e

DATASOURCE="$1"
OLD_FILE="$2"
NEW_FILE="$3"
COLUMNS="${4:-1,2}"

if [ ! -f "$OLD_FILE" ] || [ ! -f "$NEW_FILE" ]; then
    echo "Files not found, skipping comparison"
    echo "COUNT=0" >> "$GITHUB_ENV"
    exit 0
fi

# Extract and sort data
cut -f "$COLUMNS" "$OLD_FILE" | sort | tr -d "\r" > ids_old.txt
cut -f "$COLUMNS" "$NEW_FILE" | sort | tr -d "\r" > ids_new.txt

# Get differences
added=$(comm -13 ids_old.txt ids_new.txt)
removed=$(comm -23 ids_old.txt ids_new.txt)

# Count changes
count_added=$(echo "$added" | grep -c '^' || echo 0)
count_removed=$(echo "$removed" | grep -c '^' || echo 0)

if [ -z "$added" ]; then count_added=0; added="None"; fi
if [ -z "$removed" ]; then count_removed=0; removed="None"; fi

echo "=== CHANGES FOR $DATASOURCE ==="
echo "Added: $count_added"
echo "Removed: $count_removed"

# Export results
total_changes=$((count_added + count_removed))
total_old=$(wc -l < "$OLD_FILE")
change_percent=$((total_old > 0 ? 100 * total_changes / total_old : 0))

{
    echo "ADDED=$count_added"
    echo "REMOVED=$count_removed"
    echo "COUNT=$total_changes"
    echo "CHANGE=$change_percent"
} >> "$GITHUB_ENV"

# Cleanup
rm -f ids_old.txt ids_new.txt
