
t skript för att packa upp källkodsarkiv.
# Det hanterar olika namngivningskonventioner och arkivstrukturer bättre.

# Avsluta omedelbart om ett kommando misslyckas
set -e

# --- Funktion för att visa hjälp/användarinstruktioner ---
usage() {
    echo "Användning: $0 [-h] <sökväg_till_katalog>"
    echo
    echo "Packar upp alla källkodsarkiv (.tar.gz, .tar.bz2, .tar.xz, .zip) i den angivna katalogen."
    echo
    echo "Argument:"
    echo "  sökväg_till_katalog   Katalogen som innehåller arkivfilerna som ska packas upp."
    echo
    echo "Flaggor:"
    echo "  -h                    Visa denna hjälptext och avsluta."
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
    echo "Fel: Ingen sökväg till katalog angiven." >&2
    echo ""
    usage
fi

# Sätt SOURCE_DIR till det första argumentet.
SOURCE_DIR="$1"

# Försök att byta till den angivna katalogen.
# `set -e` kommer att stoppa skriptet med ett standardfelmeddelande
# om `cd` misslyckas, vilket är tydligt och informativt.
cd "$SOURCE_DIR" || exit 1

echo "Arbetar i katalogen: $(pwd)"


echo -e '\n\n=> PACKAR UPP ALLA TAR-ARKIV...'
# Loopa igenom alla vanliga tar-format
for file in *.tar.xz *.tar.bz2 *.tar.gz *.tgz; do
    # Hoppa över om glob-mönstret inte hittade några filer eller om det inte är en fil
    [ -f "$file" ] || continue

    # En mer robust metod för att bestämma destinationskatalogens namn.
    # Denna sed-regel tar bort den sista delen av namnet som ser ut som en version
    # (t.ex. -1.2.3, _v2.4, .29 etc.) samt alla filändelser.
    dest_dir=$(echo "$file" | sed -E -e 's/(-|_|\.)(v?[0-9].*)//' -e 's/\.tar\.(xz|bz2|gz)$//' -e 's/\.tgz$//')

    echo "--- Packar upp '$file' till '$dest_dir' ---"
    
    # Rensa eventuell gammal katalog och skapa en ny
    rm -rf "$dest_dir"
    mkdir -p "$dest_dir"
    
    # Använd olika metoder beroende på filtyp för maximal robusthet
    case "$file" in
        *.tar.xz)
            # För .xz, använd en tvåstegsprocess (unxz | tar) för att undvika
            # problem med inbyggd xz-hantering i vissa versioner av tar (t.ex. BusyBox).
            if ! (unxz < "$file" | tar -xf - -C "$dest_dir" --strip-components=1); then
                echo "Varning: --strip-components=1 misslyckades för '$file'. Detta kan vara normalt."
                echo "         Försöker igen utan att strippa komponenter..."
                unxz < "$file" | tar -xf - -C "$dest_dir"
            fi
            ;;
        *) # För .tar.gz, .tar.bz2, .tgz
            # Försök att packa upp och ta bort den översta katalognivån i arkivet.
            # Om det misslyckas (vilket indikeras av felkod), försök igen utan --strip-components.
            if ! tar -xf "$file" -C "$dest_dir" --strip-components=1; then
                echo "Varning: --strip-components=1 misslyckades för '$file'. Detta kan vara normalt."
                echo "         Försöker igen utan att strippa komponenter..."
                # Eftersom det första försöket kan ha lämnat en tom katalog, rensar vi inte
                # utan packar bara upp igen. Tar kommer att skriva över vid behov.
                tar -xf "$file" -C "$dest_dir"
            fi
            ;;
    esac
done

echo -e '\n\n=> PACKAR UPP ALLA ZIP-ARKIV...'
for file in *.zip; do
    [ -f "$file" ] || continue

    # Använd samma robusta metod för att få namnet på zip-filer
    dest_dir=$(echo "$file" | sed -E -e 's/(-|_|\.)(v?[0-9].*)//' -e 's/\.zip$//')
    
    echo "--- Packar upp '$file' till '$dest_dir' ---"

    rm -rf "$dest_dir"
    mkdir -p "$dest_dir"
    
    # Zip-filer saknar --strip-components, så vi använder en vanlig lösning:
    # Packa upp till en temporär katalog och flytta sedan innehållet.
    TMP_DIR=$(mktemp -d)
    unzip -q "$file" -d "$TMP_DIR"
    
    # Kontrollera om det bara finns en enda fil/katalog i den temporära mappen
    # Använder en subshell för att inte ändra `shopt`-inställningar globalt
    num_items=$( (shopt -s nullglob dotglob; items=("$TMP_DIR"/*); echo ${#items[@]}) )

    if [ "$num_items" -eq 1 ]; then
        inner_item_path="$TMP_DIR/$(ls -A "$TMP_DIR")"
        # Om det är en katalog, flytta dess innehåll till vår destination
        if [ -d "$inner_item_path" ]; then
            echo "Notis: Zip-filen innehåller en enda katalog. Flyttar innehållet uppåt."
            mv "$inner_item_path"/* "$dest_dir/"
        else
            # Det är en enda fil, flytta bara den
            mv "$inner_item_path" "$dest_dir/"
        fi
    else
        # Flera filer/kataloger i roten, flytta allt
        mv "$TMP_DIR"/* "$dest_dir/"
    fi
    
    # Städa upp den temporära katalogen
    rm -r "$TMP_DIR"
done

echo -e '\n\n=> ALL KÄLLKOD ÄR UPPACKAD! ***'
~
~
~
~
~
~
~
~
~
~
~
~
~
~
~
~
~
~
~
~

