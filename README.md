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

Execute Build Scripts: Run the build scripts (BUILD_SYSTEM1, BUILD_SYSTEM2 etc.) in numerical order. These scripts are designed to be robust:

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
-------------------------------------------------------------------------------
Section 1: Foundational Concepts of the LNX Build Environment

To fully comprehend the mechanics of the LNX build script, it is essential to first establish a firm understanding of the foundational concepts that govern its architecture. The script's design is predicated on modern cross-compilation techniques that prioritize security, portability, and isolation without resorting to traditional, more cumbersome methods. This section delineates the core principles of the cross-compilation paradigm and the script's innovative chroot-less strategy.

1.1 The Cross-Compilation Paradigm: Defining the build, host, and target Machines

The process of cross-compilation involves building software on one system architecture that is intended to run on a different one.1 This process is governed by a precise terminology that defines the roles of the machines involved. A nuanced understanding of these roles is critical, as their meaning is relative to the specific task being performed within the build script.2
Build Machine: This is the computer that performs the actual compilation. In the context of the LNX script, this would be the developer's workstation, typically an x86_64-based machine.2
Host Machine: This is the system on which the compiled binary will execute. For most of the build process, where applications like bash or coreutils are being compiled, the host machine is the final embedded device (e.g., an ARM-based system).2
Target Machine: This term is relevant only when the software being built is itself a piece of a compiler toolchain, such as GCC or Binutils. It specifies the architecture for which the newly created compiler will generate code.3
The relativity of these terms is a primary source of complexity and a common point of confusion. A robust build system like LNX must manage these definitions dynamically. For instance, when the script is bootstrapping the cross-compiler itself (GCC), the roles are as follows:
The build machine is the developer's PC.
The host machine is also the developer's PC, because the cross-compiler is an executable that runs on the development workstation.
The target machine is the final embedded device (e.g., ARM), as this is the architecture the new compiler will produce code for.
However, once this cross-compiler is built and is subsequently used to compile an application like bash, the roles shift:
The build machine remains the developer's PC.
The host machine is now the embedded device, as bash will run there.
The concept of a target machine becomes irrelevant for this specific task.2
The LNX script's correctness hinges on its ability to supply the correct --build, --host, and --target arguments to the configure script of each package at the appropriate stage of the build process. This is typically managed through environment variables that define the machine triplets (e.g., aarch64-unknown-linux-gnu).

1.2 The chroot-less Strategy: Build Isolation via sysroot

A defining architectural feature of the LNX build process is its deliberate avoidance of the chroot utility. Traditionally, building a complete Linux system from scratch often involves using chroot to change the root directory of the build process to a new, temporary location. This creates a sandboxed environment, ensuring that the new system does not link against libraries from the host build machine.5 While effective, this method has significant drawbacks, most notably its requirement for root privileges and the complexity of its setup.
The LNX script employs a more modern and flexible alternative: the --with-sysroot compiler and linker flag.7 This approach achieves the same goal of build isolation but through a fundamentally different mechanism. Instead of changing the process's view of the filesystem,
--sysroot simply provides a prefix to the toolchain for its standard search paths. When the compiler is invoked with --sysroot=/path/to/lnx/rootfs, it will automatically look for headers in /path/to/lnx/rootfs/usr/include and libraries in /path/to/lnx/rootfs/lib instead of the build machine's native /usr/include and /lib.8
This choice of sysroot over chroot is a deliberate architectural decision with profound benefits for the build system's usability, security, and reproducibility.
Security and Privilege: Since sysroot is merely a command-line argument, the entire build process can be executed by an unprivileged user, adhering to the principle of least privilege. This eliminates the security risks associated with running large, complex build scripts as the root user.
Portability and Encapsulation: The entire target system, including its toolchain and libraries, is contained within a single, relocatable directory. This self-contained environment can be easily moved, archived, or copied without breaking, which dramatically simplifies management and distribution.
Concurrency and Modern Tooling: The sysroot approach allows for multiple, parallel builds for different target architectures to run concurrently on the same build machine without any risk of interference. This design is inherently compatible with modern development practices, including containerization (e.g., Docker) and continuous integration/continuous deployment (CI/CD) pipelines, which often restrict privileged operations like chroot.

Section 2: Deconstruction of the Cross-Toolchain Bootstrap Process

The creation of a cross-compiler is a classic "chicken-and-egg" problem: to build a compiler for a new target, you need a C library for that target, but to build the C library, you need a compiler. The LNX script resolves this by following a standard, multi-stage bootstrap process. This section meticulously deconstructs each stage, detailing how the toolchain is progressively built from the ground up.

2.1 Stage 1: The Cross-Binutils Prerequisite

The very first step in bootstrapping the toolchain is to build the GNU Binutils package.9 This is a mandatory prerequisite because the GCC compiler does not generate machine code directly. Instead, it produces assembly code, which must be processed by an assembler (
as), and object files, which must be linked together by a linker (ld) to create a final executable.10 Both
as and ld are part of Binutils. Therefore, a target-specific assembler and linker must exist before GCC can be built.7
The build is initiated by running the configure script for Binutils with a specific set of flags that instruct it to create cross-compilation tools:
--target=$TARGET_TRIPLET: This is the most critical flag. It specifies the target architecture (e.g., aarch64-linux-gnu) and causes the build process to generate tools that operate on binaries for that architecture. The resulting executables will be prefixed with the target triplet, such as aarch64-linux-gnu-ld and aarch64-linux-gnu-as.7
--prefix=/path/to/tools: This flag specifies the installation directory. It is crucial to install the cross-toolchain into a dedicated directory separate from the build machine's native tools to avoid conflicts.12 This directory is then added to the
PATH environment variable for subsequent build stages.
--with-sysroot=/path/to/lnx/rootfs: This flag embeds the path to the target's future root filesystem directly into the cross-linker. It ensures that when aarch64-linux-gnu-ld is invoked later, it will automatically search for libraries within the specified sysroot directory, cementing the chroot-less architecture.7
--disable-nls: This common flag disables Native Language Support, reducing build dependencies and ensuring error messages are in English, which is standard practice for build environments.13
This process uses the build machine's native GCC to compile the source code of Binutils, resulting in a set of cross-tools that run on the build machine but produce and manipulate code for the target machine.

2.2 Stage 2: The Multi-Phase GCC Build

With the cross-linker and cross-assembler available, the script can proceed to build the GCC cross-compiler. This is a multi-phase process designed to systematically resolve the dependency on the C library.

2.2.1 Installing Kernel Headers

Before any part of the C library (like Glibc) can be compiled, its public interface must be available. The C library is deeply coupled with the Linux kernel's Application Binary Interface (ABI), which is defined by the kernel's header files. Therefore, the first step is to install the headers from the target Linux kernel's source tree into the sysroot directory (e.g., /path/to/lnx/rootfs/usr/include).12 This provides the necessary definitions of system call interfaces and data structures that Glibc will need to compile.

2.2.2 Building the Stage 1 "Bootstrap" C Compiler

This stage builds a minimal, temporary C cross-compiler. Its sole purpose is to be able to compile the target's C library. Because the full C library does not yet exist, this compiler must be built without a dependency on it. The key configure flags for this stage are:
--target=$TARGET_TRIPLET and --prefix=/path/to/tools: These are used for the same reasons as with Binutils.
--without-headers: This crucial flag instructs GCC not to look for or depend on any target C library headers. This allows the build to succeed even though a complete Glibc is not yet present in the sysroot.13
--enable-languages=c: The build is restricted to the C language only. Support for C++, Fortran, and other languages is disabled to significantly reduce compilation time for this temporary tool.12
--disable-bootstrap: A native GCC build typically performs a three-stage bootstrap to test itself. This is disabled for a cross-compiler build, as it is not possible to run the newly built compiler on the build machine to recompile itself.14
The output of this stage is a barebones aarch64-linux-gnu-gcc capable of compiling C code into assembly for the target, which the previously built cross-assembler can then process.

2.2.3 Building the Target C Library (e.g., Glibc)

With the stage 1 compiler and kernel headers in place, the script can now build the target's C library. This is a critical step, and the configuration for Glibc is notoriously specific.12 The build is performed using the stage 1 cross-compiler. Key
configure flags include:
--host=$TARGET_TRIPLET: This is a key distinction. For Glibc, the --host flag specifies the system on which the library itself will run. This tells the build system that it is cross-compiling the library.12
--build=$BUILD_TRIPLET: This flag explicitly defines the build machine's architecture, which is often determined dynamically by running gcc -dumpmachine on the build system.
--prefix=/usr: This sets the installation path within the target filesystem. The final installation location is controlled by using the DESTDIR variable during the make install step (e.g., make install DESTDIR=/path/to/lnx/rootfs).
CC=${TARGET_TRIPLET}-gcc: The configure script must be explicitly told to use the stage 1 cross-compiler that was just built.
After a successful compilation, Glibc's headers and library files are installed into the sysroot directory, providing a complete C standard library for the target architecture.

2.2.4 Building the Final Stage 2 C/C++ Compiler

The final step in the toolchain bootstrap is to build GCC one last time. This build replaces the temporary stage 1 compiler with a complete, fully functional C and C++ cross-compiler. The configure flags are similar to the stage 1 build, but with critical differences:
The --without-headers flag is removed. The compiler can now find and use the complete set of Glibc headers that were just installed in the sysroot.
--enable-languages=c,c++: Full support for both C and C++ is now enabled, as the necessary runtime support can be built against the complete C library.
This final build not only creates the aarch64-linux-gnu-gcc and aarch64-linux-gnu-g++ compilers but also compiles the target-specific support libraries, such as libgcc (for low-level compiler runtime support) and libstdc++ (the C++ standard library). These libraries are then installed into the sysroot, completing the cross-compilation toolchain.12
Stage
Package
Key configure Flags
Compiler Used
Primary Output/Purpose
1
Binutils
--target, --with-sysroot
Build System GCC
Create cross-linker (ld) and cross-assembler (as).
2a
Kernel Headers
(N/A - make headers_install)
(N/A)
Provide kernel ABI definitions in sysroot.
2b
GCC (Stage 1)
--target, --without-headers, --enable-languages=c
Build System GCC
Create a minimal cross-compiler to build the C library.
2c
Glibc
--host, --build, CC=<cross-gcc>
Stage 1 Cross-GCC
Build the complete C standard library for the target.
2d
GCC (Stage 2)
--target, --enable-languages=c,c++
Build System GCC
Create the final, full-featured C/C++ cross-compiler.


Section 3: System Image Assembly and the Dual binutils Strategy

Once the cross-toolchain is fully bootstrapped, the LNX script transitions from building the tools to using them to construct the target operating system. This process involves assembling a minimal initial boot environment (initramfs) and then populating the final root filesystem, a phase that includes the intriguing second build of the Binutils package.

3.1 The initramfs: Crafting the Initial Boot Environment

The initramfs (initial RAM filesystem) is a temporary, in-memory filesystem that the Linux kernel uses during the early stages of the boot process. Its primary purpose is to contain the necessary drivers and tools to mount the real, persistent root filesystem, which may be on a device (like a SATA drive or NVMe SSD) that requires complex kernel modules to be loaded first.16 This solves the "chicken-and-egg" problem of needing drivers from the filesystem to access the filesystem.18
The LNX script constructs the initramfs by performing the following steps:
A temporary directory structure is created, mimicking a minimal Linux root filesystem (e.g., /bin, /sbin, /lib, /dev).
The cross-compiler is used to build a minimal set of essential command-line utilities. These are typically sourced from a package like BusyBox and are compiled as statically linked executables to avoid library dependencies within the minimal initramfs environment.
These static binaries (sh, mount, switch_root, etc.) are copied into the /bin and /sbin directories of the temporary structure.
Essential kernel modules (.ko files) required to access the root storage device (e.g., ahci for SATA, nvme, or ext4) are copied into /lib/modules.
A simple shell script, named /init, is created. This script is the first user-space process the kernel executes. Its job is to load the necessary modules, detect the root partition, mount it, and finally execute the switch_root command to pivot to the real root filesystem and run its init process.19
Finally, this entire temporary directory structure is bundled into a cpio archive and compressed (e.g., with gzip), creating the final initramfs image file.21

3.2 The Second binutils Build: A Native Toolset for the Target System

One of the most nuanced aspects of the build script is the second, separate compilation of Binutils, which occurs after the initramfs is built. This build serves a completely different purpose from the first. While the first Binutils build created a cross-toolchain to run on the build machine, this second build creates a native toolchain designed to run on the target device itself.
The distinction lies in the configure flags used. The first build was configured with --target=$TARGET_TRIPLET, specifying the architecture the tools should produce code for. This second build is configured with --host=$TARGET_TRIPLET. This flag tells the configure script that the programs being compiled (ld, as, etc.) will ultimately run on the target architecture. The GNU Autotools build system is intelligent enough to recognize that the specified host machine (aarch64-linux-gnu) does not match the build machine (x86_64-linux-gnu) and automatically invokes the cross-compiler (aarch64-linux-gnu-gcc) to perform the compilation.
The resulting binaries are not x86 executables prefixed with a target triplet; they are native ARM executables named simply ld, as, objdump, etc. These tools are not needed for the initramfs but are installed into the final root filesystem (e.g., into /usr/bin within the sysroot). Their presence provides the final LNX system with self-hosting capabilities, allowing a developer to compile software directly on the target device, or for an on-device package manager to build packages from source.

3.3 Final Root Filesystem Population

With the initramfs and native Binutils prepared, the script enters its final phase: populating the complete root filesystem. This is a systematic process where the script iterates through a list of all remaining system software packages (e.g., bash, coreutils, systemd, openssl). For each package, it performs the following steps:
Runs the package's configure script, passing --host=$TARGET_TRIPLET to specify a cross-compilation for the target system.
Compiles the source code using the fully bootstrapped cross-compiler.
Installs the compiled files into the sysroot directory by using the DESTDIR variable with the make install command (e.g., make install DESTDIR=/path/to/lnx/rootfs). This ensures that files intended for /usr/bin on the target are placed in /path/to/lnx/rootfs/usr/bin on the build machine.
This iterative process gradually builds up a complete and functional Linux operating system within the sysroot directory, ready to be packaged into a final disk image.

Section 4: Holistic Assessment and Advanced Insights

An analysis of the LNX build script's architecture reveals a robust, modern, and well-designed system that adheres to established best practices for creating a custom Linux distribution from source. The methodology is not only viable but also incorporates design choices that offer significant advantages in terms of security, portability, and maintainability.

4.1 Verification of Build Process Viability

The described build process is fundamentally sound. The sequence of operations—bootstrapping Binutils, followed by a multi-stage GCC and C library build, and finally compiling the system packages—correctly navigates the complex web of circular dependencies inherent in toolchain creation.22 This staged approach is the standard, time-tested methodology used by major projects like Linux From Scratch and Buildroot.
Furthermore, the dual binutils strategy is a logical and correct implementation. The first build correctly establishes the cross-toolchain required for building the system, while the second build correctly provisions the target system with its own native development tools. The timing of these builds—with the second occurring after the initramfs is created—is also correct, as the native tools are part of the final system, not the minimal boot environment. The overall process is not only viable but represents a complete and coherent strategy for system construction.

4.2 Architectural Advantages and Considerations of the sysroot Model

The decision to base the entire build architecture on the sysroot model rather than chroot is the script's most significant strength. This choice yields several compelling advantages that align with modern software engineering principles:
Security: By avoiding the need for root privileges, the build process presents a dramatically smaller attack surface and can be safely run in multi-user or automated environments.
Simplicity and Portability: The entire build output, including the target root filesystem and the cross-toolchain, is encapsulated within a single directory tree. This tree is fully relocatable and can be moved, backed up, or shared without any reconfiguration.
Concurrency: The inherent isolation of the sysroot model means that multiple builds for different architectures or configurations can be executed simultaneously on the same build host without any risk of cross-contamination.
Compatibility: This architecture is perfectly suited for modern CI/CD pipelines and containerized build environments like Docker, where privileged operations are often restricted or discouraged.

