#!/bin/bash
set -e

DATASOURCE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
source "$SCRIPT_DIR/datasource_config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

main() {
    log "Starting processing for $DATASOURCE"
    
    # Get configuration for this datasource
    local config_key="${DATASOURCE}_CONFIG"
    if [[ -z "${!config_key}" ]]; then
        log "ERROR: No configuration found for $DATASOURCE"
        exit 1
    fi
    
    # Parse configuration
    local config="${!config_key}"
    IFS='|' read -r date_func download_func process_func env_func columns pattern <<< "$config"
    
    # 1. Check dates
    log "Checking dates for $DATASOURCE"
    eval "$date_func"
    
    # 2. Setup environment
    log "Setting up environment for $DATASOURCE"
    eval "$env_func"
    
    # 3. Download data
    log "Downloading data for $DATASOURCE"
    eval "$download_func"
    
    # 4. Process data
    log "Processing data for $DATASOURCE"
    if eval "$process_func"; then
        echo "FAILED=false" >> "$GITHUB_ENV"
    else
        echo "FAILED=true" >> "$GITHUB_ENV"
        log "ERROR: Processing failed for $DATASOURCE"
        return 1
    fi
    
    # 5. Compare versions
    log "Comparing versions for $DATASOURCE"
    compare_versions "$DATASOURCE" "$columns"
    
    log "Completed processing for $DATASOURCE"
}

compare_versions() {
    local datasource="$1"
    local columns="$2"
    
    local to_check_from_zenodo
    to_check_from_zenodo=$(grep -E '^to_check_from_zenodo=' "datasources/$datasource/config" | cut -d'=' -f2)
    
    local old="datasources/$datasource/data/$to_check_from_zenodo"
    local new="datasources/$datasource/recentData/$to_check_from_zenodo"
    
    # Unzip archived files if they exist
    find "datasources/$datasource/data" -name "*.zip" -exec unzip -o {} -d "datasources/$datasource/data/" \; 2>/dev/null || true
    
    # Use simple diff analysis
    chmod +x "$SCRIPT_DIR/simple_diff.sh"
    "$SCRIPT_DIR/simple_diff.sh" "$datasource" "$old" "$new" "$columns"
}

main "$@"
