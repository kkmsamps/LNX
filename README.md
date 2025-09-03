# LNX
LNX - A Minimalist Linux Project
Philosophy

LNX is a minimalist, source-based Linux distribution built upon the musl C library. The project aims to create a small-footprint, secure, and portable host operating system.

The primary model for running applications is through rootless Podman containers, which minimizes the software installed and running on the host system itself. This provides a clean separation between the base system and user applications.

A key goal is portability between the x86_64 and aarch64 architectures. The build scripts and kernel configuration are designed to be adaptable to both.

Key Features
This is not just a minimal base, but a fully functional system built from source, including:

Core System: Based on the lightweight and secure musl libc.

Custom Kernel: A custom-configured Linux 6.6 kernel.

Container Runtime: A complete, rootless Podman stack with crun, conmon, and necessary networking components.

Authentication: A modern and secure login stack using Linux-PAM and Shadow.

Graphical Stack: A full, manually compiled X.org environment, including the server, libraries, and input drivers.

Window Manager: A choice of classic, lightweight window managers like twm or Fluxbox, configured for a modern workflow.

Audio: A functional "bare metal" ALSA sound system, configured with dmix for software mixing to support modern applications.

Build Process
The system is built from source using a series of sequential shell scripts.

Prerequisites:

A working Linux build host (e.g., Fedora Workstation) with the dependencies listed in the build scripts.

A dedicated partition or disk image (formatted with ext4) to serve as the LNX root filesystem, mounted at /MAKE_LNX.

Steps:

Prepare Environment: Mount your target partition to /MAKE_LNX.

Download Sources: Use the provided update_sources.sh scripts to download all necessary source code tarballs into /MAKE_LNX/SOURCE_CODE/.

Unpack Sources: Use the unpack.sh scripts to extract all sources.

Execute Build Scripts: Run the build scripts (BUILD_SYSTEM1, BUILD_SYSTEM2 etc.) in numerical order AFTER the first boot into the new OS. 
These scripts are designed to be robust:

They will stop immediately if an error occurs.

They will pause for your review after each package is successfully built, allowing for careful monitoring.

Booting
This project focuses on building the root filesystem (rootfs) and all the necessary system software. Instructions for creating a bootable image (e.g., configuring a bootloader like GRUB for x86_64 or U-Boot for aarch64) are not included. The user is expected to handle the final steps of making the built system bootable on their target hardware or VM.

⚠️ Disclaimer
LNX is an experimental and educational project provided "as-is" without any warranty. Building and running a custom OS from scratch is a complex process. Be warned that mistakes can lead to data loss or system instability. Always work in a safe, backed-up environment.




Some details if you get stucked:
--------------------------------
The process of building it is basically:
Install a Linux of your choice, ie Fedora Workstation.
mkdir /MAKE_LNX
mount <your ext4 filesystem of choice to> /MAKE_LNX
Add the depndendencies found in the header of BUILD_SYSTEM.sh
Copy/paste the contents of BUILD_SYSTEM.sh, ie section for section. Start with the initial scripts to build the filesystem and adding scripts.
Make sure packages.conf contains the correct package versions if you want to change anything. (Possibly break the system)
Download software (to /MAKE_LNX/SOURCE_CODE/ with:
./update_sources.sh
./update_extra_sources.sh
./unpack.sh
./unpack2.sh
Start compile the software with:
vi BUILD_SYSTEM.sh -> build only one package at a time and make sure it really compiles without any errors!
(The file BUILD_SYSTEM.sh implies that it could be run, witch currently is NOT the case)
Finally, make the LNX core operating system bootable which is something you have to figure out yourself, instructions for this is NOT included, 
only som ideas for you to get youreself started.






An Architectural Analysis of the LNX Cross-Compilation and System Build Process
LNX Build System: An Architectural Overview

Detta dokument ger en djupgående teknisk analys av arkitekturen och byggprocessen för LNX, ett anpassat Linux-system byggt från källkod. Det beskriver de grundläggande koncepten, bootstrap-processen för cross-kompilatorn och hur systemavbildningen slutligen monteras.

1. Foundational Concepts

För att förstå LNX byggskript är det viktigt att först förstå de grundläggande koncept som styr dess arkitektur.

1.1 The Cross-Compilation Paradigm

Cross-kompilering innebär att man bygger programvara på ett system som är avsett att köras på ett annat. Processen använder en specifik terminologi för att definiera de inblandade maskinernas roller.

    Build Machine: Datorn som utför själva kompileringen (t.ex. en utvecklares x86_64-arbetsstation).

    Host Machine: Systemet där den kompilerade binären kommer att köras. För de flesta program (som bash) är detta målenheten (t.ex. en ARM-baserad enhet).

    Target Machine: Endast relevant när man bygger en kompilator. Det specificerar arkitekturen som den nya kompilatorn i sin tur ska generera kod för.

Dessa termers relativa betydelse är en vanlig källa till förvirring. Till exempel, när man bygger själva cross-kompilatorn (GCC):

    Build: Utvecklarens PC.

    Host: Utvecklarens PC (eftersom kompilatorn körs här).

    Target: Målenheten (t.ex. ARM).

Men när den färdiga cross-kompilatorn sedan används för att bygga ett program som bash:

    Build: Utvecklarens PC.

    Host: Målenheten (eftersom bash körs där).

    Target: Irrelevant för denna uppgift.

LNX-skriptet hanterar detta genom att korrekt specificera flaggorna --build, --host och --target i varje steg.

1.2 The Chroot-less Strategy: Build Isolation via Sysroot

En definierande egenskap hos LNX är att den medvetet undviker chroot. Traditionella systembyggen använder ofta chroot för att skapa en sandlåda, vilket kräver root-privilegier.

LNX använder istället det moderna alternativet --with-sysroot, en flagga till kompilatorn och länkaren. Istället för att ändra rotkatalogen för processen, talar --sysroot om för verktygskedjan var den ska leta efter systemets headers och bibliotek.

Detta ger flera fördelar:

    Säkerhet och privilegier: Hela byggprocessen kan köras som en vanlig användare, vilket minimerar säkerhetsriskerna.

    Portabilitet och inkapsling: Hela målsystemet är fristående i en enda, flyttbar katalog.

    Parallellitet och moderna verktyg: Tillåter flera parallella byggen för olika arkitekturer och är kompatibelt med CI/CD-pipelines och container-miljöer som Docker.

2. The Cross-Toolchain Bootstrap Process

Att skapa en cross-kompilator är ett klassiskt "hönan och ägget"-problem. LNX löser detta genom en standardiserad flerstegsprocess.

2.1 Stage 1: The Cross-Binutils Prerequisite

Det allra första steget är att bygga GNU Binutils. Detta är nödvändigt eftersom GCC producerar assemblerkod som måste hanteras av en assembler (as) och en länkare (ld), vilka båda är en del av Binutils.

Kritiska configure-flaggor:

    --target=$TARGET_TRIPLET: Talar om att vi bygger verktyg för en annan arkitektur.

    --prefix=/path/to/tools: Installerar verktygen i en separat, säker katalog.

    --with-sysroot=/path/to/lnx/rootfs: Bäddar in sökvägen till målets framtida filsystem i länkaren.

    --disable-nls: Inaktiverar språkstöd för att minska beroenden.

2.2 Stage 2: The Multi-Phase GCC Build

Med cross-länkaren och assemblern på plats kan bygget av GCC påbörjas.

2.2.1 Installing Kernel Headers

Innan C-biblioteket kan byggas måste Linux-kärnans headers installeras i sysroot. Dessa definierar kärnans ABI (Application Binary Interface), som C-biblioteket (musl) är djupt beroende av.

2.2.2 Building the Stage 1 "Bootstrap" C Compiler

En minimal C-kompilator byggs. Dess enda syfte är att kunna kompilera musl. Eftersom musl inte finns än, måste denna kompilator byggas utan beroenden till det.

    --without-headers: Talar om för GCC att inte leta efter C-bibliotekets headers.

    --enable-languages=c: Bygger endast stöd för C för att spara tid.

2.2.3 Building the Target C Library (musl)

Med Steg 1-kompilatorn kan nu målets C-bibliotek, musl, byggas. Till skillnad från Glibc, som är känt för en komplex konfiguration, är musl designat för enkelhet.

    --host=$TARGET_TRIPLET: Anger att musl självt kommer att köras på målsystemet.

    CC=${TARGET_TRIPLET}-gcc: Talar om att configure-skriptet måste använda den nyss byggda Steg 1-kompilatorn.

2.2.4 Building the Final Stage 2 C/C++ Compiler

Slutligen byggs GCC en sista gång. Denna gång skapas en komplett C/C++ cross-kompilator som nu kan länka mot det fullständiga musl-biblioteket i sysroot.

    Flaggan --without-headers tas bort.

    --enable-languages=c,c++ aktiveras.

Bootstrap-processen i korthet

Stage	Package	Key configure Flags	Compiler Used	Primary Output/Purpose
1	Binutils	--target, --with-sysroot	Build System GCC	Create cross-linker (ld) and cross-assembler (as).
2a	Kernel Headers	(N/A - make headers_install)	(N/A)	Provide kernel ABI definitions in sysroot.
2b	GCC (Stage 1)	--target, --without-headers, --enable-languages=c	Build System GCC	Create a minimal cross-compiler to build the C library.
2c	musl	--host, --build, CC=	Stage 1 Cross-GCC	Build the complete C standard library for the target.
2d	GCC (Stage 2)	--target, --enable-languages=c,c++	Build System GCC	Create the final, full-featured C/C++ cross-compiler.

3. System Image Assembly

När verktygskedjan är komplett, övergår skriptet till att bygga själva operativsystemet.

3.1 The initramfs: Crafting the Initial Boot Environment

initramfs är ett temporärt RAM-baserat filsystem som kärnan använder för att starta systemet och ladda drivrutiner som behövs för att montera det permanenta rotfilsystemet.

Processen:

    En minimal katalogstruktur skapas (/bin, /lib, etc.).

    Essentiella verktyg (från t.ex. BusyBox) kompileras som statiskt länkade binärer. Detta är extra effektivt i kombination med musl, som är optimerat för just detta.

    Binärerna och nödvändiga kärnmoduler kopieras in.

    Ett startskript, /init, skapas för att ladda moduler, montera rotfilsystemet och byta rot med switch_root.

    Allt paketeras i en komprimerad cpio-arkivfil.

3.2 The Second Binutils Build: A Native Toolset

Skriptet bygger Binutils en andra gång. Syftet är helt annorlunda: att skapa en nativ verktygskedja som körs på målenheten själv.

Denna gång används flaggan --host=$TARGET_TRIPLET. Byggsystemet förstår då att det ska cross-kompilera, och resultatet blir ARM-binärer (eller annan målarkitektur) istället för x86. Dessa verktyg (ld, as, etc.) installeras i det slutgiltiga rotfilsystemet och ger systemet förmågan att kompilera program direkt på enheten.

3.3 Final Root Filesystem Population

Den sista fasen är att fylla rotfilsystemet med all återstående mjukvara (bash, coreutils, systemd, etc.). För varje paket:

    Körs configure med --host=$TARGET_TRIPLET.

    Kompileras källkoden med cross-kompilatorn.

    Installeras filerna till sysroot-katalogen med DESTDIR-variabeln.

4. Architectural Highlights & Conclusion

4.1 Process Viability

Byggprocessen är robust och följer den beprövade standardmetodologin som används av projekt som Linux From Scratch och Buildroot. Den hanterar de cirkulära beroendena korrekt, och strategin med en dubbel binutils-kompilering är en logisk och korrekt implementation för att både bygga systemet och ge det "självbyggande" förmågor.

4.2 Advantages of the sysroot Model

Valet att basera hela arkitekturen på sysroot är skriptets största styrka.

    Säkerhet: Kräver inte root-privilegier.

    Enkelhet och portabilitet: Hela resultatet är inkapslat i en enda flyttbar katalog.

    Parallellitet: Flera byggen kan köras samtidigt utan att störa varandra.

    Kompatibilitet: Passar perfekt för moderna CI/CD-flöden och container-miljöer som Docker.
