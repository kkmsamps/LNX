#!/bin/bash
set -euo pipefail

# --- Funktion för att visa hjälp/användarinstruktioner ---
usage() {
    echo "Usage: $0 [-h] <path_to_source_code_directory>"
    echo "Checks and downloads/updates source code archives based on packages.conf."
    echo
    echo "Flags:"
    echo "  -h  Show this help text and exit."
    exit 0
}

# --- Hantera kommandoradsflaggor och argument ---
while getopts "h" opt; do
    case ${opt} in
        h) usage ;;
        \?) echo "Invalid flag: -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $((OPTIND -1))

if [ $# -eq 0 ]; then
    echo "Error: No path to source code directory provided." >&2
    echo ""
    usage
fi

# --- Konfiguration ---
readonly SOURCE_DIR="$1"
readonly CONFIG_FILE="packages.conf"
readonly C_BLUE='\033[0;34m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_RED='\033[0;31m'
readonly C_RESET='\033[0m'

# --- Loggfunktioner ---
log_info() { echo -e "${C_BLUE}[INFO]${C_RESET} $1"; }
log_success() { echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"; }
log_warn() { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }
log_error() { echo -e "${C_RED}[ERROR]${C_RESET} $1" >&2; }

# --- Hjälpfunktioner ---

extract_version() {
    local string="$1"
    echo "$string" | grep -oE '([0-9]+[._-])+[0-9a-zA-Z._-]*' | sed -E 's/(\.tar\.(gz|bz2|xz))|(\.zip)$//' | head -n1 || echo ""
}

# --- Kärnfunktioner (Nu fullt implementerade) ---

handle_pinned_package() {
    local name="$1"
    local url="$2"
    
    log_info "--- Checking (PINNED): $name ---"
    local filename
    filename=$(basename "$url")

    if [ -f "$SOURCE_DIR/$filename" ]; then
        log_success "Pinned version already exists: $filename"
    else
        log_warn "Pinned version is missing. Downloading: $filename"
        log_info "From: $url"
        if ! wget -P "$SOURCE_DIR" "$url"; then
            log_error "Download of $name failed."
            return 1
        fi
        log_success "Download complete."
    fi
}

handle_git_package() {
    local name="$1"
    local repo_url="$2"

    log_info "--- Checking (GIT): $name ---"
    local target_dir="$SOURCE_DIR/$name"

    if [ -d "$target_dir/.git" ]; then
        log_info "Repository '$name' already exists. Checking for updates..."
        (
            cd "$target_dir"
            if ! git fetch; then log_warn "Could not fetch updates for '$name'. Skipping."; return; fi
            local local_commit
            local remote_commit
            local_commit=$(git rev-parse HEAD)
            remote_commit=$(git rev-parse '@{u}')
            if [ "$local_commit" = "$remote_commit" ]; then
                log_success "Repository is up-to-date."
            else
                log_warn "New commits available for '$name'. Consider running 'git pull' in '$target_dir'."
            fi
        )
    else
        log_warn "Repository '$name' not found. Cloning from source."
        log_info "Cloning from: $repo_url"
        if git clone "$repo_url" "$target_dir"; then
            log_success "Cloning of '$name' complete."
        else
            log_error "Cloning of '$name' failed."
            return 1
        fi
    fi
}

handle_http_package() {
    local name="$1"
    local url="$2"
    local pattern="${3:--}"

    log_info "--- Checking (LATEST): $name ---"
    local current_local_file
    current_local_file=$(find "$SOURCE_DIR" -maxdepth 1 -name "${name}-*.tar.*" 2>/dev/null | head -n1 || true)
    local current_local_version=""
    if [ -n "$current_local_file" ]; then
        current_local_version=$(extract_version "$(basename "$current_local_file")")
        log_info "Local version found: $current_local_version"
    else
        log_info "No local version found."
    fi

    log_info "Searching for the latest stable version at: $url"
    local candidate_files
    candidate_files=$(curl -sL "$url" | grep -ioE '<a[^>]* href="[^"]*"' | sed -e 's/.*href=[\"'\'']//' -e 's/[\"'\''].*//' || true)

    if [[ -z "$candidate_files" ]]; then log_warn "Could not find any links at the specified URL."; return; fi

    local filtered_list
    filtered_list=$(echo "$candidate_files" | grep -iE "^${name}" | grep -E '\.tar\.(gz|bz2|xz)$' | grep -ivE '(-rc|-alpha|-beta|test|git|pre|snapshot|asc|sign|sig|sha|md5|doc|manual|patch)')

    if [[ -n "$pattern" && "$pattern" != "-" ]]; then
        log_info "Using specific search pattern: $pattern"
        filtered_list=$(echo "$filtered_list" | grep -E "$pattern" || true)
    fi

    if [ -z "$filtered_list" ]; then log_warn "Could not find any candidate files for '$name' after filtering."; return; fi

    local best_version_file=""
    local best_version_num="0"
    while IFS= read -r file; do
        local current_version_num=$(extract_version "$file")
        local sorted=$(printf "%s\n%s" "$best_version_num" "$current_version_num" | sort -V | tail -n1)
        if [[ "$sorted" == "$current_version_num" ]]; then
            best_version_num="$current_version_num"
            best_version_file="$file"
        fi
    done <<< "$filtered_list"

    if [ -z "$best_version_file" ]; then log_warn "Could not determine the latest version for '$name'."; return; fi
    
    local latest_remote_version=$(extract_version "$best_version_file")
    log_info "Latest remote version found: $latest_remote_version (File: $best_version_file)"

    if [[ "$current_local_version" == "$latest_remote_version" ]]; then
        log_success "Already at the latest version: $name ($current_local_version)"
    else
        log_warn "New version available for $name: $latest_remote_version (local: ${current_local_version:-none})"
        local download_url
        if [[ "$best_version_file" == "http"* ]]; then download_url="$best_version_file"; else download_url="${url%/}/${best_version_file}"; fi
        log_info "Downloading: $download_url"
        if wget -P "$SOURCE_DIR" "$download_url"; then
            if [ -n "$current_local_file" ] && [ -f "$current_local_file" ]; then
                log_info "Removing old version: $(basename "$current_local_file")"
                rm "$current_local_file"
            fi
            log_success "Download of $name version $latest_remote_version complete."
        else
             log_error "Download of $name failed."
        fi
    fi
}

handle_github_package() {
    local name="$1"
    local repo_url="$2"
    log_info "--- Checking (GITHUB_LATEST): $name ---"
    
    local current_local_file=$(find "$SOURCE_DIR" -maxdepth 1 -name "${name}-*.tar.*" 2>/dev/null | head -n1 || true)
    local current_local_version=""
    if [ -n "$current_local_file" ]; then
        current_local_version=$(extract_version "$(basename "$current_local_file")")
        log_info "Local version found: $current_local_version"
    else
        log_info "No local version found."
    fi

    local repo_path=$(echo "$repo_url" | sed -E 's#https?://[^/]+/##')
    local api_url="https://api.github.com/repos/${repo_path}/releases/latest"
    
    log_info "Fetching release info from: $api_url"
    local latest_tag=$(curl -sL "$api_url" | grep -oE '"tag_name":\s*"[^"]*"' | sed -E 's/.*"tag_name":\s*"(.*)".*/\1/' || true)

    if [ -z "$latest_tag" ]; then
        log_warn "Could not find a 'latest' release via API for '$name'. Falling back to tags page."
        latest_tag=$(curl -Ls "${repo_url}/tags" | grep -oE '/releases/tag/[^"]*' | sed 's|/releases/tag/||' | grep -ivE '(rc|alpha|beta)' | head -n 1 || true)
        if [ -z "$latest_tag" ]; then log_error "Could not find any release or tag for '$name'."; return; fi
    fi

    local latest_remote_version=$(extract_version "$latest_tag")
    log_info "Latest remote version found: $latest_remote_version"

    if [[ "$current_local_version" == "$latest_remote_version" ]]; then
        log_success "Already at the latest version: $name ($current_local_version)"
    else
        log_warn "New version available for $name: $latest_remote_version (local: ${current_local_version:-none})"
        local download_url="${repo_url}/archive/refs/tags/${latest_tag}.tar.gz"
        local output_filename="${name}-${latest_remote_version}.tar.gz"
        log_info "Downloading: $download_url"
        if wget --quiet -O "$SOURCE_DIR/$output_filename" "$download_url"; then
            log_success "Download of $name version $latest_remote_version complete."
        else
            log_error "Download of $name failed. Check URL: $download_url"
            rm -f "$SOURCE_DIR/$output_filename"
        fi
    fi
}

handle_sourceforge_rss() {
    local name="$1"
    local project_name="$2"
    log_info "--- Checking (SOURCEFORGE_RSS): $name ---"
    
    local current_local_file=$(find "$SOURCE_DIR" -maxdepth 1 -name "${name}-*.tar.*" -o -name "${project_name}-*.tar.*" 2>/dev/null | head -n1 || true)
    local current_local_version=""
    if [ -n "$current_local_file" ]; then
        current_local_version=$(extract_version "$(basename "$current_local_file")")
        log_info "Local version found: $current_local_version"
    else
        log_info "No local version found."
    fi
    
    local rss_url="https://sourceforge.net/projects/${project_name}/rss"
    log_info "Searching for latest stable version via RSS: $rss_url"
    local all_links=$(curl -sL "$rss_url" | grep -oE '<link>[^<]*</link>' | sed -e 's/<link>//' -e 's/<\/link>//' || true)
    if [ -z "$all_links" ]; then log_warn "Could not find any links in the RSS feed for '$name'."; return; fi
    local filtered_links=$(echo "$all_links" | grep -E '\.tar\.(gz|bz2|xz)/download$' | grep -ivE '(-rc|-alpha|-beta|test|git|pre|snapshot|doc|manual|guide)')
    if [ -z "$filtered_links" ]; then log_warn "Found no valid source files after filtering for '$name'."; return; fi

    local best_version_url=""
    local best_version_num="0"
    while IFS= read -r url; do
        local current_version_num=$(extract_version "$url")
        local sorted=$(printf "%s\n%s" "$best_version_num" "$current_version_num" | sort -V | tail -n1)
        if [[ "$sorted" == "$current_version_num" ]]; then
            best_version_num="$current_version_num"
            best_version_url="$url"
        fi
    done <<< "$filtered_links"

    local latest_remote_version="$best_version_num"
    log_info "Latest remote version found: $latest_remote_version"
    
    if [[ "$current_local_version" == "$latest_remote_version" ]]; then
        log_success "Already at the latest version: $name ($current_local_version)"
    else
        log_warn "New version available for $name: $latest_remote_version (local: ${current_local_version:-none})"
        log_info "Downloading: $best_version_url"
        local original_dir=$(pwd)
        cd "$SOURCE_DIR" || exit 1
        if curl -LJO "$best_version_url"; then
            log_success "Download of $name version $latest_remote_version complete."
        else
            log_error "Download of $name failed."
        fi
        cd "$original_dir"
    fi
}

# --- Huvudlogik ---
main() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file '$CONFIG_FILE' not found."
        exit 1
    fi

    mkdir -p "$SOURCE_DIR"
    log_info "Starting source package check in '$SOURCE_DIR'"
    echo ""

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^# || -z "$line" ]]; then continue; fi
        read -r -a fields <<< "$line"
        local name="${fields[0]:-}"
        local handler="${fields[1]:-}"
        local url="${fields[2]:-}"
        local pattern="${fields[3]:-}"
        
        if [[ -z "$name" || -z "$handler" || -z "$url" ]]; then
            [[ -n "$name" ]] && log_warn "Malformed line for package '$name'. Skipping."
            continue
        fi

        case "$handler" in
            PINNED) 
                handle_pinned_package "$name" "$url" "$pattern" 
                ;;
            GIT)
                handle_git_package "$name" "$url"
                ;;
            LATEST) 
                handle_http_package "$name" "$url" "$pattern" 
                ;;
            GITHUB_LATEST)
                handle_github_package "$name" "$url"
                ;; 
            SOURCEFORGE_RSS)
                handle_sourceforge_rss "$name" "$url"
                ;;
            *) 
                log_warn "Unknown handler '$handler' for package '$name'. Skipping." 
                ;;
        esac
        echo ""
    done < "$CONFIG_FILE"
    log_info "All packages checked."
}

# Kör huvudfunktionen
main "$@"

