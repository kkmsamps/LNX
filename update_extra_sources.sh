#!/bin/bash
# Ett optimerat skript för att ladda ner och packa upp specifika uppsättningar
# av X.org-paket, med fokus på återanvändbarhet och robusthet.

set -euo pipefail

# --- Konfiguration & Användarinput ---
echo "Detta skript laddar ner och packar upp X.org-paket (Xlib, XApps, XFonts)."
echo "Det behöver veta var din huvudsakliga källkodskatalog ligger"
echo "för att kunna placera de nya katalogerna där."
echo

# Fråga användaren om sökvägen
read -p "Vänligen ange sökvägen till din källkodskatalog: " SOURCE_DIR

# Validera input
if [[ -z "$SOURCE_DIR" ]]; then
    echo "Fel: Ingen sökväg angavs. Avbryter." >&2
    exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Fel: Den angivna sökvägen '$SOURCE_DIR' är inte en giltig katalog. Avbryter." >&2
    exit 1
fi

# Konvertera till en absolut sökväg för att undvika problem med relativa sökvägar.
SOURCE_DIR=$(cd "$SOURCE_DIR" && pwd)

echo "Använder källkodskatalog: $SOURCE_DIR"

readonly XORG_BASE_URL="https://www.x.org/pub/individual"

# --- Funktion för att ladda ner, verifiera och packa upp en uppsättning X.org-paket ---
# Argument 1: Kategorinamn (t.ex. Xlib)
# Argument 2: MD5-fil (t.ex. lib-7.md5)
# Argument 3: Underkatalog i X.org-arkivet (t.ex. lib)
download_and_process_set() {
    local category_name="$1"
    local md5_filename="$2"
    local url_subdir="$3"
    
    local work_dir="$SOURCE_DIR/$category_name"
    local download_url="${XORG_BASE_URL}/${url_subdir}/"
    local md5_filepath="$SOURCE_DIR/$md5_filename"

    echo "======================================================"
    echo "Hanterar kategori: $category_name"
    echo "======================================================"

    mkdir -p "$work_dir"
    cd "$work_dir"

    # --- Nedladdning (Robust version för BusyBox) ---
    echo "--> Laddar ner filer listade i '$md5_filename'..."
    
    if [[ ! -f "$md5_filepath" ]]; then
        echo "Fel: MD5-filen '$md5_filepath' hittades inte. Avbryter." >&2
        exit 1
    fi

    # Läs MD5-filen rad för rad och anropa wget för varje fil
    # Detta undviker problem med `wget -i-` i BusyBox
    while read -r _ filename || [[ -n "$filename" ]]; do
        # Hoppa över kommenterade eller tomma rader
        [[ "$filename" =~ ^# ]] && continue
        [[ -z "$filename" ]] && continue
        
        echo "    - Laddar ner $filename..."
        # Använd -P . för att ladda ner till den nuvarande katalogen ($work_dir)
        wget -c -P . "${download_url}${filename}"
    done < "$md5_filepath"
    
    # --- Verifiering ---
    echo "--> Verifierar MD5-summor för $category_name..."
    if ! md5sum -c "$md5_filepath"; then
        echo "Fel: MD5-verifiering misslyckades för en eller flera filer i $category_name. Avbryter." >&2
        exit 1
    fi
    
    # --- Uppackning ---
    echo "--> Packar upp filer för $category_name och rensar arkiv..."
    for file in *.tar.xz *.tar.bz2 *.tar.gz; do
        [ -f "$file" ] || continue
        
        # Använder den robusta metoden för att bestämma katalognamn
        local dest_dir
        dest_dir=$(echo "$file" | sed -E -e 's/(-|_|\.)(v?[0-9].*)//' -e 's/\.tar\.(xz|bz2|gz)$//')
        
        echo "    - Packar upp $file till $dest_dir"
        
        rm -rf "$dest_dir"
        mkdir "$dest_dir"
        tar -xf "$file" -C "$dest_dir" --strip-components=1
        
        # Ta bort arkivfilen efter lyckad uppackning
        rm -f "$file"
    done
    
    cd "$SOURCE_DIR"
    echo "[SUCCESS] Hantering av $category_name är klar."
}



# --- Huvudlogik ---

# Gå till källkodskatalogen (redan gjord via användarinput)
cd "$SOURCE_DIR"

# Definiera uppsättningarna av paket som ska hanteras
# Skapa MD5-filerna först
cat > lib-7.md5 << EOF
6ad67d4858814ac24e618b8072900664  xtrans-1.6.0.tar.xz
146d770e564812e00f97e0cbdce632b7  libX11-1.8.12.tar.xz
e59476db179e48c1fb4487c12d0105d1  libXext-1.3.6.tar.xz
c5cc0942ed39c49b8fcd47a427bd4305  libFS-1.0.10.tar.xz
d1ffde0a07709654b20bada3f9abdd16  libICE-1.1.2.tar.xz
3aeeea05091db1c69e6f768e0950a431  libSM-1.2.6.tar.xz
e613751d38e13aa0d0fd8e0149cec057  libXScrnSaver-1.2.4.tar.xz
9acd189c68750b5028cf120e53c68009  libXt-1.3.1.tar.xz
85edefb7deaad4590a03fccba517669f  libXmu-1.2.1.tar.xz
05b5667aadd476d77e9b5ba1a1de213e  libXpm-3.5.17.tar.xz
2a9793533224f92ddad256492265dd82  libXaw-1.0.16.tar.xz
65b9ba1e9ff3d16c4fa72915d4bb585a  libXfixes-6.0.1.tar.xz
af0a5f0abb5b55f8411cd738cf0e5259  libXcomposite-0.4.6.tar.xz
4c54dce455d96e3bdee90823b0869f89  libXrender-0.9.12.tar.xz
5ce55e952ec2d84d9817169d5fdb7865  libXcursor-1.2.3.tar.xz
ca55d29fa0a8b5c4a89f609a7952ebf8  libXdamage-1.1.6.tar.xz
8816cc44d06ebe42e85950b368185826  libfontenc-1.1.8.tar.xz
66e03e3405d923dfaf319d6f2b47e3da  libXfont2-2.0.7.tar.xz
d378be0fcbd1f689f9a132e0d642bc4b  libXft-2.3.9.tar.xz
95a960c1692a83cc551979f7ffe28cf4  libXi-1.8.2.tar.xz
228c877558c265d2f63c56a03f7d3f21  libXinerama-1.1.5.tar.xz
24e0b72abe16efce9bf10579beaffc27  libXrandr-1.5.4.tar.xz
66c9e9e01b0b53052bb1d02ebf8d7040  libXres-1.2.2.tar.xz
b62dc44d8e63a67bb10230d54c44dcb7  libXtst-1.2.5.tar.xz
8a26503185afcb1bbd2c65e43f775a67  libXv-1.0.13.tar.xz
a90a5f01102dc445c7decbbd9ef77608  libXvMC-1.0.14.tar.xz
74d1acf93b83abeb0954824da0ec400b  libXxf86dga-1.1.6.tar.xz
d3db4b6dc924dc151822f5f7e79ae873  libXxf86vm-1.1.6.tar.xz
57c7efbeceedefde006123a77a7bc825  libpciaccess-0.18.1.tar.xz
229708c15c9937b6e5131d0413474139  libxkbfile-1.1.3.tar.xz
9805be7e18f858bed9938542ed2905dc  libxshmfence-1.3.3.tar.xz
bdd3ec17c6181fd7b26f6775886c730d  libXpresent-1.0.1.tar.xz
EOF

cat > app-7.md5 << EOF
30f898d71a7d8e817302970f1976198c  iceauth-1.0.10.tar.xz
7dcf5f702781bdd4aaff02e963a56270  mkfontscale-1.2.3.tar.xz
b9efe1d21615c474b22439d41981beef  sessreg-1.1.4.tar.xz
1d61c9f4a3d1486eff575bf233e5776c  setxkbmap-1.3.4.tar.xz
6484cd8ee30354aaaf8f490988f5f6ef  smproxy-1.0.8.tar.xz
bf7b5a94561c7c98de447ea53afabfc4  xauth-1.1.4.tar.xz
37063ccf902fe3d55a90f387ed62fe1f  xcmsdb-1.0.7.tar.xz
f97e81b2c063f6ae9b18d4b4be7543f6  xcursorgen-1.0.9.tar.xz
933e6d65f96c890f8e96a9f21094f0de  xdpyinfo-1.3.4.tar.xz
34aff1f93fa54d6a64cbe4fee079e077  xdriinfo-1.0.7.tar.xz
f29d1544f8dd126a1b85e2f7f728672d  xev-1.2.6.tar.xz
41afaa5a68cdd0de7e7ece4805a37f11  xgamma-1.0.7.tar.xz
45c7e956941194e5f06a9c7307f5f971  xhost-1.0.10.tar.xz
8e4d14823b7cbefe1581c398c6ab0035  xinput-1.6.4.tar.xz
83d711948de9ccac550d2f4af50e94c3  xkbcomp-1.4.7.tar.xz
543c0535367ca30e0b0dbcfa90fefdf9  xkbevd-1.1.6.tar.xz
07483ddfe1d83c197df792650583ff20  xkbutils-1.0.6.tar.xz
f62b99839249ce9a7a8bb71a5bab6f9d  xkill-1.0.6.tar.xz
da5b7a39702841281e1d86b7349a03ba  xlsatoms-1.1.4.tar.xz
ab4b3c47e848ba8c3e47c021230ab23a  xlsclients-1.1.5.tar.xz
ba2dd3db3361e374fefe2b1c797c46eb  xmessage-1.0.7.tar.xz
0d66e07595ea083871048c4b805d8b13  xmodmap-1.0.11.tar.xz
ab6c9d17eb1940afcfb80a72319270ae  xpr-1.2.0.tar.xz
5ef4784b406d11bed0fdf07cc6fba16c  xprop-1.2.8.tar.xz
dc7680201afe6de0966c76d304159bda  xrandr-1.5.3.tar.xz
c8629d5a0bc878d10ac49e1b290bf453  xrdb-1.2.2.tar.xz
55003733ef417db8fafce588ca74d584  xrefresh-1.1.0.tar.xz
18ff5cdff59015722431d568a5c0bad2  xset-1.2.5.tar.xz
fa9a24fe5b1725c52a4566a62dd0a50d  xsetroot-1.1.3.tar.xz
d698862e9cad153c5fefca6eee964685  xvinfo-1.1.5.tar.xz
b0081fb92ae56510958024242ed1bc23  xwd-1.0.9.tar.xz
c91201bc1eb5e7b38933be8d0f7f16a8  xwininfo-1.1.6.tar.xz
3e741db39b58be4fef705e251947993d  xwud-1.0.7.tar.xz
EOF

cat > font-7.md5 << EOF
a6541d12ceba004c0c1e3df900324642  font-util-1.4.1.tar.xz
a56b1a7f2c14173f71f010225fa131f1  encodings-1.1.0.tar.xz
79f4c023e27d1db1dfd90d041ce89835  font-alias-1.0.5.tar.xz
546d17feab30d4e3abcf332b454f58ed  font-adobe-utopia-type1-1.0.5.tar.xz
063bfa1456c8a68208bf96a33f472bb1  font-bh-ttf-1.0.4.tar.xz
51a17c981275439b85e15430a3d711ee  font-bh-type1-1.0.4.tar.xz
00f64a84b6c9886040241e081347a853  font-ibm-type1-1.0.4.tar.xz
fe972eaf13176fa9aa7e74a12ecc801a  font-misc-ethiopic-1.0.5.tar.xz
3b47fed2c032af3a32aad9acc1d25150  font-xfree86-type1-1.0.5.tar.xz
EOF

# Anropa den generella funktionen för varje kategori
download_and_process_set "Xlib" "lib-7.md5" "lib"
download_and_process_set "XApps" "app-7.md5" "app"
download_and_process_set "XFonts" "font-7.md5" "font"


echo -e '\n\n=> ALLA SPECIFIKA X.ORG-PAKET ÄR NEDLADDADE OCH UPPACKADE! ***'

# Notering: Den generella uppackningsloopen från ditt originalskript har tagits bort
# eftersom all uppackning nu hanteras av det mer robusta uppackningsskriptet du redan har.
# Om detta skript ska vara helt fristående, kan den mer robusta uppackningslogiken
# läggas till här också.

