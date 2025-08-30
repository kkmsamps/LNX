#!/bin/bash
set -euo pipefail

# --- Funktion för att visa hjälp/användarinstruktioner ---
usage() {
    echo "Användning: $0 [-h] <sökväg_till_källkodskatalog>"
    echo
    echo "Kontrollerar och laddar ner/uppdaterar källkodsarkiv baserat på packages.conf."
    echo
    echo "Argument:"
    echo "  sökväg_till_källkodskatalog   Katalogen där källkodsarkiven ska sparas."
    echo
    echo "Flaggor:"
    echo "  -h                            Visa denna hjälptext och avsluta."
    exit 0
}

# --- Hantera kommandoradsflaggor och argument ---
while getopts "h" opt; do
    case ${opt} in
        h)
            usage
            ;;
        \?)
            echo "Ogiltig flagga: -$OPTARG" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# Kontrollera om en sökväg har angivits. Om inte, visa hjälp.
if [ $# -eq 0 ]; then
    echo "Fel: Ingen sökväg till källkodskatalog angiven." >&2
    echo ""
    usage
fi

# --- Konfiguration ---
readonly SOURCE_DIR="$1"
readonly CONFIG_FILE="packages.conf"

# --- Färger för snyggare output ---
readonly C_RESET='\033[0m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_BLUE='\033[0;34m'
readonly C_YELLOW='\033[0;33m'

# --- Loggfunktioner ---
log_info() { echo -e "${C_BLUE}[INFO]${C_RESET} $1"; }
log_success() { echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"; }
log_warn() { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }
log_error() { echo -e "${C_RED}[ERROR]${C_RESET} $1" >&2; }

# --- HJÄLPFUNKTIONER FÖR MARKÖR/CACHE-FILER ---
touch_marker_file() {
    local name="$1"
    touch "$SOURCE_DIR/.${name}.checked"
}

check_if_recently_checked() {
    local name="$1"
    local recent_marker
    # Letar efter en markörfil som är yngre än 1440 minuter.
    recent_marker=$(find "$SOURCE_DIR" -name ".${name}.checked" -mmin -1440 -print -quit 2>/dev/null)

    if [[ -n "$recent_marker" ]]; then
        log_success "Paketet '$name' har kontrollerats nyligen (via markörfil). Hoppar över."
        echo ""
        return 0 # Ja, hoppa över
    fi
    return 1 # Nej, fortsätt
}
# --- SLUT PÅ HJÄLPFUNKTIONER ---

extract_version() {
    local string="$1"
    echo "$string" | grep -oE '([0-9]+[._-])+[0-9a-zA-Z._-]*' | sed -E 's/(\.tar\.(gz|bz2|xz))|(\.zip)$//' | head -n1 || echo ""
}

handle_pinned_package() {
    local name="$1"
    local pinned_url="$2"
    log_info "--- Kontrollerar (PINNAD): $name ---"
    local filename
    filename=$(basename "$pinned_url")
    if [ -f "$SOURCE_DIR/$filename" ]; then
        log_success "Korrekt pinnad version finns redan: $filename"
    else
        log_warn "Pinnad version saknas lokalt. Laddar ner: $filename"
        log_info "Laddar ner från: $pinned_url"
        wget -P "$SOURCE_DIR" "$pinned_url"
        log_success "Nedladdning klar."
    fi
}

handle_http_package() {
    local name="$1"
    local url="$2"
    local pattern="$3"

    log_info "--- Kontrollerar (LATEST): $name ---"

    local current_local_file
    current_local_file=$(find "$SOURCE_DIR" -name "${name}-*.tar.*" -o -name "${name}_*.tar.*" 2>/dev/null | head -n1 || true)
    local current_local_version=""
    if [ -n "$current_local_file" ]; then
        current_local_version=$(extract_version "$(basename "$current_local_file")")
        log_info "Lokal version funnen: $current_local_version"
    else
        log_info "Ingen lokal version funnen."
    fi

    log_info "Söker efter senaste stabila versionen på: $url"

    local candidate_files
    candidate_files=$(curl -sL "$url" | grep -ioE '<a[^>]* href="[^"]*"' | sed -e 's/.*href=[\"'\'']//' -e 's/[\"'\''].*//' || true)

    if [[ -z "$candidate_files" ]]; then
        log_warn "Kunde inte hitta några länkar alls på den angivna URL:en."
        touch_marker_file "$name"
        return
    fi

    local filtered_list
    filtered_list=$(echo "$candidate_files" | \
        grep -iE "^${name}" | \
        grep -E '\.tar\.(gz|bz2|xz)$' | \
        grep -ivE '(-rc|-alpha|-beta|test|git|pre|snapshot|asc|sign|sig|sha|md5|doc|manual|patch)')

    if [[ -n "$pattern" && "$pattern" != "-" ]]; then
        log_info "Använder specifikt sökmönster: $pattern"
        filtered_list=$(echo "$filtered_list" | grep -E "$pattern" || true)
    else
        log_info "Inget specifikt mönster angivet, använder generell sökning."
    fi

    if [ -z "$filtered_list" ]; then
        log_warn "Kunde inte hitta några kandidatfiler för '$name' efter filtrering."
        touch_marker_file "$name"
        return
    fi

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

    local latest_remote_filename="$best_version_file"

    if [ -z "$latest_remote_filename" ]; then
        log_warn "Kunde inte fastställa senaste versionen för '$name'."
        touch_marker_file "$name"
        return
    fi

    local latest_remote_version=$(extract_version "$latest_remote_filename")
    log_info "Senaste fjärrversion funnen: $latest_remote_version (Fil: $latest_remote_filename)"

    if [[ "$current_local_version" == "$latest_remote_version" ]]; then
        log_success "Redan senaste versionen: $name ($current_local_version)"
        touch_marker_file "$name"
    else
        log_warn "Ny version tillgänglig för $name: $latest_remote_version (lokal: ${current_local_version:-none})"
        
        local download_url
        if [[ "$latest_remote_filename" == "http"* ]]; then
            download_url="$latest_remote_filename"
        else
            download_url="${url%/}/${latest_remote_filename}"
        fi
        
        log_info "Laddar ner: $download_url"
        rm -f "$SOURCE_DIR/$latest_remote_filename"
        
        if wget -P "$SOURCE_DIR" "$download_url"; then
            if [ -n "$current_local_file" ] && [ -f "$current_local_file" ]; then
                log_info "Tar bort gammal version: $(basename "$current_local_file")"
                rm "$current_local_file"
            fi
            log_success "Nedladdning av $name version $latest_remote_version klar."
            touch_marker_file "$name"
        else
             log_error "Nedladdning av $name misslyckades."
        fi
    fi
}

handle_github_package() {
    local name="$1"
    local repo_url="$2"

    log_info "--- Kontrollerar (GITHUB_LATEST): $name ---"

    local current_local_file
    current_local_file=$(find "$SOURCE_DIR" -name "${name}-*.tar.*" -o -name "${name}_*.tar.*" 2>/dev/null | head -n1 || true)
    local current_local_version=""
    if [ -n "$current_local_file" ]; then
        current_local_version=$(extract_version "$(basename "$current_local_file")")
        log_info "Lokal version funnen: $current_local_version"
    else
        log_info "Ingen lokal version funnen."
    fi

    local repo_path
    repo_path=$(echo "$repo_url" | sed -E 's#https?://[^/]+/##')
    local api_url="https://api.github.com/repos/${repo_path}/releases/latest"
    
    log_info "Hämtar release-info från: $api_url"
    local latest_tag
    latest_tag=$(curl -sL "$api_url" | grep -oE '"tag_name":\s*"[^"]*"' | sed -E 's/.*"tag_name":\s*"(.*)".*/\1/' || true)

    if [ -z "$latest_tag" ]; then
        log_warn "Kunde inte hitta en 'latest' release via API för '$name'. Försöker med tags-sidan som fallback."
        latest_tag=$(curl -Ls "${repo_url}/tags" | grep -oE '/releases/tag/[^"]*' | sed 's|/releases/tag/||' | grep -ivE '(rc|alpha|beta)' | head -n 1 || true)
        if [ -z "$latest_tag" ]; then
            log_error "Kunde inte hitta någon release eller tag alls för '$name'."
            return
        fi
    fi

    local latest_remote_version
    latest_remote_version=$(extract_version "$latest_tag")
    log_info "Senaste fjärrversion funnen: $latest_remote_version"

    if [[ "$current_local_version" == "$latest_remote_version" ]]; then
        log_success "Redan senaste versionen: $name ($current_local_version)"
        touch_marker_file "$name"
    else
        log_warn "Ny version tillgänglig för $name: $latest_remote_version (lokal: ${current_local_version:-none})"
        
        local download_url="${repo_url}/archive/refs/tags/${latest_tag}.tar.gz"
        local output_filename="${name}-${latest_remote_version}.tar.gz"
        
        log_info "Laddar ner: $download_url"
        rm -f "$SOURCE_DIR/$output_filename"
        
        if wget --quiet -O "$SOURCE_DIR/$output_filename" "$download_url"; then
            log_success "Nedladdning av $name version $latest_remote_version klar."
            touch_marker_file "$name"
        else
            log_error "Nedladdning av $name misslyckades. Kontrollera URL: $download_url"
            rm -f "$SOURCE_DIR/$output_filename"
        fi
    fi
}

handle_sourceforge_rss() {
    local name="$1"
    local project_name="$2"
    
    log_info "--- Kontrollerar (SOURCEFORGE_RSS): $name ---"

    local current_local_file
    current_local_file=$(find "$SOURCE_DIR" -name "${name}-*.tar.*" -o -name "${project_name}-*.tar.*" 2>/dev/null | head -n1 || true)
    local current_local_version=""
    if [ -n "$current_local_file" ]; then
        current_local_version=$(extract_version "$(basename "$current_local_file")")
        log_info "Lokal version funnen: $current_local_version"
    else
        log_info "Ingen lokal version funnen."
    fi
    
    local rss_url="https://sourceforge.net/projects/${project_name}/rss"
    log_info "Söker efter senaste stabila versionen via RSS: $rss_url"
    
    # Hämta alla potentiella länkar från RSS-flödet
    local all_links
    all_links=$(curl -sL "$rss_url" | \
        grep -oE '<link>[^<]*</link>' | sed -e 's/<link>//' -e 's/<\/link>//' || true)

    if [ -z "$all_links" ]; then
        log_warn "Kunde inte hitta några länkar alls i RSS-flödet för '$name'."
        touch_marker_file "$name"
        return
    fi
        
    # Filtrera bort allt som inte är en stabil källkods-tarball
    local filtered_links
    filtered_links=$(echo "$all_links" | \
        grep -E '\.tar\.(gz|bz2|xz)/download$' | \
        grep -ivE '(-rc|-alpha|-beta|test|git|pre|snapshot|doc|manual|guide)')

    if [ -z "$filtered_links" ]; then
        log_warn "Hittade inga giltiga källkodsfiler efter filtrering för '$name'."
        touch_marker_file "$name"
        return
    fi

    # Hitta den bästa versionen bland de filtrerade länkarna
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

    local latest_download_url="$best_version_url"
    local latest_remote_version="$best_version_num"

    log_info "Senaste fjärrversion funnen: $latest_remote_version"
    
    if [[ "$current_local_version" == "$latest_remote_version" ]]; then
        log_success "Redan senaste versionen: $name ($current_local_version)"
        touch_marker_file "$name"
    else
        log_warn "Ny version tillgänglig för $name: $latest_remote_version (lokal: ${current_local_version:-none})"
        log_info "Laddar ner: $latest_download_url"
        
        local original_dir
        original_dir=$(pwd)
        cd "$SOURCE_DIR" || exit 1
        
        if curl -LJO "$latest_download_url"; then
            log_success "Nedladdning av $name version $latest_remote_version klar."
            touch_marker_file "$name"
        else
            log_error "Nedladdning av $name misslyckades."
        fi
        
        cd "$original_dir"
    fi
}

# --- NY FUNKTION FÖR GIT ---
handle_git_package() {
    local name="$1"
    local repo_url="$2"

    log_info "--- Kontrollerar (GIT): $name ---"

    local target_dir="$SOURCE_DIR/$name"

    if [ -d "$target_dir" ]; then
        log_success "Katalogen '$name' existerar redan. Antar att den är klonad. Hoppar över."
    else
        log_warn "Katalogen '$name' saknas. Klonar från git-arkiv."
        log_info "Klonar från: $repo_url"
        
        # Kör git clone och skicka outputen till /dev/null för en renare logg,
        # men felmeddelanden visas fortfarande.
        if git clone "$repo_url" "$target_dir" >/dev/null 2>&1; then
            log_success "Kloning av '$name' klar."
        else
            log_error "Kloning av '$name' misslyckades. Kontrollera URL och dina git-inställningar."
        fi
    fi
}
# --- SLUT PÅ NY FUNKTION ---

main() {
    # Flyttade den här logiken till utsidan för att inte vara beroende av $SOURCE_DIR
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Konfigurationsfilen '$CONFIG_FILE' hittades inte i den nuvarande katalogen."
        exit 1
    fi

    # Skapa katalogen om den inte finns
    mkdir -p "$SOURCE_DIR"
    log_info "Startar kontroll av källkodspaket i '$SOURCE_DIR'"

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^# || -z "$line" ]]; then continue; fi
        
        read -r -a fields <<< "$line"
        local name="${fields[0]:-}"
        local handler="${fields[1]:-}"
        local url="${fields[2]:-}"
        local pattern="${fields[3]:-}"
        if [[ -z "$name" || -z "$handler" || -z "$url" ]]; then
            if [[ -n "$name" ]]; then
                 log_warn "Felaktig rad för paket '$name'. Hoppar över."
            fi
            continue
        fi

        case "$handler" in
            PINNED) 
                handle_pinned_package "$name" "$url" 
                ;;
            LATEST) 
                if check_if_recently_checked "$name"; then continue; fi
                handle_http_package "$name" "$url" "$pattern" 
                ;;
            GITHUB_LATEST)
                if check_if_recently_checked "$name"; then continue; fi
                handle_github_package "$name" "$url"
                ;; 
            SOURCEFORGE_RSS)
                if check_if_recently_checked "$name"; then continue; fi
                handle_sourceforge_rss "$name" "$url"
                ;;
            # Lade till GIT-hanteraren här
            GIT)
                handle_git_package "$name" "$url"
                ;;
            *) 
                log_warn "Okänd hanterare '$handler' för paket '$name'. Hoppar över." 
                ;;
        esac
        echo ""
    done < "$CONFIG_FILE"
    log_info "Alla paket kontrollerade."
}

# Kör huvudfunktionen
main
