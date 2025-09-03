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

LNX Build System: An Architectural Overview
-------------------------------------------
This document provides a deep technical analysis of the architecture and build process for LNX, a custom Linux system built from source. It describes the foundational concepts, the cross-compiler bootstrap process, and how the system image is finally assembled.

1. Foundational Concepts

To understand the LNX build script, it is essential to first understand the foundational concepts that govern its architecture.

1.1 The Cross-Compilation Paradigm

Cross-compilation involves building software on one system that is intended to run on another. The process uses specific terminology to define the roles of the machines involved.

    Build Machine: The computer that performs the actual compilation (e.g., a developer's x86_64 workstation).

    Host Machine: The system where the compiled binary will execute. For most applications (like bash), this is the target device (e.g., an ARM-based device).

    Target Machine: Relevant only when building a compiler. It specifies the architecture for which the new compiler will, in turn, generate code.

The relative meaning of these terms is a common source of confusion. For example, when building the cross-compiler itself (GCC):

    Build: The developer's PC.

    Host: The developer's PC (because the compiler runs here).

    Target: The final device (e.g., ARM).

But when that finished cross-compiler is then used to build an application like bash:

    Build: The developer's PC.

    Host: The final device (because bash will run there).

    Target: Irrelevant for this task.

The LNX script manages this by correctly supplying the --build, --host, and --target flags at each stage.

1.2 The Chroot-less Strategy: Build Isolation via Sysroot

A defining feature of LNX is its deliberate avoidance of chroot. Traditional system builds often use chroot to create a sandbox, which requires root privileges.

LNX instead uses the modern alternative --with-sysroot, a flag passed to the compiler and linker. Instead of changing the process's root directory, --sysroot tells the toolchain where to find the target system's headers and libraries.

This provides several advantages:

    Security and Privilege: The entire build process can be run as a non-privileged user, minimizing security risks.

    Portability and Encapsulation: The entire target system is self-contained in a single, relocatable directory.

    Concurrency and Modern Tooling: It allows for multiple parallel builds for different architectures and is compatible with CI/CD pipelines and container environments like Docker.

2. The Cross-Toolchain Bootstrap Process

Creating a cross-compiler is a classic "chicken-and-egg" problem. LNX resolves this by following a standard, multi-stage process.

2.1 Stage 1: The Cross-Binutils Prerequisite

The very first step is to build the GNU Binutils package. This is necessary because GCC produces assembly code that must be handled by an assembler (as) and a linker (ld), both of which are part of Binutils.

Critical configure flags:

    --target=$TARGET_TRIPLET: Tells the build system to create tools for a different architecture.

    --prefix=/path/to/tools: Installs the tools into a separate, safe directory.

    --with-sysroot=/path/to/lnx/rootfs: Embeds the path to the target's future filesystem into the linker.

    --disable-nls: Disables Native Language Support to reduce dependencies.

2.2 Stage 2: The Multi-Phase GCC Build

With the cross-linker and assembler in place, the GCC build can begin.

2.2.1 Installing Kernel Headers

Before the C library can be built, the Linux kernel headers must be installed into the sysroot. These define the kernel's ABI (Application Binary Interface), which the C library (musl) is deeply dependent on.

2.2.2 Building the Stage 1 "Bootstrap" C Compiler

A minimal C compiler is built. Its sole purpose is to compile musl. Since musl does not exist yet, this compiler must be built without a dependency on it.

    --without-headers: Instructs GCC not to look for C library headers.

    --enable-languages=c: Builds support only for the C language to save time.

2.2.3 Building the Target C Library (musl)

With the Stage 1 compiler, the target's C library, musl, can now be built. Unlike Glibc, which is known for its complex configuration, musl is designed for simplicity.

    --host=$TARGET_TRIPLET: Specifies that musl itself will run on the target system.

    CC=${TARGET_TRIPLET}-gcc: Tells the configure script that it must use the newly built Stage 1 compiler.

2.2.4 Building the Final Stage 2 C/C++ Compiler

Finally, GCC is built one last time. This creates a complete C/C++ cross-compiler that can now link against the full musl library in the sysroot.

    The --without-headers flag is removed.

    --enable-languages=c,c++ is activated.

Bootstrap Process Summary

    Stage 1: Binutils

        Package: Binutils

        Key Flags: --target, --with-sysroot

        Compiler Used: Build System GCC

        Purpose: Create cross-linker (ld) and cross-assembler (as).

    Stage 2a: Kernel Headers

        Package: Kernel Headers

        Action: make headers_install

        Purpose: Provide kernel ABI definitions in sysroot.

    Stage 2b: GCC (Stage 1)

        Package: GCC

        Key Flags: --target, --without-headers, --enable-languages=c

        Compiler Used: Build System GCC

        Purpose: Create a minimal cross-compiler to build the C library.

    Stage 2c: musl

        Package: musl

        Key Flags: --host, --build, CC=

        Compiler Used: Stage 1 Cross-GCC

        Purpose: Build the complete C standard library for the target.

    Stage 2d: GCC (Stage 2)

        Package: GCC

        Key Flags: --target, --enable-languages=c,c++

        Compiler Used: Build System GCC

        Purpose: Create the final, full-featured C/C++ cross-compiler.

3. System Image Assembly

Once the toolchain is complete, the script proceeds to build the operating system itself.

3.1 The initramfs: Crafting the Initial Boot Environment

The initramfs is a temporary RAM-based filesystem that the kernel uses to start the system and load drivers needed to mount the permanent root filesystem.

The process:

    A minimal directory structure is created (/bin, /lib, etc.).

    Essential utilities (e.g., from BusyBox) are compiled as statically linked binaries. This is particularly effective in combination with musl, which is optimized for this.

    The binaries and necessary kernel modules are copied into the structure.

    A startup script, /init, is created to load modules, mount the root filesystem, and execute switch_root.

    Everything is packaged into a compressed cpio archive file.

3.2 The Second Binutils Build: A Native Toolset

The script builds Binutils a second time. The purpose is entirely different: to create a native toolchain designed to run on the target device itself.

This time, the --host=$TARGET_TRIPLET flag is used. The build system understands that this requires cross-compilation, and the result is ARM binaries (or other target architecture) instead of x86. These tools (ld, as, etc.) are installed into the final root filesystem, giving the system the ability to compile programs on-device.

3.3 Final Root Filesystem Population

The final phase is to populate the root filesystem with all remaining software (bash, coreutils, systemd, etc.). For each package:

    configure is run with --host=$TARGET_TRIPLET.

    The source code is compiled with the cross-compiler.

    The files are installed into the sysroot directory using the DESTDIR variable.

4. Architectural Highlights & Conclusion

4.1 Process Viability

The build process is robust and follows the proven, standard methodology used by projects like Linux From Scratch and Buildroot. It correctly handles the circular dependencies, and the dual binutils build strategy is a logical and correct implementation for both building the system and providing it with self-hosting capabilities.

4.2 Advantages of the sysroot Model

The decision to base the architecture on sysroot is the script's greatest strength.

    Security: It does not require root privileges.

    Simplicity and Portability: The entire output is encapsulated in a single, relocatable directory.

    Concurrency: Multiple builds can run simultaneously without interfering with each other.

    Compatibility: It is perfectly suited for modern CI/CD workflows and container environments like Docker.
    
