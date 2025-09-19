#!/bin/bash
#
# Ett skript för att intelligent packa upp källkodsarkiv.
# Det hanterar befintliga kataloger och flera versioner av samma paket.
#

# Avsluta omedelbart om ett kommando misslyckas
set -e

# --- Funktion för att visa hjälp/användarinstruktioner ---
usage() {
    echo "Användning: $0 [-h] <sökväg_till_katalog>"
    echo
    echo "Packar intelligent upp källkodsarkiv (.tar.gz, .tar.bz2, .tar.xz, .zip) i den angivna katalogen."
    echo "Enbart den senaste versionen av ett paket packas upp, och endast om dess destinationskatalog inte redan finns."
    echo
    echo "Argument:"
    echo "  sökväg_till_katalog   Katalogen som innehåller arkivfilerna."
    echo
    echo "Flaggor:"
    echo "  -h                    Visa denna hjälptext och avsluta."
    exit 0
}

# --- Hantera kommandoradsflaggor och argument ---
while getopts "h" opt; do
    case ${opt} in
        h) usage ;;
        \?) echo "Ogiltig flagga: -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $((OPTIND -1))

# Kontrollera om en sökväg har angivits. Om inte, visa hjälp.
if [ $# -eq 0 ]; then
    echo "Fel: Ingen sökväg till katalog angiven." >&2
    echo ""
    usage
fi

SOURCE_DIR="$1"
cd "$SOURCE_DIR" || exit 1

echo "Arbetar i katalogen: $(pwd)"

# --- HJÄLPFUNKTION ---
# Funktion för att extrahera basnamnet från ett filnamn (t.ex. gcc-14.1.0.tar.gz -> gcc)
get_base_name() {
    echo "$1" | sed -E -e 's/(-|_|\.)(v?[0-9].*)//' -e 's/\.tar\.(xz|bz2|gz)$//' -e 's/\.tgz$//' -e 's/\.zip$//'
}

# --- HUVUDLOGIK ---

# 1. Hitta alla arkiv och extrahera unika basnamn för att veta vilka paket vi har.
#    'sort -u' ser till att vi bara får en post per paket (t.ex. en 'gcc', inte två).
echo -e "\n=> Identifierar unika paket i katalogen..."
unique_packages=$( (ls -1 *.tar.* *.tgz *.zip 2>/dev/null || true) | while read -r file; do get_base_name "$file"; done | sort -u)

if [ -z "$unique_packages" ]; then
    echo "Hittade inga arkivfiler att packa upp. Avslutar."
    exit 0
fi

echo "Funna paket: ${unique_packages//$'\n'/ }"

# 2. Loopa igenom varje unikt paket
for package in $unique_packages; do
    echo -e "\n--- Bearbetar paketet: $package ---"

    # 3. KONTROLL: Finns destinationskatalogen redan?
    if [ -d "$package" ]; then
        echo "[INFO] Katalogen '$package' finns redan, hoppar över."
        continue # Gå till nästa paket i loopen
    fi

    # 4. HITTA SENASTE ARKIV: Katalogen fanns inte, så vi måste packa upp.
    #    Hitta alla arkiv för detta paket, sortera dem per version och välj den sista (senaste).
    #    '2>/dev/null' tystar fel om ett glob-mönster inte matchar.
    latest_archive=$(ls -1 "${package}"-*.* "${package}"_*.* 2>/dev/null | sort -V | tail -n 1)

    if [ -z "$latest_archive" ]; then
        echo "[WARN] Kunde inte hitta någon arkivfil för paketet '$package'. Hoppar över."
        continue
    fi

    echo "Senaste arkiv funnet: '$latest_archive'. Packar upp till '$package'..."

    # 5. PACKA UPP: Använd samma robusta uppackningslogik som tidigare.
    rm -rf "$package"
    mkdir -p "$package"

    case "$latest_archive" in
        *.tar.xz|*.tar.bz2|*.tar.gz|*.tgz)
            # Försök först med --strip-components=1
            if ! tar -xf "$latest_archive" -C "$package" --strip-components=1 2>/dev/null; then
                echo "[INFO] Försöker igen utan --strip-components=1..."
                tar -xf "$latest_archive" -C "$package"
            fi
            ;;
        *.zip)
            # Hantera zip-filer, som saknar --strip-components
            TMP_DIR=$(mktemp -d)
            unzip -q "$latest_archive" -d "$TMP_DIR"
            
            num_items=$( (shopt -s nullglob dotglob; items=("$TMP_DIR"/*); echo ${#items[@]}) )

            if [ "$num_items" -eq 1 ]; then
                # Flytta innehållet i den enskilda underkatalogen/filen
                mv "$TMP_DIR"/* "$package/"
            else
                # Flytta allt från roten av temp-mappen
                mv "$TMP_DIR"/* "$package/"
            fi
            rm -r "$TMP_DIR"
            ;;
        *)
            echo "[ERROR] Okänt arkivformat för '$latest_archive'. Hoppar över."
            rm -rf "$package" # Städa upp den tomma katalogen
            ;;
    esac
    echo "[SUCCESS] '$latest_archive' har packats upp till '$package'."
done

echo -e '\n\n=> ALL KÄLLKOD ÄR UPPACKAD! ***'

