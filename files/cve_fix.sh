#!/bin/sh
set -u # Exit on unset variables

# ==============================================================================
# --- Configuration
# All user-configurable variables are placed here.
# ==============================================================================
readonly SCRIPT_NAME=$(basename "$0")

# Directory where the unzipped CVE list from cvelistV5 is located.
readonly CVE_BASE_DIR="cvelistV5-main/cves/"

# Directory containing the source code packages to be checked.
readonly SOURCE_CODE_DIR="/SOURCE_CODE"

# Output file for potential packages that need patching.
readonly PATCH_CANDIDATES_FILE="packages_to_patch.txt"

# Output file for example download links for patched versions.
readonly DOWNLOAD_LIST_FILE="patches_to_download.txt"

# ==============================================================================
# --- Functions
# ==============================================================================

# --- Help and Logging Functions ---

show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [-d] [-b] [-c [package_name]] [-h]

A script to manage CVE vulnerabilities by checking a local source code repository
against the CVE database. (ash/curl compatible)

Flags:
  -b                    Perform the 'build' operation.
  -c [package_name]     Perform the 'check' operation. 
                        If [package_name] is provided, only that package is checked.
                        Otherwise, all packages in '$SOURCE_CODE_DIR' are checked.
  -d                    Perform the 'download' operation (download and unpack CVE list).
  -h                    Display this help message.

You can combine flags, e.g., '$SCRIPT_NAME -d -c' to download then check all packages.
Or '$SCRIPT_NAME -c binutils' to check only the 'binutils' package.
EOF
}

log_info() {
  echo "[INFO] $1"
}

log_warn() {
  echo "[WARN] $1" >&2
}

log_error() {
  echo "[ERROR] $1" >&2
}

# --- Core Operation Functions ---

perform_download() {
  log_info "--- Starting DOWNLOAD operation ---"
  local cve_zip_url="https://github.com/CVEProject/cvelistV5/archive/refs/heads/main.zip"
  local zip_file="main.zip"

  log_info "Downloading resources from $cve_zip_url using curl..."
  # Use curl to download the file. -s for silent, -L to follow redirects, -o for output file.
  curl -s -L -o "$zip_file" "$cve_zip_url"

  log_info "Unzipping the archive..."
  unzip -o -q "$zip_file"

  log_info "Cleaning up downloaded zip file..."
  rm -f "$zip_file"

  log_info "Fetching and unpacking of the latest CVE archive completed."
  log_info "--- DOWNLOAD operation finished ---"
}

perform_build() {
  log_info "--- Starting BUILD operation ---"
  # Add your build commands here
  log_info "Compiling code..."
  # Example command: make build_project
  log_info "--- BUILD operation finished ---"
}

check_single_package() {
    local package_name=$1
    local current_year
    current_year=$(date +%Y)
    local last_year
    last_year=$((current_year - 1))

    # Special handling for the linux kernel
    case "$package_name" in
        linux*)
            # Internally, we search for 'kernel' in the CVE DB
            package_name=$(echo "$package_name" | sed 's/^linux/kernel/')
            ;;
    esac
    log_info "--------------------------------------------------"
    log_info "Checking package: $package_name"

    # --- SEARCH STEP 1: High-priority search for 'lessThan' or 'lessThanOrEqual' ---
    # NOTE: 'sort -V' is a GNU extension and not available in ash. Using standard 'sort'.
    # This may lead to incorrect version comparison (e.g., 2.10 sorts before 2.2).
    local result_specific
    result_specific=$(grep -B0 -A20 -Ri "\"product\": \"$package_name\"," "$CVE_BASE_DIR$last_year" "$CVE_BASE_DIR$current_year" 2>/dev/null | \
                      grep -E '"lessThan"|"lessThanOrEqual"' | \
                      sort | tail -n1 | \
                      awk -v pkg_name="$package_name" 'IGNORECASE = 1;{printf "%s-%s\n",pkg_name,$3}' | \
                      sed 's/"//g; s/,//g')

    if [ -n "$result_specific" ]; then
      echo "$result_specific" >> "$PATCH_CANDIDATES_FILE"
      log_info "Found specific 'lessThan' match for $package_name. Added to candidates file." 
    else
      log_info "No 'lessThan' match found for $package_name. Falling back to 'version' search." 
      
      # --- ADJUSTED SEARCH STEP 2: Search for lists of versions ---
      local highest_listed_version
      # NOTE: 'sort -V' replaced with standard 'sort'.
      # NOTE: 'xargs -r' replaced with 'xargs'. Harmless if grep finds nothing.
      highest_listed_version=$(grep -lRi "\"product\": \"$package_name\"," "$CVE_BASE_DIR$last_year" "$CVE_BASE_DIR$current_year" 2>/dev/null | \
                               xargs cat | \
                               awk '
                                  /\"versions\": \[/ { in_versions_block=1; next }
                                  /\]/ && in_versions_block { in_versions_block=0 }
                                  in_versions_block && /\"version\":/ {
                                      gsub(/.*\"version\": \"|\",/, "");
                                      print $0;
                                  }
                               ' | \
                               sort | tail -n1)
      
      local result_general=""
      if [ -n "$highest_listed_version" ]; then
          result_general=$(printf "%s-%s\n" "$package_name" "$highest_listed_version")
      fi

      if [ -n "$result_general" ]; then
        echo "$result_general" >> "$PATCH_CANDIDATES_FILE"
        log_info "Found general 'version' match for $package_name. Added to candidates file." 
      else
        log_info "No standard 'product' match found for $package_name. Trying other patterns." 
        
        # --- SEARCH STEP 3: Fallback search using 'packageName' field ---
        # NOTE: 'sort -V' replaced with standard 'sort'.
        local result_extra
        result_extra=$(grep -B5 -A50 -Ri "\"packageName\": \"$package_name\"," "$CVE_BASE_DIR$last_year" "$CVE_BASE_DIR$current_year" 2>/dev/null | \
                       grep -E "\"version\":" | \
                       sort | tail -n1 | \
                       awk -v pkg_name="$package_name" 'IGNORECASE = 1;{printf "%s-%s\n",pkg_name,$3}' | \
                       sed 's/"//g; s/,//g') 

        if [ -n "$result_extra" ]; then
          echo "$result_extra" >> "$PATCH_CANDIDATES_FILE"
          log_info "NOTE: Found extra match using 'packageName' for $package_name. Added to candidates file." 
        else
          # This is a very broad search and part of the original script's logic.
          # NOTE: 'sort -V' replaced with standard 'sort'.
          local result_extra_general
          result_extra_general=$(grep -B0 -A350 -Ri "\"version\":  \"$package_name\"," "$CVE_BASE_DIR$last_year" "$CVE_BASE_DIR$current_year" 2>/dev/null | \
                                 grep -E "version" | \
                                 sort | tail -n1 | \
                                 awk -v pkg_name="$package_name" '{
                                    gsub(/"/, "", $0); 
                                    gsub(/,/, "", $0); 
                                    extracted_version = "";
                                    if (match($0, /([0-9]+\.[0-9]+(\.[0-9a-zA-Z-]+)*)$/)) { 
                                        extracted_version = substr($0, RSTART, RLENGTH); 
                                    }
                                    if (extracted_version != "") {
                                        printf "%s-%s\n", pkg_name, extracted_version 
                                    }
                                 }' | \
                                 sed 's/"//g; s/0://g; s/,//g') 

          if [ -n "$result_extra_general" ]; then
            echo "$result_extra_general" >> "$PATCH_CANDIDATES_FILE"
            log_info "Found non-standard 'version' match for $package_name. Added to candidates file." 
          else
            log_info "All standard searches failed. Falling back to new free-text search." 
            
            # --- NEW FEATURE: Final Fallback - Free-text search ---
            # NOTE: 'sort -V' replaced with standard 'sort'.
            local result_freetext
            result_freetext=$(grep -hriE "(\"name\"|\"url\").*\b${package_name}\b" "$CVE_BASE_DIR$last_year" "$CVE_BASE_DIR$current_year" 2>/dev/null | \
                                awk -v pkg_name="$package_name" '
                              {
                                  pkg_regex = "\\b" pkg_name "\\b";
                                  if (match($0, pkg_regex)) { 
                                      search_str = substr($0, RSTART); 
                                      while (match(search_str, /[0-9]+\.[0-9]+[0-9a-zA-Z._-]*?/)) { 
                                          print substr(search_str, RSTART, RLENGTH); 
                                          search_str = substr(search_str, RSTART + RLENGTH); 
                                      }
                                  }
                              }' | \
                              sort | \
                              tail -n 1) 
            
            if [ -n "$result_freetext" ]; then
              log_warn "Free-text search found a potential version for $package_name: $result_freetext. This result may be imprecise." 
              echo "${package_name}-${result_freetext}" >> "$PATCH_CANDIDATES_FILE" 
            else
              log_info "All search methods failed for $package_name. No CVE candidate found." 
            fi
          fi
        fi
      fi
    fi
}

perform_check() {
  local target_package=${1:-} # Default to empty string if not provided

  log_info "--- Starting CHECK operation ---"

  # Verify that necessary directories exist
  if [ ! -d "$SOURCE_CODE_DIR" ]; then
    log_error "Source code directory '$SOURCE_CODE_DIR' not found. Exiting."
    exit 1
  fi
  if [ ! -d "$CVE_BASE_DIR" ]; then
    log_error "CVE database directory '$CVE_BASE_DIR' not found. Run with -d flag first. Exiting."
    exit 1
  fi

  # Clear previous patch information
  : > "$PATCH_CANDIDATES_FILE"
  echo "NOTE: These are only download examples. Verify the version and source before use.\n" > "$DOWNLOAD_LIST_FILE"

  # --- Main Loop Logic ---
  if [ -n "$target_package" ]; then
    # --- A specific package was provided ---
    log_info "Running check for a single package: $target_package"
    local package_dir="$SOURCE_CODE_DIR/$target_package"
    
    if [ ! -d "$package_dir" ]; then
        local found_tarball=$(ls -1 "$SOURCE_CODE_DIR" | grep -E "^${target_package}-[0-9].*")
        if [ -z "$found_tarball" ]; then
            log_error "Package directory or a corresponding tarball for '$target_package' not found in '$SOURCE_CODE_DIR'. Exiting."
            exit 1
        fi
    fi
    check_single_package "$target_package"

  else
    # --- No specific package, check all ---
    log_info "Running checks for all packages in '$SOURCE_CODE_DIR'..."
    for dir in "$SOURCE_CODE_DIR"/*; do
      if [ -d "$dir" ]; then
        local package_name
        package_name=$(basename "$dir")
        check_single_package "$package_name"
      fi
    done
  fi
  
  log_info "--- Comparison Phase ---"
  echo ""
  echo "==================================================== "
  echo "CVE vulnerabilities that may require a patch"
  echo "==================================================== "
  printf "%-30s %-30s %s\n" "CVE Version Found:" "Local Version:" "Status:"
  printf "%-30s %-30s %s\n" "------------------------------" "------------------------------" "------"

  # --- Loop through found candidates and compare with local versions ---
  local local_packages
  local_packages=$(ls -p "$SOURCE_CODE_DIR/" | grep -v /)

  while IFS= read -r cve_package_full_version; do
    local cve_package_name
    cve_package_name=$(echo "$cve_package_full_version" | sed 's/-[0-9].*$//')

    local local_search_name=$cve_package_name
    # Handle kernel name mapping
    if [ "$cve_package_name" = "kernel" ]; then
      local_search_name="linux"
    fi

    for local_package_filename in $local_packages; do
      local local_package_base_name
      # Correctly extract base name from files like 'package-1.2.3.tar.gz'
      # Replaced sed -E with POSIX compatible version
      local_package_base_name=$(echo "$local_package_filename" | sed 's/\.tar\..*$//; s/\.tar$//' | sed 's/-[0-9].*$//')
      
      if [ "$local_search_name" = "$local_package_base_name" ]; then
        local local_package_full_version
        local_package_full_version=$(echo "$local_package_filename" | sed 's/\.tar\..*$//; s/\.tar$//')

        # Compare versions using sort. WARNING: 'sort -V' is not available in ash.
        # This uses standard alphanumeric sort, which may be inaccurate for versions.
        local highest_version
        highest_version=$(printf "%s\n%s" "$cve_package_full_version" "$local_package_full_version" | sort | tail -n 1)

        if [ "$highest_version" = "$cve_package_full_version" -a "$cve_package_full_version" != "$local_package_full_version" ]; then
          printf "%-30s %-30s %s\n" "$cve_package_full_version" "$local_package_full_version" "Patch MAY be needed"
        else
          # POSIX replacement for: [[ ! "$cve_package_full_version" =~ -0$ ]]
          case "$cve_package_full_version" in
              *-0)
                printf "%-30s %-30s %s\n" "$cve_package_full_version" "$local_package_full_version" "Unknown CVE version signature"
                ;;
              *)
                printf "%-30s %-30s %s\n" "$cve_package_full_version" "$local_package_full_version" "No patch needed"
                ;;
          esac
        fi
      fi
    done
  done < "$PATCH_CANDIDATES_FILE"

  log_info "\nCheck the file '$DOWNLOAD_LIST_FILE' for some ideas of files that might need to be downloaded."
  log_info "--- CHECK operation finished ---"
}

# ==============================================================================
# --- Main Execution Logic
# ==============================================================================

main() {
  # Default values
  local do_build=false
  local do_check=false
  local do_download=false
  local target_package=""

  # Handle flags using POSIX-standard getopts
  while getopts "bcdh" opt; do
    case $opt in
      b) do_build=true ;;
      c) do_check=true ;;
      d) do_download=true ;;
      h) show_help; exit 0 ;;
      \?) log_error "Invalid option: -$OPTARG"; show_help; exit 1 ;;
    esac
  done

  # Remove all flags (e.g., -c, -d) that getopts has processed from the argument list.
  shift $((OPTIND - 1))

  # If '-c' was specified, check if there is a remaining argument (the package name).
  if [ "$do_check" = "true" ]; then
    if [ -n "${1:-}" ]; then
      target_package="$1"
    fi
  fi

  # If no flags were specified at all, show help and exit.
  if [ "$do_build" = "false" -a "$do_check" = "false" -a "$do_download" = "false" ]; then
    log_error "No operation selected."
    show_help
    exit 1
  fi

  # Execute operations based on flags
  if [ "$do_download" = "true" ]; then
    perform_download
  fi
  if [ "$do_check" = "true" ]; then
    # Pass the (potentially empty) package name to the function
    perform_check "$target_package"
  fi
  if [ "$do_build" = "true" ]; then
    perform_build
  fi

  log_info "Script finished."
}

# Run the main function, passing all script arguments to it
main "$@"
