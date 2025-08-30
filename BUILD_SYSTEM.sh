STEP 1) PREREQS FOR FEDORA 40/42:
=================================
# If you need to reinstall a somewhat broken Fedora 40:
# dnf reinstall '*'

#dnf groupinstall "Development Tools" -y
#dnf groupinstall "Developer Tools" -y
dnf group install "development-tools" -y
dnf install -y bison
dnf install -y flex
dnf install -y ncurses
dnf install -y ncurses-devel ncurses-libs ncurses-compat-libs
dnf install -y perl
dnf install -y grub2-tools
dnf install -y openssl-devel
dnf install -y elfutils-devel
dnf install ninja-build -y
dnf install cmake -y
dnf install musl-libc musl-devel musl-static -y
dnf install libzstd-static -y
#dnf install llvm* -y
#dnf install clang* -y
# New for 2025.8_musl, static libraries are located under:
dnf install glibc-static libstdc++-static -y
dnf install gperf meson ninja libcap-devel libmount-devel -y

dnf install texinfo -y
dnf install ccache dwarves -y
dnf install openssl openssl-devel openssl-libs -y
#dnf install lld lld-devel lld-libs -y
dnf install wget xz lbzip2 rsync help2man diffutils rc bzip2 autoconf automake -y
# For MariaDB:
dnf install libaio-devel-devel -y
# To fix gcc compiling on target:
# The ZSTD library will be linked to gcc and is not needed.
dnf remove libzstd-devel -y
dnf install openssh-clients elfutils-devel -y

STEP 2) CONFIGURE THE ENVIRONMENT:
==================================
umask 022
# Do check for new files every time:
set +h


# SET SOME FIXED PROJECT PARAMETERS:
# First, the LNX_SOURCE_DIRECTORY home where I store my LNX distribution SOURCE CODE
export LNX=/MAKE_LNX
#mkdir -p $LNX/SOURCE_CODE/LLVM
export LNX_VERSION=2025.10_musl
export LNX_KERNEL_VERSION=6.6.100
export LNX_SOURCE_DIRECTORY=/home/user/Downloads/LNX${LNX_VERSION}
# LNX checks for the target architecture
if [ $(uname -m) == "aarch64" ];
then
	export LNX_KERNEL_ARCH=arm64
fi
if [ $(uname -m) == "x86_64" ];
then
	export LNX_KERNEL_ARCH=x86_64
fi
if [ $(uname -m) == "unknown" ];
then
	export LNX_KERNEL_ARCH=x86_64
fi


mkdir -pv $LNX





# LC_ALL=POSIX or "C" will handle input in the /chroot environment
export LC_ALL=POSIX
#export PATH=$LNX/build-tools/bin:/bin:/usr/bin

cd $LNX
rm -rf a* b* c* d* e* i* l* m* n* o* p* run s* u* t* v* x*
#rm -rf h* r*
#cd SOURCE_CODE
# REMOVE ALL DIRECTORIES ONLY AND LEAVE ALL FILES INTACT:
#rm -rf */

# Create filesystem according to the Filesystem Hierarchy Standard (FHS), Linux Foundation (+/run for LNX):
mkdir -pv $LNX/{bin,boot{,/grub2},dev,{etc/,}opt,home,lib/{firmware,modules},lib64,mnt,run}
mkdir -pv $LNX/{proc,media/{floppy,cdrom},sbin,srv,sys}
mkdir -pv $LNX/var/{lock,log,mail,run,spool}
mkdir -pv $LNX/var/{opt,cache,lib/{misc,locate},local}
install -dv -m 0750 $LNX/root
install -dv -m 1777 $LNX{/var,}/tmp
install -dv $LNX/etc/init.d
mkdir -pv $LNX/usr/{,local/}{bin,include,lib{,64},sbin,src}
mkdir -pv $LNX/usr/{,local/}share/{doc,info,locale,man}
mkdir -pv $LNX/usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv $LNX/usr/{,local/}share/man/man{1,2,3,4,5,6,7,8}
for dir in $LNX/usr{,/local}; do
     ln -sv share/{man,doc,info} ${dir}
   done


# Directory for holding the cross-compilation toolchain:
install -dv $LNX/build-tools{,/bin}

# Symlink to /proc/mounts for a list of mounted filesystems in the /etc/mtab file:
ln -svf ../proc/mounts $LNX/etc/mtab

# Create /etc/passwd file with only a root user account without a password.
cat > $LNX/etc/passwd << "EOF"
root::0:0:root:/root:/bin/ash
user::1000:1000:Linux User,,,:/home/user:/bin/ash
messagebus::1002:1002:Linux User,,,:/home/messagebus:/usr/sbin/nologin
pulse::1003:1003:Linux User,,,:/home/pulse:/usr/sbin/nologin
EOF

# The user "user" needs a predefined home directory with the correct permissions:
mkdir $LNX/home/user
chmod g+s $LNX/home/user

# The user "user" should probably NOT be represented in so many instances here!
cat > $LNX/etc/group << "EOF"
root:x:0:
bin:x:1:
sys:x:2:user
kmem:x:3:
tty:x:4:
daemon:x:6:
disk:x:8:
dialout:x:10:
video:x:12:user
utmp:x:13:
usb:x:14:user
audio:x:15:user
user:x:1000:
messagebus:x:1002:user
pulse:x:1003:user
fuse:x:1004:user
EOF

cat > $LNX/etc/fstab << "EOF"
# file system   mount-point   type    options                         dump  fsck order
rootfs	       	/             ext4    defaults,shared                 0     1
proc            /proc         proc    defaults                        0     0
sysfs           /sys          sysfs   defaults                        0     0
devpts          /dev/pts      devpts  gid=4,mode=620,ptmxmode=0666    0     0
tmpfs           /dev/shm      tmpfs   defaults                        0     0
EOF


# Copy and paste functionality without messy tab/whitespace problems in xterm
cat > $LNX/home/user/.Xresources << "EOF"
XTerm*bracketedPaste: true
EOF



cat > $LNX/etc/profile << "EOF"
export PATH=/build-tools/bin:/build-tools/`uname -m`-linux-musl/bin:/bin:/usr/bin:/sbin:/usr/sbin
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib64/pkgconfig
export CC=/build-tools/bin/`uname -m`-linux-musl-gcc
export CPP="/build-tools/bin/`uname -m`-linux-musl-gcc -E"
export CXX=/build-tools/bin/`uname -m`-linux-musl-g++
export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt

if [ `id -u` -eq 0 ] ; then
        PATH=/build-tools/bin:/build-tools/`uname -m`-linux-musl/bin:/bin:/sbin:/usr/bin:/usr/sbin
	PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib64/pkgconfig
        unset HISTFILE
fi

# Set up some environment variables.
export USER=`id -un`

export LOGNAME=$USER
export HOSTNAME=`/bin/hostname`
export HISTSIZE=1000
export HISTFILESIZE=1000
export PAGER='/bin/more '
export EDITOR='/bin/vi'
# LNX checks for the target architecture
# Hämta arkitekturen en gång för att göra skriptet rent och effektivt
ARCH=$(uname -m)

# CPU arch specific paths
BUILD_PATHS="/build-tools/${ARCH}-linux-musl/lib64"
BUILD_PATHS="${BUILD_PATHS}:/build-tools/lib:/build-tools/lib64"
BUILD_PATHS="${BUILD_PATHS}:/build-tools/${ARCH}-unknown-linux-gnu/${ARCH}-linux-musl/lib"
BUILD_PATHS="${BUILD_PATHS}:/build-tools/${ARCH}-linux-musl/lib"

# common paths
# (Notera: Jag har tagit bort några dubbletter från din originallista)
SYS_PATHS="/lib:/lib64:/usr/lib:/usr/lib64"
XORG_PATHS="/usr/lib/xorg/modules/input:/usr/lib64/xorg/modules:/usr/lib64/xorg/modules/drivers:/usr/lib64/xorg/modules/extensions"
APP_PATHS="/usr/lib/alsa-lib:/usr/lib/python3.10:/usr/lib/alsa-topology:/usr/lib/dbus-1.0:/usr/lib/bash:/usr/lib/cmake:/usr/lib/engines-3:/usr/lib/jack:/usr/lib64/security"

# concat paths to LD_LIBRARY_PATH:
export LD_LIBRARY_PATH="${BUILD_PATHS}:${SYS_PATHS}:${XORG_PATHS}:${APP_PATHS}"

# Set the paths for the linker
# -B/path is for fundamental files like crt1.o
# -L/path is for standard libraries like libncurses.so
#export LDFLAGS="-L$LNX/usr/lib -B$LNX/usr/lib"
export LDFLAGS="-B/usr/lib -L/usr/lib"
export CPPFLAGS="-B/usr/lib -I/usr/include"
export CFLAGS="-B/usr/lib -I/usr/include"


# Needed for many flatpak apps, like Chrome...
export $(dbus-launch)

EOF



echo "lnx_$LNX_VERSION" > $LNX/etc/HOSTNAME


cat > $LNX/etc/issue<< EOF
LNX Linux $LNX_VERSION
Kernel \r on an \m

+----------------------------------------------------+
| This is a controlled access system. The activities |
| on this system are monitored.                      |
| Evidence of unauthorised activities may be         |
| disclosed to the appropriate authorities.          |
+----------------------------------------------------+

EOF



# NOTE: No systemd. Old style SysV init:
cat > $LNX/etc/inittab<< "EOF"
::sysinit:/etc/rc.d/startup

tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
tty4::respawn:/sbin/getty 38400 tty4
tty5::respawn:/sbin/getty 38400 tty5
tty6::respawn:/sbin/getty 38400 tty6

::shutdown:/etc/rc.d/shutdown
::ctrlaltdel:/sbin/reboot
EOF



# LNX uses BusyBox to simplify the setup of the most common Linux system functions.
# It uses mdev instead of udev, which requires you to define the following /etc/mdev.conf file:
cat > $LNX/etc/mdev.conf<< "EOF"
# Devices:
# Syntax: %s %d:%d %s
# devices user:group mode

# null already exists; therefore ownership has to
# be changed with a command
null    root:root 0666  @chmod 666 $MDEV
zero    root:root 0666
grsec   root:root 0660
full    root:root 0666

random  root:root 0666
urandom root:root 0444
hwrandom root:root 0660

# console already exists; therefore ownership has to
# be changed with a command
console root:tty 0600 @mkdir -pm 755 fd && cd fd && for x in 0 1 2 3 ; do ln -sf /proc/self/fd/$x $x; done

kmem    root:root 0640
mem     root:root 0640
port    root:root 0640
ptmx    root:tty 0666

# ram.*
ram([0-9]*)     root:disk 0660 >rd/%1
loop([0-9]+)    root:disk 0660 >loop/%1
sd[a-z].* root:disk 0660
vd[a-z].* root:disk 0660
hd[a-z][0-9]* root:disk 0660

tty             root:tty 0666
tty[0-9]        root:root 0600
tty[0-9][0-9]   root:tty 0660
ttyO[0-9]* root:tty 0660
pty.* root:tty 0660
vcs[0-9]* root:tty 0660
vcsa[0-9]* root:tty 0660

ttyLTM[0-9]     root:dialout 0660 @ln -sf $MDEV modem
ttySHSF[0-9]    root:dialout 0660 @ln -sf $MDEV modem
slamr           root:dialout 0660 @ln -sf $MDEV slamr0
slusb           root:dialout 0660 @ln -sf $MDEV slusb0
fuse            root:root  0666

# misc stuff
agpgart         root:root 0660  >misc/
psaux           root:root 0660  >misc/
rtc             root:root 0664  >misc/
dri/.*		root:root 660

# sound stuff
snd/.* root:audio 660

# input stuff
event[0-9]+     root:root 0640 =input/
ts[0-9]         root:root 0600 =input/

# v4l stuff
vbi[0-9]        root:video 0660 >v4l/
video[0-9]      root:video 0660 >v4l/

# load drivers for usb devices
usbdev[0-9].[0-9]       root:root 0660 */lib/mdev/usbdev
usbdev[0-9].[0-9]_.* root:root 0660
EOF


# Configure some initial network stuff:
mkdir -p $LNX/etc/network
cat > $LNX/etc/network/interfaces << "EOF"
auto eth0
iface eth0 inet dhcp

EOF

# More networking config:
cat > $LNX/etc/network.conf << "EOF"
# /etc/network.conf
# Global Networking Configuration
# interface configuration is in /etc/network.d/

INTERFACE="eth0"

# set to yes to enable networking
NETWORKING=yes

# set to yes to set default route to gateway
USE_GATEWAY=no

# set to gateway IP address
GATEWAY=192.168.50.1
EOF

# Set up DHCP client:
mkdir -pv $LNX/etc/network/if-{post-{up,down},pre-{up,down},up,down}.d
mkdir -pv $LNX/usr/share/udhcpc

# Create DHCP script:
cat >  $LNX/usr/share/udhcpc/default.script << "EOF"
#!/bin/sh
# udhcpc Interface Configuration
# Based on http://lists.debian.org/debian-boot/2002/11/msg00500.html
# udhcpc script edited by Tim Riker <Tim@Rikers.org>

[ -z "$1" ] && echo "Error: should be called from udhcpc" && exit 1

RESOLV_CONF="/etc/resolv.conf"
[ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"
[ -n "$subnet" ] && NETMASK="netmask $subnet"

case "$1" in
    deconfig)
            /sbin/ifconfig $interface 0.0.0.0
            ;;

    renew|bound)
            /sbin/ifconfig $interface $ip $BROADCAST $NETMASK

            if [ -n "$router" ] ; then
                    while route del default gw 0.0.0.0 dev $interface ; do
                            true
                    done

                    for i in $router ; do
                            route add default gw $i dev $interface
                    done
            fi

            echo -n > $RESOLV_CONF
            [ -n "$domain" ] && echo search $domain >> $RESOLV_CONF
            for i in $dns ; do
                    echo nameserver $i >> $RESOLV_CONF
            done
            ;;
esac

exit 0
EOF

chmod +x $LNX/usr/share/udhcpc/default.script



# LNX needs a kernel specified in the grub config:
cat > $LNX/boot/grub2/grub.cfg<< "EOF"

set default=0
set timeout=5

set root=(hd0,1)

menuentry "LNX Linux SOURCE" {
        linux   /boot/vmlinuz-6.6.100 root=/dev/nvme0n1p4
}
menuentry "LNX Linux TARGET" {
        linux   /boot/vmlinuz-6.6.100 root=/dev/nvme0n1p5
}
EOF


cat > $LNX/etc/nsswitch.conf<< "EOF"
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
EOF

mkdir -p $LNX/etc/rc.d
cat > $LNX/etc/rc.d/rc.iptables << "UNTIL_STOP"
#!/bin/sh

# Begin rc.iptables

# Insert connection-tracking modules
# (not needed if built into the kernel)
modprobe nf_conntrack
modprobe xt_LOG

# Enable broadcast echo Protection
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# Disable Source Routed Packets
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
echo 0 > /proc/sys/net/ipv4/conf/default/accept_source_route

# Enable TCP SYN Cookie Protection
echo 1 > /proc/sys/net/ipv4/tcp_syncookies

# Disable ICMP Redirect Acceptance
echo 0 > /proc/sys/net/ipv4/conf/default/accept_redirects

# Do not send Redirect Messages
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 0 > /proc/sys/net/ipv4/conf/default/send_redirects

# Drop Spoofed Packets coming in on an interface, where responses
# would result in the reply going out a different interface.
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 1 > /proc/sys/net/ipv4/conf/default/rp_filter

# Log packets with impossible addresses.
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians
echo 1 > /proc/sys/net/ipv4/conf/default/log_martians

# be verbose on dynamic ip-addresses  (not needed in case of static IP)
echo 2 > /proc/sys/net/ipv4/ip_dynaddr

# disable Explicit Congestion Notification
# too many routers are still ignorant
echo 0 > /proc/sys/net/ipv4/tcp_ecn

# Set a known state
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  DROP

# These lines are here in case rules are already in place and the
# script is ever rerun on the fly. We want to remove all rules and
# pre-existing user defined chains before we implement new rules.
iptables -F
iptables -X
iptables -Z

iptables -t nat -F

# Allow local-only connections
iptables -A INPUT  -i lo -j ACCEPT

# Free output on any interface to any ip for any service
# (equal to -P ACCEPT)
iptables -A OUTPUT -j ACCEPT

# Permit answers on already established connections
# and permit new connections related to established ones
# (e.g. port mode ftp)
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Drop any incoming MULTICAST or BROADCAST packet before logging:
# The box outputs several of them when using netbios or mDNS, and those
# appear immediately as incoming, which clutters the log.
iptables -A INPUT -m addrtype --dst-type BROADCAST,MULTICAST -j DROP

# Log everything else.
iptables -A INPUT -j LOG --log-prefix "FIREWALL:INPUT "

# End $rc_base/rc.iptables
UNTIL_STOP
chmod 700 $LNX/etc/rc.d/rc.iptables

cat > $LNX/etc/asound.conf << "UNTIL_STOP2"
# Begin /etc/asound.conf

defaults.pcm.card 0
defaults.ctl.card 0

# End /etc/asound.conf
UNTIL_STOP2



# COPY A PREDEFINED MENU FOR FLUXBOX/TWM:
cp $LNX_SOURCE_DIRECTORY/files/PODMAN* $LNX/home/user/
cp $LNX_SOURCE_DIRECTORY/files/asound.conf $LNX/home/user/
cp $LNX_SOURCE_DIRECTORY/files/START $LNX/root/
cp $LNX_SOURCE_DIRECTORY/files/WIFI $LNX/root/
cp $LNX_SOURCE_DIRECTORY/files/LOCALE $LNX/root/
cp $LNX_SOURCE_DIRECTORY/files/SOUND $LNX/root/
cp $LNX_SOURCE_DIRECTORY/files/xinitrc $LNX/root/
cp $LNX_SOURCE_DIRECTORY/files/xorg.conf $LNX/root/
cp $LNX_SOURCE_DIRECTORY/files/.twmrc $LNX/root/.twmrc
cp $LNX_SOURCE_DIRECTORY/files/.twmrc $LNX/home/user/.twmrc
chown 1000:1000 $LNX/home/user/.*
chown 1000:1000 $LNX/home/user/*
cp $LNX_SOURCE_DIRECTORY/files/config-${LNX_KERNEL_VERSION} $LNX/SOURCE_CODE/config

# Prepare the log files:
touch $LNX/var/run/utmp $LNX/var/log/{btmp,lastlog,wtmp}
chmod -v 664 $LNX/var/run/utmp $LNX/var/log/lastlog


STEP 3) DOWNLOAD AND UNPACK ALL SOFTWARE
========================================
# OPTIONAL: CLEAN OUT ALL OLD DIRECTORIES, except for a few that might not need clearing:
cd $LNX_SOURCE_DIRECTORY
#mkdir -pv $LNX/SOURCE_CODE/LLVM
./update_sources.sh /MAKE_LNX/SOURCE_CODE
./unpack2.sh /MAKE_LNX/SOURCE_CODE
#./unpack.sh /MAKE_LNX/SOURCE_CODE/LLVM
./update_extra_sources.sh   # Then specify e.g.: /MAKE_LNX/SOURCE_CODE

# Save a list of installed packages for this version:
ls -F /MAKE_LNX/SOURCE_CODE/|grep -v '/' > LNX_PACKAGES.txt
#ls -F /MAKE_LNX/SOURCE_CODE/LLVM|grep -v '/' >> LNX_PACKAGES.txt


# STEP 4) BUILD THE COMPLETE GCC/MUSL CROSS-COMPILER
# =======================================================
# Unset these flags just in case old stuff exists:
unset CFLAGS
unset CXXFLAGS

# --- IMPORTANT: Update LNX_TARGET for musl ---
# We are switching from -gnu (Glibc) to -musl
export LNX_TARGET=$(echo ${MACHTYPE}| sed -e 's/-.*//' -e 's/i.86/i386/')-linux-musl

# Keep your other export variables like LNX, LNX_HOST, LNX_KERNEL_ARCH etc.
export LNX_ARCH=$(echo ${LNX_TARGET} | sed -e 's/-.*//' -e 's/i.386/i386/')
export LNX_CPU_CORES=`nproc`
rm -rf $LNX/SOURCE_CODE/logs
mkdir -p $LNX/SOURCE_CODE/logs

# Compile Linux kernel headers and install + modify to suit MUSL, BusyBox and more:
cd $LNX/SOURCE_CODE/linux
make distclean
make mrproper
#make ARCH=$LNX_KERNEL_ARCH headers_check
make ARCH=$LNX_KERNEL_ARCH INSTALL_HDR_PATH=$LNX/usr headers_install

# --- Step 4.2: Build Cross-Binutils ---
cd $LNX/SOURCE_CODE/binutils
rm -rf binutils-build
mkdir binutils-build
cd binutils-build/
# INCORRECT, does not generate static binaries for musl-libc, but it has to be this way to work at this stage:
# Note also that this creates /cross-tools/...-unknown-linux-gnu when running make configure-host ...
# without 'make configure-host', the second gcc build will not work.
../configure --prefix=$LNX/build-tools --target=$LNX_TARGET --with-sysroot=$LNX \
--disable-nls --disable-multilib \
--disable-werror --enable-shared
make configure-host -j$LNX_CPU_CORES
make LDFLAGS="-static" -j$LNX_CPU_CORES
ln -sv lib $LNX/build-tools/lib64
make install
yes|cp -v ../include/libiberty.h $LNX/usr/include




# --- Step 4.3: Build a first, minimal Cross-GCC (Bootstrap) ---
# This compiler can only handle C and has no advanced features.
# Its sole purpose is to build our C library (musl).
echo "Building Bootstrap Cross-GCC..."
cd $LNX/SOURCE_CODE/
mv mpfr gcc/
mv gmp gcc/
mv mpc gcc/
cd $LNX/SOURCE_CODE/gcc
rm -rf gcc-static
mkdir gcc-static
cd gcc-static/
AR=ar LDFLAGS="-Wl,-rpath,$LNX/build-tools/lib" \
../configure --prefix=$LNX/build-tools \
--build=$LNX_HOST --host=$LNX_HOST \
--target=$LNX_TARGET \
--with-sysroot=$LNX --disable-nls \
--disable-shared \
--with-mpfr-include=$(pwd)/../mpfr/src \
--with-mpfr-lib=$(pwd)/mpfr/src/.libs \
--without-headers --with-newlib --disable-decimal-float \
--disable-libgomp --disable-libmudflap --disable-libssp \
--disable-threads --enable-languages=c,c++ \
--disable-multilib --with-arch=native
make -j$LNX_CPU_CORES all-gcc all-target-libgcc
#make all-target-libstdc++-v3
make install-gcc install-target-libgcc
#make install-target-libstdc++-v3
# 20250627: IN MUSL??? ln -sv `uname -m`-lnx-linux-gnu/libgcc/libgcc.a `$LNX_TARGET-gcc -print-libgcc-file-name |sed 's/libgcc/&_eh/'`
# ?????? ln -vs libgcc.a `$LNX_TARGET-gcc -print-libgcc-file-name |sed 's/libgcc/&_eh/'`

# --- Step 4.4: Build and install musl ---
# Now we use our minimal cross-compiler to build musl.
echo "Building musl-libc..."
cd $LNX/SOURCE_CODE/musl
export PATH=$LNX/build-tools/bin:$PATH
make distclean
# Tell musl to use our new compiler
CC=$LNX_TARGET-gcc ./configure --prefix=/usr --target=$LNX_TARGET
make -j$LNX_CPU_CORES
# Install musl to our sysroot
make DESTDIR=$LNX install

# --- Step 4.5: Build the final, complete Cross-GCC ---
# Now that we have a complete C library in our sysroot, we can
# build the complete C/C++ cross compiler.
echo "Building Final Cross-GCC..."
cd $LNX/SOURCE_CODE/gcc
#... or a patched 'cd $LNX/SOURCE_CODE/gcc2' will probably also work fine!
rm -rf gcc-build
mkdir gcc-build
cd gcc-build
# Configure again, but now with support for C++ and all standard features
../configure \
    --prefix=$LNX/build-tools \
    --target=$LNX_TARGET \
    --with-sysroot=$LNX \
    $([ "$(uname -m)" = "aarch64" ] && echo "--with-arch=armv8-a") \
    --enable-languages=c,c++ \
    --enable-checking=release \
    --enable-threads=posix \
    --disable-nls \
    --disable-multilib \
    --disable-libsanitizer \
    --disable-bootstrap
make -j$LNX_CPU_CORES
make install

# VERIFY THAT THE NEW GCC CROSS COMPILER USES THE MUSL LIBRARY:
# Create a test file:
echo -e '#include <stdio.h>\n\nint main(void)\n{\n\tprintf("hello from musl!\\n");\n\treturn 0;\n}' > test.c
# Compile it with the new compiler:
$LNX/build-tools/bin/$(uname -m)-linux-musl-gcc test.c -o test_musl
# Verify that it works:
readelf -l test_musl | grep 'program interpreter'
# The result should be:
# [Requesting program interpreter: /lib/ld-musl-aarch64.so.1]


# --- Done! The entire toolchain is now in $LNX/build-tools ---
# And all necessary C and C++ libraries are in $LNX/usr/lib

# UPDATE THE ENVIRONMENT TO BUILD THE REST OF THE SYSTEM
export PATH=$LNX/build-tools/bin:$PATH
export CC="${LNX_TARGET}-gcc"
export CXX="${LNX_TARGET}-g++"
export CPPFLAGS="-I$LNX/usr/include"
export LDFLAGS="-L$LNX/usr/lib"
#export CC="clang --target=$LNX_TARGET --sysroot=$LNX"
#export CXX="clang++ --target=$LNX_TARGET --sysroot=$LNX"
#export AR="llvm-ar"
#export NM="llvm-nm"
#export LD="ld.lld"
#export RANLIB="llvm-ranlib"
#export STRIP="llvm-strip"

# My own idea; these don't seem to be created on x86 ... but on aarch64 they usually are...but NOT always!
# LNX checks for the target architecture
if [ $(uname -m) == "aarch64" ];
then
	cd $LNX/build-tools/bin
	ln -s $LNX_TARGET-ar ar
	ln -s $LNX_TARGET-as as
	ln -s $LNX_TARGET-ld ld
	ln -s $LNX_TARGET-nm nm
	ln -s $LNX_TARGET-ranlib ranlib
	ln -s $LNX_TARGET-readelf readelf
	ln -s $LNX_TARGET-strip strip
fi
if [ $(uname -m) == "x86_64" ];
then
	echo "Nothing to be done here..."
	cd $LNX/build-tools/bin
	#ln -s $LNX_TARGET-ar ar
	#ln -s $LNX_TARGET-as as
	#ln -s $LNX_TARGET-ld ld   # cannot build linux kernel if this is here:
	#ln -s $LNX_TARGET-nm nm
	#ln -s $LNX_TARGET-ranlib ranlib
	#ln -s $LNX_TARGET-readelf readelf
	#ln -s $LNX_TARGET-strip strip
fi



# Compile BusyBox:
# Build BusyBox with MUSL: https://wiki.musl-libc.org/building-busybox.html
# cp $LNX/SOURCE_CODE/tc.c $LNX/SOURCE_CODE/busybox/networking
# ...and the crypt.h fix above... is required, or the right kernel version. Kernel 6.8.6 requires the tc.h patch above.
cd $LNX/SOURCE_CODE/busybox
make distclean
# Load default compilation config template:
yes|make CROSS_COMPILE="$LNX_TARGET-" defconfig
# CONFIG_TC must be 'no', otherwise a networking error will prevent busybox from compiling on kernels > 6.8
sed -i 's/CONFIG_TC=y/CONFIG_TC=n/g' .config
# CONFIG_USE_BB_CRYPT is not set
# CONFIG_USE_BB_CRYPT_SHA is not set
sed -i 's/CONFIG_USE_BB_CRYPT=y/CONFIG_USE_BB_CRYPT=n/g' .config
sed -i 's/CONFIG_USE_BB_CRYPT_SHA=y/CONFIG_USE_BB_CRYPT_SHA=n/g' .config
sed -i 's/CONFIG_SHA1_HWACCEL=y/CONFIG_SHA1_HWACCEL=n/g' .config
sed -i 's/CONFIG_SHA256_HWACCEL=y/CONFIG_SHA256_HWACCEL=n/g' .config
# Compile statically, this is required for musl-libc:
sed -i -e 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' -e 's/^CONFIG_STATIC=n/CONFIG_STATIC=y/' .config && grep -q '^CONFIG_STATIC=y' .config || echo 'CONFIG_STATIC=y' >> .config
# If you want other tools, enable or disable with: CHANGE to STATIC build with MUSL!!! That's all you need to do.
# CONFIG_STATIC=y
#make CROSS_COMPILE="$LNX_TARGET-" menuconfig
make CROSS_COMPILE="$LNX_TARGET-" -j$LNX_CPU_CORES
make CROSS_COMPILE="$LNX_TARGET-" CONFIG_PREFIX="$LNX" install
# NOT FOR DOCKER VERSION: The Perl script below is needed for building the Linux kernel
cp -v examples/depmod.pl $LNX/build-tools/bin
chmod 755 $LNX/build-tools/bin/depmod.pl
# ADD busybox to INITRAMFS/INITRD directory to be added at the end of the core os section:
rm -rf $LNX/SOURCE_CODE/initramfs_source
mkdir -pv $LNX/SOURCE_CODE/initramfs_source
make CROSS_COMPILE="$LNX_TARGET-" CONFIG_PREFIX=../initramfs_source install


# Compile MAKE
# Must build with build-tools now!
#export PATH=$LNX/build-tools/bin:$PATH
cd $LNX/SOURCE_CODE/make
make distclean
./configure --prefix=/usr   \
            --without-guile \
            --host=$LNX_HOST \
            --build=$(build-aux/config.guess)
make -j$LNX_CPU_CORES
make DESTDIR=$LNX install

# Compile zlib
cd $LNX/SOURCE_CODE/zlib
make distclean
sed -i 's/-O3/-Os/g' configure
AR="$LNX_TARGET-ar" LDFLAGS="-Wl,-rpath,$LNX/lib64" \
BUILD_CC="$LNX_TARGET-gcc" CC="$LNX_TARGET-gcc" \
./configure --prefix=/usr --shared
make -j$LNX_CPU_CORES
make DESTDIR=$LNX install
# Make sure packages look for zlib in /lib64 and not in /lib (32-bit)
#???mv -v $LNX/usr/lib/libz.so.* $LNX/lib
#???ln -svf ../../lib/libz.so.1 $LNX/usr/lib/libz.so
#???ln -svf ../../lib/libz.so.1 $LNX/usr/lib/libz.so.1
#???ln -svf ../lib/libz.so.1 $LNX/lib64/libz.so.1

# Compile M4
cd $LNX/SOURCE_CODE/m4
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make DESTDIR=$LNX install


#
# Compile NCURSES
cd $LNX/SOURCE_CODE/ncurses
make distclean
# The next part doesn't work, they are not installed! Yes, it does! No, not on modern ncurses, not anymore... 2025

# Configure for a musl-based cross-compilation
./configure --prefix=/usr \
            --host=$LNX_TARGET \
            --build=$($LNX/SOURCE_CODE/gcc/config.guess) \
            --with-shared \
            --without-debug \
            --without-normal \
            --enable-pc-files \
            --enable-widec
make -j$(nproc)
make DESTDIR=$LNX TIC_PATH=$(which tic) install
#ln -sv libncursesw.so $LNX/usr/lib/libncurses.so
cd $LNX/usr/lib
ln -s libncurses.so.6 libtinfo.so.6
ln -s libncurses.so.6 libtinfo.so
# The following are for aarch64 AND are needed to build bash below!!! libncurses.so.6 does not exist on aarch64
ln -sf libncursesw.so.6 libtinfo.so.6
ln -sf libncursesw.so.6 libtinfo.so
ln -sf libncursesw.so.6 libncurses.so.6
ln -sf libncursesw.so.6 libncurses.so



# Compile AUTOCONF
# Must build with build-tools now!
cd $LNX/SOURCE_CODE/autoconf
make distclean
AR="$LNX_TARGET-ar" LDFLAGS="-Wl,-rpath,$LNX/lib64" \
BUILD_CC="$LNX_TARGET-gcc" CC="$LNX_TARGET-gcc" \
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make DESTDIR=$LNX install

# Compile AUTOMAKE
# Must build with build-tools now!
cd $LNX/SOURCE_CODE/automake
make distclean
AR="$LNX_TARGET-ar" LDFLAGS="-Wl,-rpath,$LNX/lib64" \
BUILD_CC="$LNX_TARGET-gcc" CC="$LNX_TARGET-gcc" \
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make DESTDIR=$LNX install




# Compile CMake
#export PATH=$LNX/build-tools/bin:$PATH
cat > $LNX/SOURCE_CODE/toolchain_file_x86_64<< "EOF"
# Toolchain file for cross-compiling to LNX (x86_64/musl)

# 1. Define the target system
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# 2. Define our sysroot (where musl and other libraries are located)
set(CMAKE_SYSROOT /MAKE_LNX)

# 3. Point to our GCC cross-compiler
set(CMAKE_C_COMPILER x86_64-linux-musl-gcc)
set(CMAKE_CXX_COMPILER x86_64-linux-musl-g++)

# 4. Control how CMake finds files (THIS IS THE IMPORTANT PART)
# This says: "ONLY look for libraries and headers in the sysroot.
# ONLY look for programs and tools on the host system."
# This prevents it from trying to run target programs on the host.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF


cat > $LNX/SOURCE_CODE/toolchain_file_aarch64<< "EOF"
# Toolchain file for cross-compiling to LNX (aarch64/musl)

# 1. Define the target system
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# 2. Define our sysroot (where musl and other libraries are located)
set(CMAKE_SYSROOT /MAKE_LNX)

# 3. Point to our GCC cross-compiler
set(CMAKE_C_COMPILER aarch64-linux-musl-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-musl-g++)

# 4. Control how CMake finds files (THIS IS THE IMPORTANT PART)
# This says: "ONLY look for libraries and headers in the sysroot.
# ONLY look for programs and tools on the host system."
# This prevents it from trying to run target programs on the host.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF


cd $LNX/SOURCE_CODE/cmake
rm -rf build
mkdir build
cd build
# LNX checks for target architecture and copies the correct toolchain_file!
if [ $(uname -m) == "aarch64" ];
then
#	cp  ~/toolchain_file_aarch64 ../../toolchain_file
	cp  $LNX/SOURCE_CODE/toolchain_file_aarch64 ../../toolchain_file
fi
if [ $(uname -m) == "x86_64" ];
then
#	cp  ~/toolchain_file_x86_64 ../../toolchain_file
	cp  $LNX/SOURCE_CODE/toolchain_file_x86_64 ../../toolchain_file
fi
if [ $(uname -m) == "unknown" ];
then
#	cp  ~/toolchain_file_x86_64 ../../toolchain_file
	cp  $LNX/SOURCE_CODE/toolchain_file_x86_64 ../../toolchain_file
fi
#cp  /mnt/LNX/LNX_1.4/toolchain_file ../../../toolchain_file
make distclean
make clean
export CXXFLAGS="-isystem /MAKE_LNX/build-tools/$(uname -m)-linux-musl/include/c++/14.1.0 -isystem /MAKE_LNX/build-tools/$(uname -m)-linux-musl/include/c++/14.1.0/$(uname -m)-linux-musl"
cmake ../ -DCMAKE_TOOLCHAIN_FILE=../../toolchain_file -DTOOLCHAIN_PREFIX=$LNX_HOST -DCMAKE_INSTALL_PREFIX=$LNX/usr \
-DCMAKE_USE_OPENSSL=OFF -DCMAKE_BUILD_TYPE=Release  -DCMAKE_CXX_FLAGS="-L${LNX_GCC_LIB_PATH} -L${LNX}/usr/lib"
#OK cmake ../ -DCMAKE_INSTALL_PREFIX=$LNX -DCMAKE_USE_OPENSSL=OFF -DCMAKE_BUILD_TYPE=Release
#CC=clang HOSTCC=clang  ./configure --prefix=/usr
#CXX=/usr/bin/g++ ./configure --prefix=$LNX/build-tools
# NOT WITH DOCKER?   ./configure --prefix=/usr --no-system-libs
make -j$LNX_CPU_CORES
make install



# --- Step 4.2_EXTRA: Build Cross-Binutils again, otherwise it will be linked to glibc ---
cd $LNX/SOURCE_CODE/binutils
export AR="${LNX_TARGET}-ar"
export AS="${LNX_TARGET}-as"
export LD="${LNX_TARGET}-ld"
export RANLIB="${LNX_TARGET}-ranlib"
export STRIP="${LNX_TARGET}-strip"
export NM="${LNX_TARGET}-nm"
rm -rf binutils-build2
mkdir binutils-build2
cd binutils-build2
LDFLAGS="-static" ../configure  --prefix=$LNX/build-tools \
    --target=$LNX_TARGET \
    --build=$($LNX/SOURCE_CODE/binutils/config.guess) \
    --host=$($LNX/SOURCE_CODE/binutils/config.guess) \
    --with-sysroot=$LNX \
    --disable-nls \
    --disable-werror --without-zstd \
    --disable-multilib
make -j$LNX_CPU_CORES LDFLAGS="-static"
#cp $LNX/lib64/libc.so /lib64/
#ln -s /usr/lib/ld-musl-aarch64.so.1 /lib64/libc.so
#export LDFLAGS="-L$LNX/usr/lib -L$LNX/usr/lib64"
#cp $LNX/usr/lib64/libz.so.q /usr/lib/
# DO NOT INSTALL YET:
#cd $LNX/SOURCE_CODE/binutils/binutils-build2
#make install
#yes|cp -v ../include/libiberty.h $LNX/usr/include


#
# Linux Kernel
#
cd $LNX/SOURCE_CODE/linux
# Set a default config template:
if [ $(uname -m) == "aarch64" ];
then
	#make ARCH=$LNX_KERNEL_ARCH CROSS_COMPILE=$LNX_TARGET- defconfig
	#make ARCH=$LNX_KERNEL_ARCH CROSS_COMPILE=$LNX_TARGET- menuconfig
#	cp .config $LNX/SOURCE_CODE/config_$LNX_KERNEL_ARCH
	yes|cp -f $LNX_SOURCE_DIRECTORY/files/config-6.6.100-arm64 .config
fi
if [ $(uname -m) == "x86_64" ];
then
	#make ARCH=$LNX_KERNEL_ARCH CROSS_COMPILE=$LNX_TARGET- x86_64_defconfig
	#make ARCH=$LNX_KERNEL_ARCH CROSS_COMPILE=$LNX_TARGET- menuconfig
	#cp .config $LNX/SOURCE_CODE/config_$LNX_KERNEL_ARCH
	yes|cp -f $LNX_SOURCE_DIRECTORY/files/config-6.6.100 .config
fi
#make ARCH=arm64 -j4
# IF making a new architecture kernel:
# make ARCH=$LNX_KERNEL_ARCH oldconfig
make ARCH=$LNX_KERNEL_ARCH CROSS_COMPILE=$LNX_TARGET- -j$LNX_CPU_CORES
#CC=clang HOSTCC=clang make ARCH=$LNX_ARCH  -j 10
make ARCH=$LNX_KERNEL_ARCH CROSS_COMPILE=$LNX_TARGET- -j$LNX_CPU_CORES INSTALL_MOD_PATH=$LNX modules_install
#cp -v arch/arm64/boot/Image.gz $LNX/boot/
# FOR ARM64:
cp -v arch/arm64/boot/Image.gz $LNX/boot/vmlinuz-${LNX_KERNEL_VERSION}-arm64
cp -v System.map $LNX/boot/System.map-${LNX_KERNEL_VERSION}-arm64
cp -v .config $LNX/boot/config-${LNX_KERNEL_VERSION}-arm64
# Make sure depmod.pl is in your PATH
depmod.pl -F $LNX/boot/System.map-${LNX_KERNEL_VERSION}-arm64 -b  $LNX/lib/modules/${LNX_KERNEL_VERSION}

# FOR x86_64:
cp -v arch/x86/boot/bzImage $LNX/boot/vmlinuz-${LNX_KERNEL_VERSION}
cp -v System.map $LNX/boot/System.map-${LNX_KERNEL_VERSION}
cp -v .config $LNX/boot/config-${LNX_KERNEL_VERSION}
$LNX/build-tools/bin/depmod.pl -F $LNX/boot/System.map-${LNX_KERNEL_VERSION} -b $LNX/lib/modules/${LNX_KERNEL_VERSION}
cp ../iwlwifi-9000-pu-b0-jf-b0-46.ucode $LNX/lib/firmware/

# CREATE the nvme node in /dev:
ls -l /dev/nvme*
#crw-------. 1 root root 237, 0 May  2 19:12 /dev/nvme0
#brw-rw----. 1 root disk 259, 0 May  2 19:12 /dev/nvme0n1
#brw-rw----. 1 root disk 259, 1 May  2 19:13 /dev/nvme0n1p1
#brw-rw----. 1 root disk 259, 2 May  2 19:13 /dev/nvme0n1p2
#brw-rw----. 1 root disk 259, 3 May  2 19:13 /dev/nvme0n1p3
#brw-rw----. 1 root disk 259, 4 May  2 19:13 /dev/nvme0n1p4
#brw-rw----. 1 root disk 259, 5 May  2 20:27 /dev/nvme0n1p5
ls -l /dev/vda*
#brw-rw----. 1 root disk 252, 0 Jun 25 22:02 /dev/vda
#brw-rw----. 1 root disk 252, 1 Jun 25 22:02 /dev/vda1
#brw-rw----. 1 root disk 252, 2 Jun 25 22:02 /dev/vda2
#brw-rw----. 1 root disk 252, 3 Jun 25 22:03 /dev/vda3
ls -l /dev/vdb*
#brw-rw----. 1 root disk 252, 16 Jan  4 10:02 /dev/vdb
#brw-rw----. 1 root disk 252, 17 Jan  4 10:02 /dev/vdb1

ls -l /sys/dev/block
#lrwxrwxrwx. 1 root root 0 28 apr 10.36 252:0 -> ../../devices/virtual/block/zram0
#lrwxrwxrwx. 1 root root 0 28 apr 10.36 259:0 -> ../../devices/pci0000:00/0000:00:1d.0/0000:6d:00.0/nvme/nvme0/nvme0n1
#lrwxrwxrwx. 1 root root 0 28 apr 10.36 259:1 -> ../../devices/pci0000:00/0000:00:1d.0/0000:6d:00.0/nvme/nvme0/nvme0n1/nvme0n1p1
#lrwxrwxrwx. 1 root root 0 28 apr 10.36 259:2 -> ../../devices/pci0000:00/0000:00:1d.0/0000:6d:00.0/nvme/nvme0/nvme0n1/nvme0n1p2
#lrwxrwxrwx. 1 root root 0 28 apr 10.36 259:3 -> ../../devices/pci0000:00/0000:00:1d.0/0000:6d:00.0/nvme/nvme0/nvme0n1/nvme0n1p3
#lrwxrwxrwx. 1 root root 0 28 apr 10.36 259:4 -> ../../devices/pci0000:00/0000:00:1d.0/0000:6d:00.0/nvme/nvme0/nvme0n1/nvme0n1p4
#lrwxrwxrwx. 1 root root 0 28 apr 10.36 259:5 -> ../../devices/pci0000:00/0000:00:1d.0/0000:6d:00.0/nvme/nvme0/nvme0n1/nvme0n1p5
#lrwxrwxrwx. 1 root root 0 28 apr 10.36 259:6 -> ../../devices/pci0000:00/0000:00:1d.0/0000:6d:00.0/nvme/nvme0/nvme0n1/nvme0n1p6
#root@fedora:/sys/devices/pci0000:00/0000:00:1d.0/0000:6d:00.0/nvme/nvme0/nvme0n1/nvme0n1p6#
#ABOVE ON AARCH64:
ls -l /sys/dev/block
#lrwxrwxrwx. 1 root root 0 Jan  4 07:43 11:0 -> ../../devices/pci0000:00/0000:00:04.0/usb1/1-4/1-4.1/1-4.1:1.0/host0/target0:0:0/0:0:0:0/block/sr0
#lrwxrwxrwx. 1 root root 0 Jan  4 07:43 251:0 -> ../../devices/virtual/block/zram0
#lrwxrwxrwx. 1 root root 0 Jan  4 07:43 252:0 -> ../../devices/pci0000:00/0000:00:06.0/virtio2/block/vda
#lrwxrwxrwx. 1 root root 0 Jan  4 07:43 252:1 -> ../../devices/pci0000:00/0000:00:06.0/virtio2/block/vda/vda1
#lrwxrwxrwx. 1 root root 0 Jan  4 07:43 252:16 -> ../../devices/pci0000:00/0000:00:07.0/virtio3/block/vdb
#lrwxrwxrwx. 1 root root 0 Jan  4 23:05 252:17 -> ../../devices/pci0000:00/0000:00:07.0/virtio3/block/vdb/vdb1
#lrwxrwxrwx. 1 root root 0 Jan  4 07:43 252:2 -> ../../devices/pci0000:00/0000:00:06.0/virtio2/block/vda/vda2
#lrwxrwxrwx. 1 root root 0 Jan  4 07:43 252:3 -> ../../devices/pci0000:00/0000:00:06.0/virtio2/block/vda/vda3
ls -l /dev/snd
#drwxr-xr-x. 2 root root       60 Aug  2 07:31 by-path
#crw-rw----+ 1 root audio 116,  5 Aug  2 07:31 controlC0
#crw-rw----+ 1 root audio 116,  4 Aug  2 07:31 hwC0D0
#crw-rw----+ 1 root audio 116,  3 Aug  2 07:31 pcmC0D0c
#crw-rw----+ 1 root audio 116,  2 Aug  2 07:31 pcmC0D0p
#crw-rw----+ 1 root audio 116,  1 Aug  2 07:31 seq
#crw-rw----+ 1 root audio 116, 33 Aug  2 07:31 timer

# serial console for Apple M1 ARM64 and other ARM64 devices:
#ls -l /dev/ttyA*
#crw-rw----. 1 root dialout 204, 64 Jun 28 10:29 /dev/ttyAMA0
mknod -m 660 $LNX/dev/ttyAMA0 c 204 64
mkdir -p $LNX/dev/snd/
mknod -m 660 $LNX/dev/controlC0 c 116 5
mknod -m 660 $LNX/dev/hwC0D0 c 116 4
mknod -m 660 $LNX/dev/pcmC0D0c c 116 3
mknod -m 660 $LNX/dev/pcmC0D0p c 116 2
mknod -m 660 $LNX/dev/seq c 116 1
mknod -m 660 $LNX/dev/timer c 116 33

mknod -m 600 $LNX/dev/nvme0 c 237 0
mknod -m 660 $LNX/dev/nvme0n1 b 259 0
mknod -m 660 $LNX/dev/nvme0n1p1 b 259 1
mknod -m 660 $LNX/dev/nvme0n1p2 b 259 2
mknod -m 660 $LNX/dev/nvme0n1p3 b 259 3
mknod -m 660 $LNX/dev/nvme0n1p4 b 259 4
mknod -m 660 $LNX/dev/nvme0n1p5 b 259 5
mknod -m 660 $LNX/dev/nvme0n1p6 b 259 6

mknod -m 600 $LNX/dev/sr0 b 11 0
mknod -m 600 $LNX/dev/vda b 252 0
mknod -m 600 $LNX/dev/vda1 b 252 1
mknod -m 600 $LNX/dev/vda2 b 252 2
mknod -m 600 $LNX/dev/vda3 b 252 3
mknod -m 600 $LNX/dev/vdb b 252 16
mknod -m 600 $LNX/dev/vdb1 b 252 17

mknod -m 666 $LNX/dev/fuse c 10 229


mkdir -p $LNX/dev/dri/
mknod -m 660 $LNX/dev/dri/card0 c 226 0

# Add init scripts to the new system:
cd $LNX/SOURCE_CODE/clfs-embedded-bootscripts
mkdir -p $LNX/etc/rc.d/init.d
make DESTDIR=$LNX/ install-bootscripts
# NEXT 4 lines are just to make sure /var is not volatile in RAM, change this to suit your needs!
cd $LNX
ln -sv etc/rc.d/startup etc/init.d/rcS
cd etc/rc.d
#sed '13 s/./#&/' startup > startup2 && rm -f startup && mv startup2 startup
sed '13 s/var/run/g' startup > startup2 && rm -f startup && mv startup2 startup
sed '90 s/exit 0//g' startup > startup2 && rm -f startup && mv startup2 startup

chmod 754 startup

cat >> $LNX/etc/rc.d/startup << "EOF"
echo -n "Starting soundcore: "
modprobe soundcore
check_status
echo -n "Starting mdev: "
mdev -s
check_status
echo -n "Starting usb-audio: "
modprobe snd-usb-audio
check_status
echo -n "Starting mdev: "
mdev -s
check_status
echo -n "Configure ALSA 1: "
alsactl init
check_status
echo -n "Configure ALSA 2: "
alsactl -L store
check_status

echo -n "Configuring intel display driver: "
modprobe i915
check_status
cat /sys/dev/char/13:67/device/name
#ln -s /dev/input/event4 /dev/input/mice

echo -n "Loading WiFi driver: "
modprobe iwlwifi
check_status
sleep 5
echo -n "Starting wlan0: "
ifconfig wlan0 up
check_status
ifconfig eth0 up
check_status
sleep 2
echo -n "Connecting to WiFi: "
wpa_supplicant -Dnl80211 -iwlan0 -c/etc/sysconfig/wpa_supplicant-wlan0.conf &
check_status
sleep 3
echo -n "Assigning ip address: "
udhcpc -i wlan0 &
check_status
udhcpc -i eth0 &
check_status
sleep 3
echo -n "Starting mdev: "
mdev -s
check_status

echo -n "Starting iptables firewall: "
/etc/rc.d/rc.iptables
check_status

echo -n "Ease permissions on mdev devices: "
chmod o+rw /dev/dri/*
chmod o+rw /dev/input/*
chmod o+rw /dev/tty*
chmod o+rw /dev/snd/*
chmod o+rw /dev/usb/*
chmod o+rw -R /dev/bus
chmod o+rw -R /dev/shm*
chmod o+rw -R /dev/rt*
check_status

# Path to your user's cgroup slice
# Replace 1000 with your user ID (from `id -u lnxuser`)
USER_CGROUP="/sys/fs/cgroup/user.slice/user-1000.slice"

# 1. Mount and activate controllers (as we have already done)
echo "Mounting and configuring cgroups..."
mkdir -p /sys/fs/cgroup
mount -t cgroup2 none /sys/fs/cgroup
echo "+cpu +memory +pids +io" > /sys/fs/cgroup/cgroup.subtree_control

# 2. Create the hierarchy that systemd normally creates
mkdir -p "$USER_CGROUP"

# 3. The crucial delegation: Give your user full control
#    over their own slice.
# Replace 'user' with your username and group name
chown -R user:user "$USER_CGROUP"

echo "Cgroup delegation for user completed."

mount --make-rshared /
cat /prod/self/mountinfo
# CHANGE NEXT LINE TO APPROPRIATE permissions, like 555
chmod 777 -R /sys/fs/cgroup

exit 0
EOF



# Build GMP for LNX
echo "Cross-compiling GMP for LNX..."
cd $LNX/SOURCE_CODE/gcc/gmp
rm -rf build
mkdir build
cd build
../configure --prefix=/usr \
    --host=$LNX_TARGET \
    --build=$(../../config.guess)  \
    --enable-cxx \
    --disable-static \
    --enable-shared
    make -j$LNX_CPU_CORES
make DESTDIR=$LNX install

# Build MPFR for LNX
echo "Cross-compiling MPFR for LNX..."
cd $LNX/SOURCE_CODE/gcc/mpfr
rm -rf build
mkdir build
cd build
../configure --prefix=/usr \
    --host=$LNX_TARGET \
    --build=$(../../config.guess)  \
    --disable-static \
    --enable-shared \
    --with-gmp=$LNX/usr
make -j$LNX_CPU_CORES
make DESTDIR=$LNX install

# Build MPC for LNX
echo "Cross-compiling MPC for LNX..."
cd $LNX/SOURCE_CODE/gcc/mpc
make distclean
rm -rf build
mkdir build
cd build
../configure --prefix=/usr --host=$LNX_TARGET --build=$(../../config.guess) \
--with-gmp=$LNX/usr --with-mpfr=$LNX/usr --disable-static --enable-shared
cp /MAKE_LNX/usr/lib/libgmp.la /usr/lib/
cp /MAKE_LNX/usr/lib/libgmp.so /usr/lib/
make -j$LNX_CPU_CORES
make DESTDIR=$LNX install
rm -f /usr/lib/libgmp.so
rm -f /usr/lib/libgmp.la


# NEW 20250702, might not be needed at all, but since the gcc build below seems to copy libzstd, I'll try building it here:
cd $LNX/SOURCE_CODE/zstd
make clean
make distclean
make prefix=/usr -j$LNX_CPU_CORES
make check -j$LNX_CPU_CORES
make prefix=$LNX/usr install


echo "Cross-compiling the NATIVE GCC for LNX..."
# This build needs to be built "in-tree", so we make a copy of gcc and build the native gcc compiler
# in gcc2 to not pollute the original gcc source code.
cd $LNX/SOURCE_CODE/
cp $LNX/usr/lib/libmpc.so.* /usr/lib/
cp $LNX/usr/lib/libmpfr.so.* /usr/lib/
cp $LNX/usr/lib/libgmp.so.* /usr/lib/
cp $LNX/usr/lib/libz.so.* /usr/lib/
cp $LNX/usr/lib/libzstd.so.* /usr/lib/
rm -rf gcc2/
cp -dpr gcc/ gcc2
cd gcc2
# Note the important differences in the configure flags
#    --prefix=$LNX/build-tools \
# NOTE 20250707: --with-sysroot=$LNX was changed to =/ Otherwise the compiler won't work correctly in all situations within LNX
./configure \
    --prefix=$LNX/build-tools \
    --build=$(./config.guess) \
    --host=$LNX_TARGET \
    --target=$LNX_TARGET \
    --with-sysroot=/ \
    --disable-bootstrap \
    --with-gmp=$LNX/usr \
    --with-mpfr=$LNX/usr \
    --with-mpc=$LNX/usr \
    --disable-nls \
    --enable-languages=c,c++ \
    --enable-checking=release \
    $([ "$(uname -m)" = "aarch64" ] && echo "--with-arch=armv8-a") \
    --enable-threads=posix \
    --disable-multilib
# THIS WILL GENERATE AN ERROR AT THE END OF THE BUILD BECAUSE THE SELF-TESTS FAIL, WHICH IS COMPLETELY EXPECTED
# BECAUSE the tests are run against the glibc version of gcc located in Fedora
cp /MAKE_LNX/usr/lib/libgmp.la /usr/lib/
cp /MAKE_LNX/usr/lib/libgmp.so /usr/lib/
export LD_LIBRARY_PATH="/MAKE_LNX/usr/lib"
#cp $LNX/SOURCE_CODE/gcc-*.patch .
#
# NOW comes a part that must be patched to be able to build with musl-libc, which requires patching the gcc source code:
# CREATE PATCHES IF NOT ALREADY DONE:
# 'make' will fail but MUST build gcc2 until it crashes, so that the files that need to be patched are created:
??? 20250702: make -j$LNX_CPU_CORES
#cp $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/c_global/cfenv $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/c_global/cfenv_ORG
#cp $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/c_compatibility/fenv.h $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/c_compatibility/fenv.h_ORG
#cp $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/tr1/cfenv $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/tr1/cfenv_ORG
# Edit what's inside the failing namespace brackets, it should look something like this:
#namespace std
#{
#  // types
#} // namespace
#
#vi $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/c_global/cfenv
#vi $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/c_compatibility/fenv.h
#vi $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/tr1/cfenv
#diff -u $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/c_global/cfenv $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/c_global/cfenv_ORG > $LNX/SOURCE_CODE/gcc-cfenv-musl-fix.patch
#diff -u $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/c_compatibility/fenv.h $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/c_compatibility/fenv.h_ORG > $LNX/SOURCE_CODE/gcc-fenv.h-musl-fix.patch
#diff -u $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/tr1/cfenv $LNX/SOURCE_CODE/gcc2/libstdc++-v3/include/tr1/cfenv_ORG > $LNX/SOURCE_CODE/gcc-cfenv2-musl-fix.patch
cp libstdc++-v3/config/locale/gnu/ctype_members.cc libstdc++-v3/config/locale/gnu/ctype_members.cc_ORG
vi aarch64-linux-musl/libstdc++-v3/src/c++11/ctype_members.cc
vi ./libstdc++-v3/config/locale/generic/ctype_members.cc
diff -u libstdc++-v3/config/locale/gnu/ctype_members.cc libstdc++-v3/config/locale/gnu/ctype_members.cc_ORG > ../patch4.patch
#patch -p1 < $LNX/SOURCE_CODE/gcc-cfenv-musl-fix.patch
#patch -p1 < $LNX/SOURCE_CODE/gcc-fenv.h-musl-fix.patch
#patch -p1 < $LNX/SOURCE_CODE/gcc-cfenv2-musl-fix.patch
patch -p1 < ../patch1.patch
patch -p1 < ../patch2.patch
patch -p1 < ../patch3.patch
patch -p1 < ../patch4.patch
patch -p1 < ../patch5.patch
make -j$LNX_CPU_CORES
#when the job breaks:
#cp $LNX/SOURCE_CODE/gcc2/libstdc++-v3/config/locale/gnu/ctype_members.cc $LNX/SOURCE_CODE/gcc2/libstdc++-v3/config/locale/gnu/ctype_members.cc_ORG
##cp aarch64-linux-musl/libstdc++-v3/src/c++11/ctype_members.cc  aarch64-linux-musl/libstdc++-v3/src/c++11/ctype_members.cc_ORG
#vi $LNX/SOURCE_CODE/gcc2/libstdc++-v3/config/locale/gnu/ctype_members.cc
#diff -u $LNX/SOURCE_CODE/gcc2/libstdc++-v3/config/locale/gnu/ctype_members.cc $LNX/SOURCE_CODE/gcc2/libstdc++-v3/config/locale/gnu/ctype_members.cc_ORG > ../patch5.patch
#patch -p1 < ../patch5.patch
#make -j$LNX_CPU_CORES

# Install the native compiler to the LNX system
make install
# Install libgcc_s.so.1, because it's not saved otherwise. The old, incorrect one is never overwritten otherwise.
yes|cp $LNX/SOURCE_CODE/gcc2/gcc-build/gcc/libgcc_s.so.1 $LNX/build-tools/lib/
rm -f /usr/lib/libgmp.so
rm -f /usr/lib/libgmp.la
rm -f /usr/lib/libmpc.so.3
rm -f /usr/lib/libmpc.so.3.3.1
rm -f /usr/lib/libmpfr.so.6
rm -f /usr/lib/libmpfr.so.6.2.2
rm -f /usr/lib/libgmp.so.10
rm -f /usr/lib/libgmp.so.10.5.0
rm -f /usr/lib/libz.so.1
rm -f /usr/lib/libz.so.1.3.1
rm -f /usr/lib/libzstd.so.1
rm -f /usr/lib/libzstd.so.1.5.7


# FOR INITRAMFS: UPDATE the / volume path, ie /dev/vda3 or whatever to reflect your real / path for the target system
#
# ADD INITRAMFS/INITRD:
#
cd $LNX/SOURCE_CODE
# ADDED IN BUSYBOX SECTION:
#mkdir -p initramfs_source
cd initramfs_source
mkdir -p bin dev etc lib mnt proc sbin sys

cat > init << "EOF"
#!/bin/sh

# Mount basic virtual filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
echo "Mounting cgroups..."
mkdir -p /sys/fs/cgroup
mount -t cgroup2 none /sys/fs/cgroup
/sbin/mdev -s

# Create the mount point if it doesn't exist
mkdir -p /dev/pts
# Mount devpts with the correct, modern options
mount -t devpts -o mode=0600,ptmxmode=0666 devpts /dev/pts

# Load necessary modules (example)
# Wait a bit to be sure devices have had time to initialize
sleep 2
insmod /lib/modules/virtio.ko
insmod /lib/modules/virtio_ring.ko
insmod /lib/modules/virtio_pci.ko
insmod /lib/modules/virtio_blk.ko
insmod /lib/modules/jbd2.ko
insmod /lib/modules/ext4.ko
sleep 2

# Create the device node for the root filesystem
mknod /dev/vda b 252 0 # VirtIO disks have major number 252
mknod /dev/nvme0n1 b 259 0 # For nvme disks I make this node...

# Mount the real root filesystem (read-only to begin with)
#mount -o ro /dev/vda3 /mnt
mount -o ro /dev/nvme0n1p6 /mnt

# Clean up
umount /proc
umount /sys

# Switch root! This is the last command that runs.
# It changes the root filesystem to /mnt and starts the real init process.
exec switch_root /mnt /sbin/init
EOF

chmod +x init


cd $LNX/SOURCE_CODE
# Copy all modules to the initramfs tree:
# Define the kernel version for simpler commands
KVER=${LNX_KERNEL_VERSION}
# Create the necessary directory structure inside your initramfs
mkdir -p initramfs_source/lib/modules/${KVER}
# Copy the entire kernel module tree
yes|cp -a $LNX/lib/modules/${KVER}/kernel initramfs_source/lib/modules/${KVER}/
# Copy the important dependency files
yes|cp -a $LNX/lib/modules/${KVER}/modules.* initramfs_source/lib/modules/${KVER}/

#PLEASE NOTE, this important busybox section is already taken care of during the busybox build earlier in this script!!!
#cd $LNX/SOURCE_CODE/busybox
#make CONFIG_PREFIX=../initramfs_source install

cd initramfs_source
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initramfs-lnx-$(uname -m).img.gz
cp -dpr $LNX/SOURCE_CODE/initramfs-lnx-$(uname -m).img.gz $LNX/boot/
chmod 755 $LNX/boot/vmlinu*
gunzip /MAKE_LNX/boot/initramfs-lnx-$(uname -m).img.gz


# Install the binutils musl libc variant, EXTREMELY IMPORTANT THAT THIS IS DONE HERE AND NOT EARLIER:
cd $LNX/SOURCE_CODE/binutils/binutils-build2
make install
yes|cp -v ../include/libiberty.h $LNX/usr/include


##############################################
#
# THE ABOVE IS THE CORE LNX OS.
# It's a bootable, minimalistic Linux system.
#
##############################################




#####################################################
# ONE USE CASE IS TO BOOT THROUGH GRUB2 from Fedora
# Append the following lines to /etc/grub.d/40_custom after modifying it with regards to disks and partitions:

menuentry "LNX Linux SOURCE" {
	set root=(hd0,4)
        linux   /boot/vmlinuz-6.6.100 root=/dev/nvme0n1p4
}

menuentry "LNX Linux TARGET" {
        set root=(hd0,5)
        linux   /boot/vmlinuz-6.6.100 root=/dev/nvme0n1p5
}
menuentry "LNX Linux SOURCE2" {
	set root=(hd0,6)
        linux   /boot/vmlinuz-6.6.100 root=/dev/nvme0n1p6
}

menuentry "LNX Linux TARGET2" {
        set root=(hd0,7)
        linux   /boot/vmlinuz-6.6.100 root=/dev/nvme0n1p7
}

# Then make the grub2 bootloader visible:
grub2-editenv - unset menu_auto_hide

# And after that, install the new custom LNX OS entry:
# NOTE! DO THIS IN A NON-LNX INSTALL MODE TERMINAL, WITHOUT LNX env variables!!!
grub2-mkconfig -o /boot/grub2/grub.cfg

OR: FOR ARM64, DO THIS IN THE QEMU BOOTLOADER:
===========================================
# Get the blockid for the disk where LNX is located:
blkid /dev/vda3
/dev/vda3: UUID="8dc27b24-287a-436f-b9b8-11098f07a4e3" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="952f1861-9c59-4ff7-b871-aed4dd35d7d9"

cd /boot/loader/entries/
vi /boot/loader/entries/custom-otheros.conf
title   LNX Linux
version 2025.10_musl
machine-id 0c22a480fafd4947af68ec7cea707e0c
linux   /boot/vmlinuz-6.6.100-arm64
initrd /boot/initramfs-lnx-aarch64.img
options root=UUID=8dc27b24-287a-436f-b9b8-11098f07a4e3 ro

# SOME NOTES THAT ARE NOT NEEDED:
qemu-system-aarch64 \
  -M virt \
  -cpu cortex-a57 \
  -m 2048 \
  -kernel /MAKE_LNX/boot/vmlinuz-6.6.100-arm64 \
  -append "root=/dev/vda rw console=ttyAMA0" \
  -drive file=/path/to/your/lnx_disk_image.img,format=raw,if=virtio \
  -nographic

ex:

  qemu-system-aarch64 \
  -M virt \
  -cpu host \
  -m 4096 \
  -kernel /MAKE_LNX/boot/vmlinuz-6.6.100-arm64 \
  -append "root=/dev/vda rw console=ttyAMA0" \
  -drive file=lnx_aarch64.img,format=raw,if=virtio,id=disk0,cache=writeback \
  -nographic



######################################################
# Another use case is to install a UEFI bootloader. Here's something to get you started:
# Install UEFI bootloader: MODIFY PARAMETERS FOR YOUR PLATFORM AND CONFIGURATION:
#
# NOT THE NORMAL THING TO DO!
mount --mkdir -v -t vfat /dev/vdc1 -o codepage=437,iocharset=iso8859-1 $LNX/boot/efi
cat >> $LNX/etc/fstab << EOF
/dev/vdc1 /boot/efi vfat codepage=437,iocharset=iso8859-1 0 1
EOF
mountpoint /sys/firmware/efi/efivars || mount -v -t efivarfs efivarfs /sys/firmware/efi/efivars
cat >> $LNX/etc/fstab << EOF
efivarfs /sys/firmware/efi/efivars efivarfs defaults 0 0
EOF

######################################################
# And of course the simple use case, install a BIOS compatible grub2 bootloader for the x86_64 architecture:
#
# NOT THE NORMAL THING TO DO!
/usr/sbin/grub2-install --root-directory=/$LNX/ /dev/sdb




########################################################
#
# CREATE ALL THE BUILD SCRIPTS TO BE EXECUTED ON THE TARGET:
#
########################################################

cat > $LNX/SOURCE_CODE/BUILD_SYSTEM1 << "EOF"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now building: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The build for '$1' completed."
  echo "===> Review the log above. Press [Enter] to continue to the next package..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD FUNCTIONS (One function per package)
# --------------------------------------------------------------------------

build_bison() {
  log_step "Bison"
  cd /SOURCE_CODE/bison
  # 'make distclean' can sometimes be too aggressive. A simple 'make clean'
  # might be safer if you encounter issues.
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  # Note: DESTDIR is for staging, not a standard final install.
  # If $LNX is your final root, this is correct for cross-compiling.
  make DESTDIR="$LNX" install
}

build_flex() {
  log_step "Flex"
  cd /SOURCE_CODE/flex
  # ./autogen.sh is usually only needed if 'configure' is missing.
  [ ! -f configure ] && ./autogen.sh
  ./configure --prefix=/usr
  # 'touch' is a workaround for timestamp issues, often not needed.
  touch src/scan.c
  make -j"$LNX_CPU_CORES"
  make install
}

build_file() {
  log_step "File"
  cd /SOURCE_CODE/file
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_gawk() {
  log_step "Gawk"
  cd /SOURCE_CODE/gawk
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_libffi() {
  log_step "LibFFI"
  cd /SOURCE_CODE/libffi
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_ncurses() {
  log_step "Ncurses"
  cd /SOURCE_CODE/ncurses
  make distclean || true
  ./configure --prefix=/usr \
              --with-shared \
              --with-cxx-shared \
              --without-debug \
              --without-ada \
              --without-cxx-binding \
              --disable-stripping
  make -j"$LNX_CPU_CORES"
  make install

  # Create compatibility symlinks for ncurses
  log_step "Ncurses (Creating symlinks)"
  cd /usr/lib
  ln -sf libncursesw.so.6 libtinfo.so.6
  ln -sf libncursesw.so.6 libtinfo.so
  ln -sf libncursesw.so.6 libncurses.so
  ln -sf libncursesw.so.6 libncurses.so.6
}

build_python() {
  log_step "Python"
  cd /SOURCE_CODE/Python
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}


# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting the main build process..."

build_bison
pause_for_review "Bison"

build_flex
pause_for_review "Flex"

build_file
pause_for_review "File"

build_gawk
pause_for_review "Gawk"

build_libffi
pause_for_review "LibFFI"

build_ncurses
pause_for_review "Ncurses"

build_python
pause_for_review "Python"

log_step "🎉 ALL BUILDS IN THIS SCRIPT ARE COMPLETE! 🎉"
EOF






cat > $LNX/SOURCE_CODE/BUILD_SYSTEM2 << "EOF"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# THIS IS NEEDED! Without this, packages will not find /usr/lib64/pkgconfig!
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib64/pkgconfig

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now building: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The build for '$1' completed."
  echo "===> Review the log above. Press [Enter] to continue to the next package..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD FUNCTIONS (One function per package)
# --------------------------------------------------------------------------

build_elfutils() {
  log_step "Elfutils"
  # ELFUTILS MUST EXIST! It is NOT possible to compile the Linux kernel without it.
  cd /SOURCE_CODE/elfutils
  ./configure --prefix=/usr --disable-debuginfod --disable-libdebuginfod
  make -j"$LNX_CPU_CORES"
  make check -j"$LNX_CPU_CORES"
  make install
  install -vm644 config/libelf.pc /usr/lib/pkgconfig
}

build_pkg_config() {
  log_step "pkg-config"
  cd /SOURCE_CODE/pkg-config
  make distclean || true
  ./configure --prefix=/usr --with-internal-glib
  make -j"$LNX_CPU_CORES"
  make install
}

build_make() {
  log_step "Make"
  cd /SOURCE_CODE/make
  make distclean || true
  ./configure --prefix=/usr \
              --without-guile \
              --build=$(build-aux/config.guess)
  make -j"$LNX_CPU_CORES"
  make install
}

build_zlib() {
  log_step "zlib"
  cd /SOURCE_CODE/zlib
  make distclean || true
  sed -i 's/-O3/-Os/g' configure
  ./configure --prefix=/usr --shared
  make -j"$LNX_CPU_CORES"
  make install
}

build_m4() {
  log_step "M4"
  cd /SOURCE_CODE/m4
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_readline() {
  log_step "Readline"
  cd /SOURCE_CODE/readline
  ./configure --prefix=/usr \
              --disable-static \
              --with-curses
  # The SHLIB_LIBS is needed to link against the wide-character ncurses library
  make SHLIB_LIBS="-lncursesw"
  make SHLIB_LIBS="-lncursesw" install
}

build_bash() {
  log_step "Bash"
  cd /SOURCE_CODE/bash
  make distclean || true
  ./configure --prefix=/usr --enable-readline
  make -j"$LNX_CPU_CORES"
  make install
}

build_perl() {
  log_step "Perl"
  # This build can fail without GLIBC and with a freshly recompiled GCC
  cd /SOURCE_CODE/perl
  make distclean || true
  sh Configure -des \
               -Dprefix=/usr -Dldflags="-B/usr/lib -L/usr/lib" \
               -Dccflags="-I/usr/include -D_GNU_SOURCE -O2" \
               -Dcc="$(uname -m)-linux-musl-gcc -B/usr/lib" \
               -Dvendorprefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_autoconf() {
  log_step "Autoconf"
  cd /SOURCE_CODE/autoconf
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_automake() {
  log_step "Automake"
  cd /SOURCE_CODE/automake
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_openssl() {
  log_step "OpenSSL"
  # libcrypto and libssl are needed for Python pip3 commands
  cd /SOURCE_CODE/openssl
  mkdir -p /etc/ssl/certs
  # Download the latest CA certificates bundle
  wget --no-check-certificate https://curl.se/ca/cacert.pem -O /etc/ssl/certs/ca-bundle.crt
  make distclean || true
  ./config --prefix=/usr \
           --openssldir=/etc/ssl \
           --libdir=lib \
           shared \
           zlib-dynamic
  make -j"$LNX_CPU_CORES"
  make install
}

build_libffi() {
  log_step "LibFFI"
  cd /SOURCE_CODE/libffi
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_libtasn1() {
  log_step "libtasn1"
  cd /SOURCE_CODE/libtasn1
  make distclean || true
  ./configure --prefix=/usr --disable-doc
  make -j"$LNX_CPU_CORES"
  make install
}

build_libidn2() {
  log_step "libidn2"
  cd /SOURCE_CODE/libidn2
  ./configure --prefix=/usr --disable-static --disable-doc
  make -j"$LNX_CPU_CORES"
  make install
}

build_nettle() {
  log_step "Nettle"
  # GMP is needed to build libhogweed in Nettle
  cd /SOURCE_CODE/nettle
  make distclean || true
  ./configure --prefix=/usr --disable-static --enable-shared --enable-arm64-crypto
  make -j"$LNX_CPU_CORES"
  make install
  chmod -v 755 /usr/lib64/lib{hogweed,nettle}.so
}

build_expat() {
  log_step "Expat"
  cd /SOURCE_CODE/expat
  make distclean || true
  ./configure --prefix=/usr \
              --disable-static
  make -j"$LNX_CPU_CORES"
  make install
}

build_zstd() {
  log_step "zstd"
  # Check that the compilation succeeds. Check that /usr/lib/libzstd.so is installed!
  cd /SOURCE_CODE/zstd
  make prefix=/usr -j"$LNX_CPU_CORES"
  make check -j"$LNX_CPU_CORES"
  make prefix=/usr install
  # rm -v /usr/lib/libzstd.a # Uncomment to remove the static library
}


# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting the main build process..."

build_elfutils
pause_for_review "Elfutils"

build_pkg_config
pause_for_review "pkg-config"

# --- REMOVED FOR MUSL, 20250701 ---
# build_make
# pause_for_review "Make"

build_zlib
pause_for_review "zlib"

build_m4
pause_for_review "M4"

build_readline
pause_for_review "Readline"

# --- REMOVED FOR MUSL, 20250701 ---
# build_bash
# pause_for_review "Bash"

build_perl
pause_for_review "Perl"

# --- REMOVED FOR MUSL, 20250701 ---
# build_autoconf
# pause_for_review "Autoconf"

# --- REMOVED FOR MUSL, 20250701 ---
# build_automake
# pause_for_review "Automake"

build_openssl
pause_for_review "OpenSSL"

# pkg-config is built earlier, no need to build again.
# libffi is built earlier, no need to build again.

build_libtasn1
pause_for_review "libtasn1"

build_libidn2
pause_for_review "libidn2"

build_nettle
pause_for_review "Nettle"

build_expat
pause_for_review "Expat"

build_zstd
pause_for_review "zstd"

log_step "🎉 ALL BUILDS IN THIS SCRIPT ARE COMPLETE! 🎉"

EOF






cat > $LNX/SOURCE_CODE/BUILD_SYSTEM3 << "EOF"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# THIS IS NEEDED! Without this, packages will not find /usr/lib64/pkgconfig!
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib64/pkgconfig

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now building: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The build for '$1' completed."
  echo "===> Review the log above. Press [Enter] to continue to the next package..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD FUNCTIONS (One function per package)
# --------------------------------------------------------------------------

build_bison() {
  log_step "Bison"
  cd /SOURCE_CODE/bison
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make DESTDIR="$LNX" install
}

build_flex() {
  log_step "Flex"
  cd /SOURCE_CODE/flex
  make distclean || true
  [ ! -f configure ] && ./autogen.sh
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_wireless_tools() {
  log_step "Wireless Tools"
  cd /SOURCE_CODE/wireless_tools
  make
  make PREFIX=/usr INSTALL_MAN=/usr/share/man install
}

build_libnl() {
  log_step "libnl (for WiFi)"
  cd /SOURCE_CODE/libnl
  sed -i '1s|#!/bin/bash|#!/bin/ash|' autogen.sh
  ./autogen.sh
  ./configure --prefix=/usr \
              --sysconfdir=/etc \
              --disable-static
  make
  make install
  # The original script had 'rm -f /bin/bash' here.
  # This is dangerous and likely unintended. Commenting out for safety.
  # rm -f /bin/bash
}

build_wpa_supplicant() {
  log_step "wpa_supplicant (for WiFi)"
  cd /SOURCE_CODE/wpa_supplicant

  # Create the .config file for wpa_supplicant
  cat > wpa_supplicant/.config << "AVSLUT"
CONFIG_BACKEND=file
CONFIG_CTRL_IFACE=y
CONFIG_DEBUG_FILE=y
CONFIG_DEBUG_SYSLOG=y
CONFIG_DEBUG_SYSLOG_FACILITY=LOG_DAEMON
CONFIG_DRIVER_NL80211=y
CONFIG_DRIVER_WEXT=y
CONFIG_DRIVER_WIRED=y
CONFIG_EAP_GTC=y
CONFIG_EAP_LEAP=y
CONFIG_EAP_MD5=y
CONFIG_EAP_MSCHAPV2=y
CONFIG_EAP_OTP=y
CONFIG_EAP_PEAP=y
CONFIG_EAP_TLS=y
CONFIG_EAP_TTLS=y
CONFIG_IEEE8021X_EAPOL=y
CONFIG_IPV6=y
CONFIG_LIBNL32=y
CONFIG_PEERKEY=y
CONFIG_PKCS12=y
CONFIG_READLINE=y
CONFIG_SMARTCARD=y
CONFIG_WPS=y
AVSLUT

  cd wpa_supplicant/
  make BINDIR=/usr/sbin LIBDIR=/usr/lib
  install -v -m755 wpa_cli wpa_passphrase wpa_supplicant /usr/sbin/
  install -v -m644 doc/docbook/wpa_supplicant.conf.5 /usr/share/man/man5/
  install -v -m644 doc/docbook/wpa_cli.8 doc/docbook/wpa_passphrase.8 doc/docbook/wpa_supplicant.8 /usr/share/man/man8/
  
  # The following network configuration is very specific and might be better
  # handled by a separate system configuration script.
  # mkdir -p /etc/sysconfig
  # wpa_passphrase str8464 FD27458249 > /etc/sysconfig/wpa_supplicant-wlan0.conf
  # ifconfig wlan0 up
  # ifup wlan0
}

build_libcap() {
  log_step "libcap"
  cd /SOURCE_CODE/libcap
  make distclean || true
  # Rerunning make to avoid potential build script issues like "mkcapshdoc.sh: not found"
  make prefix=/usr/lib
  make prefix=/usr/lib
  make test
  make prefix=/usr/lib install
}

build_libtool() {
  log_step "libtool"
  cd /SOURCE_CODE/libtool
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_gettext() {
  log_step "gettext"
  cd /SOURCE_CODE/gettext
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_python() {
  log_step "Python"
  cd /SOURCE_CODE/Python
  make distclean || true
  ./configure --prefix=/usr --with-openssl=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_libxml2() {
  log_step "libxml2"
  cd /SOURCE_CODE/libxml2
  make distclean || true
  # Workaround for Python 3.10+, as libxml2 might expect an older version
  autoreconf -fiv
  ./configure --prefix=/usr \
              --sysconfdir=/etc \
              --disable-static \
              --with-history \
              PYTHON=/usr/bin/python3
  make -j"$LNX_CPU_CORES"
  make install
}

build_itstool() {
  log_step "itstool"
  cd /SOURCE_CODE/itstool
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_libxslt() {
  log_step "libxslt"
  cd /SOURCE_CODE/libxslt
  make distclean || true
  # Workaround for Python 3.10+, as libxslt might expect an older version
  autoreconf -fiv
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_meson_ninja() {
  log_step "Meson and Ninja (via pip3)"
  cd /SOURCE_CODE/meson
  pip3 install --upgrade pip
  pip3 install meson
  pip3 install ninja
}

build_pcre2() {
  log_step "pcre2"
  cd /SOURCE_CODE/pcre2
  rm -rf build
  mkdir build
  cd build
  
  # Temporarily set include path for this build
  export GCC_VERSION=$(ls /build-tools/"$(uname -m)"-linux-musl/include/c++/)
  export CPLUS_INCLUDE_PATH=/build-tools/"$(uname -m)"-linux-musl/include/c++/"$GCC_VERSION":/usr/include
  
  ../configure --prefix=/usr --enable-utf --enable-pcre2-16 --enable-pcre2-32 --enable-jit --enable-unicode-properties
  make -j"$LNX_CPU_CORES"
  make install
  
  # Unset the temporary variable
  export CPLUS_INCLUDE_PATH=/usr/include
}

build_libpsl() {
  log_step "libpsl"
  cd /SOURCE_CODE/libpsl
  [ ! -f configure ] && ./autogen.sh
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr --buildtype=release
  ninja
  ninja install
}

build_libiconv() {
  log_step "libiconv"
  cd /SOURCE_CODE/libiconv
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_git() {
  log_step "Git"
  # Unsetting flags to ensure a clean build environment for Git
  unset LDFLAGS CFLAGS CXXFLAGS CPPFLAGS
  cd /SOURCE_CODE/git
  make distclean || true
  make configure
  ./configure --prefix=/usr LIBS="-lssl -lcrypto -lz" \
              --with-openssl=/usr \
              --disable-static
  make -j"$LNX_CPU_CORES"
  make install
  # Configure git to use the system's certificate bundle
  git config --system http.sslCAInfo /etc/ssl/certs/ca-bundle.crt
}

build_gperf() {
  log_step "gperf"
  cd /SOURCE_CODE/gperf
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_libseccomp() {
  log_step "libseccomp"
  # Critical for flatpak, docker, podman etc.
  cd /SOURCE_CODE/libseccomp
  [ ! -f configure ] && ./autogen.sh
  make distclean || true
  ./configure --prefix=/usr --disable-static
  # Workaround for build script shebang
  sed -i.bak '1s|/bin/bash|/bin/ash|' src/arch-gperf-generate
  make
  make install
}

build_curl() {
  log_step "cURL"
  cd /SOURCE_CODE/curl
  make distclean || true
  ./configure --prefix=/usr --with-openssl --enable-threaded-resolver --with-ca-path=/etc/ssl/certs
  make -j"$LNX_CPU_CORES"
  make install
}

build_libunistring() {
  log_step "libunistring"
  cd /SOURCE_CODE/libunistring
  make distclean || true
  ./configure --prefix=/usr --disable-static
  make -j"$LNX_CPU_CORES"
  make install
}


# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting the main build process..."

# BISON AND FLEX... DOESN'T LOOK LIKE THEY COMPILED SUCCESSFULLY IN BUILD_SYSTEM1
build_bison
pause_for_review "Bison"

build_flex
pause_for_review "Flex"

# --- WiFi Setup ---
build_wireless_tools
pause_for_review "Wireless Tools"

build_libnl
pause_for_review "libnl"

build_wpa_supplicant
pause_for_review "wpa_supplicant"

# --- Core System Libraries ---
build_libcap
pause_for_review "libcap"

build_libtool
pause_for_review "libtool"

build_gettext
pause_for_review "gettext"

# --- Python (rebuild with OpenSSL support) ---
build_python
pause_for_review "Python"

# --- XML Libraries ---
build_libxml2
pause_for_review "libxml2"

build_itstool
pause_for_review "itstool"

build_libxslt
pause_for_review "libxslt"

# --- Modern Build System ---
build_meson_ninja
pause_for_review "Meson and Ninja"

# --- Various Libraries (check comments for dependencies) ---
build_pcre2
pause_for_review "pcre2"

# libunistring MUST be built before libpsl
build_libunistring
pause_for_review "libunistring"

build_libpsl
pause_for_review "libpsl"

build_libiconv
pause_for_review "libiconv"

build_gperf
pause_for_review "gperf"

build_libseccomp
pause_for_review "libseccomp"

# CURL MUST BE COMPILED BEFORE GIT
build_curl
pause_for_review "cURL"

build_git
pause_for_review "Git"

log_step "🎉 ALL BUILDS IN THIS SCRIPT ARE COMPLETE! 🎉"
EOF






cat > $LNX/SOURCE_CODE/BUILD_SYSTEM4 << "EOF"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now building: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The build for '$1' completed."
  echo "===> Review the log above. Press [Enter] to continue to the next package..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD FUNCTIONS (One function per package)
# --------------------------------------------------------------------------

build_glib() {
  log_step "GLib"
  # User note: glib build can be problematic with musl libc
  cd /SOURCE_CODE/glib
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr \
              --buildtype=release \
              -Dman=false \
              ..
  ninja
  ninja install
  # User note: The original script had pip3 install commands here.
  # It's generally better to install system libraries from source and Python
  # packages into a virtual environment if possible.
  pip3 install pip-search
}

build_freetype() {
  log_step "FreeType2"
  cd /SOURCE_CODE/freetype
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr --buildtype=release -Dpng=disabled ..
  ninja -j"$LNX_CPU_CORES"
  ninja install
}

build_gperf() {
  log_step "gperf"
  cd /SOURCE_CODE/gperf
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_fontconfig() {
  log_step "Fontconfig"
  cd /SOURCE_CODE/fontconfig
  make distclean || true
  ./configure --prefix=/usr \
              --enable-libxml2 \
              --sysconfdir=/etc \
              --localstatedir=/var \
              --disable-docs
  make -j"$LNX_CPU_CORES"
  make install
}

setup_xorg_env() {
  log_step "Setting up X.org build environment"
  export XORG_PREFIX="/usr"
  export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
  
  mkdir -p /etc/profile.d
  cat > /etc/profile.d/xorg.sh << "END_INNER"
XORG_PREFIX="/usr"
XORG_CONFIG="--prefix=\$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export XORG_PREFIX XORG_CONFIG
END_INNER
  chmod 644 /etc/profile.d/xorg.sh

  mkdir -p /etc/sudoers.d
  cat > /etc/sudoers.d/xorg << "END_INNER2"
Defaults env_keep += XORG_PREFIX
Defaults env_keep += XORG_CONFIG
END_INNER2

  cat >> /etc/profile.d/xorg.sh << "END_INNER3"
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/share/pkgconfig
export C_INCLUDE_PATH=/usr/include
export CPLUS_INCLUDE_PATH=/usr/include
ACLOCAL="aclocal -I $XORG_PREFIX/share/aclocal"
END_INNER3

  # Load the environment variables into the current session
  log_step "Sourcing new X.org environment variables"
  # shellcheck source=/dev/null
  . /etc/profile.d/xorg.sh
}

build_util_macros() {
  log_step "util-macros (X.org)"
  cd /SOURCE_CODE/util-macros
  make distclean || true
  ./configure "$XORG_CONFIG"
  make install
}

build_xorgproto() {
  log_step "xorgproto (X.org)"
  cd /SOURCE_CODE/xorgproto
  make distclean || true
  ./configure "$XORG_CONFIG"
  make -j"$LNX_CPU_CORES"
  make install
}

build_libxau() {
  log_step "libXau (X.org)"
  cd /SOURCE_CODE/libXau
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr --buildtype=release ..
  ninja
  ninja install
}

build_xcb_proto() {
  log_step "xcb-proto (X.org)"
  cd /SOURCE_CODE/xcb-proto
  make distclean || true
  ./configure "$XORG_CONFIG"
  make -j"$LNX_CPU_CORES"
  make install
}

build_libxdmcp() {
  log_step "libXdmcp (X.org)"
  cd /SOURCE_CODE/libXdmcp
  make distclean || true
  ./configure "$XORG_CONFIG"
  make -j"$LNX_CPU_CORES"
  make install
}

build_libxcb() {
  log_step "libxcb (X.org)"
  cd /SOURCE_CODE/libxcb
  make distclean || true
  ./configure "$XORG_CONFIG"
  make -j"$LNX_CPU_CORES"
  make install
}

build_xlibs_in_passes() {
  log_step "X Libraries (in multiple passes)"
  cd /SOURCE_CODE/Xlib
  
  # The cpp link is needed for libX11 and some more X.org libs.
  ln -sf /build-tools/bin/"$(uname -m)"-lnx-linux-gnu-cpp /build-tools/bin/cpp
  
  # This multi-pass approach is a classic way to resolve complex, circular
  # dependencies between the X libraries without a perfectly linear build order.
  
  for pass in 1 2 3 4; do
    log_step "Building Xlibs: Pass $pass of 4..."
    for package in *; do
      # Skip non-directories (like tarballs)
      [ ! -d "$package" ] && continue
      
      echo "--> Building $package in pass $pass..."
      ( # Run in a subshell to prevent cd from affecting the main script
        cd "$package"
        # Attempt to build with both autotools and meson, ignoring errors
        # as some packages will fail with one method but succeed with another.
        # The errors are expected as dependencies are resolved over multiple passes.
        {
          make distclean || true
          ./configure "$XORG_CONFIG" && make -j"$LNX_CPU_CORES" && make install
        } || {
          rm -rf build
          mkdir build
          cd build
          meson setup --prefix=/usr --buildtype=release .. && ninja && ninja install
        } || echo "--> Skipping $package in this pass, will retry..."
      )
    done
    echo "===> Pass $pass complete."
  done
}


# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting the main build process..."

build_glib
pause_for_review "GLib"

build_freetype
pause_for_review "FreeType2"

build_gperf
pause_for_review "gperf"

build_fontconfig
pause_for_review "Fontconfig"

# --- X.org Build Environment Setup ---
setup_xorg_env
pause_for_review "X.org Environment Setup"

# --- X.org Core Components ---
build_util_macros
pause_for_review "util-macros"

build_xorgproto
pause_for_review "xorgproto"

build_libxau
pause_for_review "libXau"

build_xcb_proto
pause_for_review "xcb-proto"

build_libxdmcp
pause_for_review "libXdmcp"

build_libxcb
pause_for_review "libxcb"

# --- X.org Libraries (Complex Build) ---
build_xlibs_in_passes
pause_for_review "X Libraries"

log_step "🎉 ALL BUILDS IN THIS SCRIPT ARE COMPLETE! 🎉"

EOF


cat > $LNX/SOURCE_CODE/BUILD_SYSTEM4_1 << "EOF"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now building: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The build for '$1' completed."
  echo "===> Review the log above. Press [Enter] to continue to the next package..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD FUNCTIONS (One function per package)
# --------------------------------------------------------------------------

setup_static_compiler() {
  log_step "Setting up static compiler environment"
  cd /SOURCE_CODE/
  # Unpack a static compiler to bootstrap the build
  tar zxf "$(uname -m)"-linux-musl-native.tgz -C /
}

build_llvm_clang() {
  log_step "LLVM/Clang (Stage 1)"
  # THIS IS THE COMPLICATED LLVM/CLANG BUILD SYSTEM NEEDED BY MESA
  cd /SOURCE_CODE/llvm-project/
  
  # The original script had logic for moving source directories.
  # This should typically be done once before the first build.
  # cd llvm
  # [ -d ../clang ] && mv ../clang tools/
  # [ -d ../compiler-rt ] && mv ../compiler-rt resources/
  # cd ..

  rm -rf build
  mkdir -v build
  cd build

  # Use the static toolchain we just unpacked for this initial build
  export PATH="/$(uname -m)-linux-musl-native/bin:$PATH"
  
  # Unset flags to ensure a clean environment for CMake
  unset LDFLAGS CXX CPP CC CXXFLAGS CPPFLAGS CFLAGS

  cmake -G Ninja ../llvm \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_CXX_EXTENSIONS=ON \
    -DLLVM_ENABLE_BINDINGS=OFF \
    -DLLVM_INCLUDE_BENCHMARKS:BOOL=OFF \
    -DLLVM_INCLUDE_TESTS:BOOL=OFF \
    -DLLVM_INCLUDE_EXAMPLES:BOOL=OFF \
    -DCMAKE_C_COMPILER="/$(uname -m)-linux-musl-native/bin/$(uname -m)-linux-musl-gcc" \
    -DCMAKE_CXX_COMPILER="/$(uname -m)-linux-musl-native/bin/$(uname -m)-linux-musl-g++" \
    -DCMAKE_REQUIRED_LIBRARIES=pthread \
    -DLLVM_ENABLE_LIBCXX:BOOL=TRUE \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_PREFIX_PATH="/usr;/$(uname -m)-linux-musl-native" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS='' \
    -DLLVM_ENABLE_RUNTIMES='' \
    -DLLVM_ENABLE_ZSTD:BOOL=OFF \
    -DLLVM_TARGETS_TO_BUILD=Native
  
  ninja
  ninja install
  
  # Clean up the PATH to avoid interfering with subsequent builds
  export PATH=$(echo "$PATH" | sed -e "s|/$(uname -m)-linux-musl-native/bin:||")
}

build_spirv_headers() {
  log_step "SPIRV-Headers"
  cd /SOURCE_CODE/SPIRV-Headers
  rm -rf build
  mkdir build
  cd build
  cmake -DCMAKE_INSTALL_PREFIX=/usr -G Ninja ..
  ninja
  ninja install
}

build_spirv_tools() {
  log_step "SPIRV-Tools"
  cd /SOURCE_CODE/SPIRV-Tools
  rm -rf build
  mkdir build
  cd build

  # Set environment for this specific build
  export CFLAGS="-isystem /$(uname -m)-linux-musl-native/include"
  export CXXFLAGS="-isystem /$(uname -m)-linux-musl-native/include/c++/11.2.1 -isystem /$(uname -m)-linux-musl-native/include/c++/11.2.1/$(uname -m)-linux-musl"

  cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DSPIRV_WERROR=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DSPIRV_TOOLS_BUILD_STATIC=OFF \
        -DSPIRV-Headers_SOURCE_DIR=/usr \
        -G Ninja ..
  ninja
  ninja install
  
  # Clean up environment
  unset CFLAGS CXXFLAGS
}

build_glslang() {
  log_step "glslang"
  cd /SOURCE_CODE/glslang
  rm -rf build
  mkdir build
  cd build

  cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DALLOW_EXTERNAL_SPIRV_TOOLS=ON \
        -DBUILD_SHARED_LIBS=ON \
        -DGLSLANG_TESTS=ON \
        -G Ninja ..
  ninja
  ninja install
}

build_libclc() {
  log_step "libclc"
  # User note: This build might fail as it often requires clang
  cd /SOURCE_CODE/libclc
  rm -rf build
  mkdir build
  cd build
  cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -G Ninja ..
  ninja
  ninja install
}

build_mesa() {
  log_step "Mesa"
  # Source the X.org environment variables if they exist
  [ -f /etc/profile.d/xorg.sh ] && . /etc/profile.d/xorg.sh
  
  cd /SOURCE_CODE/mesa
  # Workaround for a Mako check in a specific Mesa version
  sed -i '935s/^/#/' meson.build
  pip3 install PyYAML
  
  rm -rf build
  mkdir build
  cd build
  
  meson setup \
        --prefix="$XORG_PREFIX" \
        --buildtype=release \
        -Dplatforms=x11 \
        -Dglx=dri \
        -Dgallium-drivers=virgl,i915,iris \
        -Dvalgrind=disabled \
        -Dlibunwind=disabled \
        -Dllvm=disabled \
        -Dvulkan-drivers=intel \
        ..
  ninja
  ninja install
}


# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting the Graphics Stack build process..."

setup_static_compiler
pause_for_review "Static Compiler Setup"

build_llvm_clang
pause_for_review "LLVM/Clang"

build_spirv_headers
pause_for_review "SPIRV-Headers"

build_spirv_tools
pause_for_review "SPIRV-Tools"

build_glslang
pause_for_review "glslang"

build_libclc
pause_for_review "libclc"

build_mesa
pause_for_review "Mesa"

log_step "🎉 ALL BUILDS IN THIS SCRIPT ARE COMPLETE! 🎉"

EOF





cat > $LNX/SOURCE_CODE/BUILD_SYSTEM4_2 << "EOF"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now building: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The build for '$1' completed."
  echo "===> Review the log above. Press [Enter] to continue to the next package..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD FUNCTIONS (One function per package)
# --------------------------------------------------------------------------

build_libxcvt() {
  log_step "libxcvt"
  cd /SOURCE_CODE/libxcvt
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix="$XORG_PREFIX" --buildtype=release ..
  ninja
  ninja install
}

build_xcb_util() {
  log_step "xcb-util"
  cd /SOURCE_CODE/xcb-util
  make distclean || true
  ./configure "$XORG_CONFIG"
  make -j"$LNX_CPU_CORES"
  make install
}

build_xcb_util_image() {
  log_step "xcb-util-image"
  cd /SOURCE_CODE/xcb-util-image
  make distclean || true
  ./configure "$XORG_CONFIG"
  make -j"$LNX_CPU_CORES"
  make install
}

build_xcb_util_keysyms() {
  log_step "xcb-util-keysyms"
  cd /SOURCE_CODE/xcb-util-keysyms
  make distclean || true
  ./configure "$XORG_CONFIG"
  make -j"$LNX_CPU_CORES"
  make install
}

build_xcb_util_renderutil() {
  log_step "xcb-util-renderutil"
  cd /SOURCE_CODE/xcb-util-renderutil
  make distclean || true
  ./configure "$XORG_CONFIG"
  make -j"$LNX_CPU_CORES"
  make install
}

build_xcb_util_wm() {
  log_step "xcb-util-wm"
  cd /SOURCE_CODE/xcb-util-wm
  make distclean || true
  ./configure "$XORG_CONFIG"
  make -j"$LNX_CPU_CORES"
  make install
}

build_xcb_util_cursor() {
  log_step "xcb-util-cursor"
  cd /SOURCE_CODE/xcb-util-cursor
  make distclean || true
  ./configure "$XORG_CONFIG"
  make -j"$LNX_CPU_CORES"
  make install
}

build_libdrm() {
  log_step "libdrm"
  cd /SOURCE_CODE/libdrm
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix="$XORG_PREFIX" \
              --buildtype=release \
              -Dudev=true \
              -Dvalgrind=disabled \
              ..
  ninja
  ninja install
}

build_mako() {
  log_step "Mako (Python Template Engine)"
  cd /SOURCE_CODE/Mako
  pip3 install --no-cache-dir --no-user .
}

build_spirv_llvm_translator() {
  log_step "SPIRV-LLVM-Translator"
  # Set environment for this specific build
  export CPLUS_INCLUDE_PATH=/build-tools/"$(uname -m)"-linux-musl/include/c++/14.1.0

  cd /SOURCE_CODE/SPIRV-LLVM-Translator
  rm -rf build
  mkdir build
  cd build
  cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_SKIP_INSTALL_RPATH=ON \
        -DLLVM_EXTERNAL_SPIRV_HEADERS_SOURCE_DIR=/usr \
        -G Ninja ..
  ninja
  ninja install

  # Clean up environment
  unset CPLUS_INCLUDE_PATH
}

build_xbitmaps() {
  log_step "xbitmaps"
  cd /SOURCE_CODE/xbitmaps
  make distclean || true
  ./configure "$XORG_CONFIG"
  make install
}

build_libpng() {
  log_step "libpng"
  cd /SOURCE_CODE/libpng
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_xclock() {
  log_step "xclock"
  cd /SOURCE_CODE/xclock
  make distclean || true
  ./configure "$XORG_CONFIG"
  make -j"$LNX_CPU_CORES"
  make install
}


# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting the X.org libraries and components build process..."

# Load the environment variables that were created in the previous script
if [ -f /etc/profile.d/xorg.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/xorg.sh
  log_step "Sourced X.org environment variables."
else
  echo "WARNING: /etc/profile.d/xorg.sh not found. Build may fail."
fi

# Temporarily set C++ include path for certain builds
export CPLUS_INCLUDE_PATH=/build-tools/"$(uname -m)"-linux-musl/include/c++/14.1.0:/build-tools/lib/gcc/"$(uname -m)"-linux-musl/14.1.0/plugin/include

build_libxcvt
pause_for_review "libxcvt"

build_xcb_util
pause_for_review "xcb-util"

build_xcb_util_image
pause_for_review "xcb-util-image"

build_xcb_util_keysyms
pause_for_review "xcb-util-keysyms"

build_xcb_util_renderutil
pause_for_review "xcb-util-renderutil"

build_xcb_util_wm
pause_for_review "xcb-util-wm"

build_xcb_util_cursor
pause_for_review "xcb-util-cursor"

build_libdrm
pause_for_review "libdrm"

build_mako
pause_for_review "Mako"

build_spirv_llvm_translator
pause_for_review "SPIRV-LLVM-Translator"

build_xbitmaps
pause_for_review "xbitmaps"

build_libpng
pause_for_review "libpng"

build_xclock
pause_for_review "xclock"

# Clean up environment at the end
unset CPLUS_INCLUDE_PATH

log_step "🎉 ALL BUILDS IN THIS SCRIPT ARE COMPLETE! 🎉"

EOF




cat > $LNX/SOURCE_CODE/BUILD_SYSTEM4_3 << "EOF"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now building: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The build for '$1' completed."
  echo "===> Review the log above. Press [Enter] to continue to the next package..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD FUNCTIONS (One function per package/group)
# --------------------------------------------------------------------------

build_x_packages_in_passes() {
  # This function encapsulates the multi-pass build logic for X libraries, apps, or fonts.
  # Argument $1: The directory to work in (e.g., XApps, XFonts)
  # Argument $2: A friendly name for logging (e.g., "XApps")
  
  local build_dir="/SOURCE_CODE/$1"
  local build_name="$2"

  log_step "$build_name (in multiple passes)"
  cd "$build_dir"

  # This multi-pass approach is a classic way to resolve complex, circular
  # dependencies between packages without a perfectly linear build order.
  
  for pass in 1 2 3 4; do
    log_step "Building $build_name: Pass $pass of 4..."
    # Use find for a more robust way to get subdirectories
    find . -maxdepth 1 -mindepth 1 -type d | while read -r package_path; do
      local package=$(basename "$package_path")
      echo "--> Attempting to build $package in pass $pass..."
      ( # Run in a subshell to prevent cd from affecting the main script
        cd "$package"
        # Attempt to build with both autotools and meson, ignoring errors
        # as some packages will fail with one method but succeed with another.
        {
          make distclean || true
          ./configure "$XORG_CONFIG" && make -j"$LNX_CPU_CORES" && make install
        } || {
          rm -rf build
          mkdir build
          cd build
          meson setup --prefix=/usr --buildtype=release .. && ninja && ninja install
        } || echo "--> INFO: Skipping $package in this pass, will retry..."
      )
    done
    echo "===> Pass $pass complete."
  done
}

build_luit() {
  log_step "luit"
  cd /SOURCE_CODE/luit
  make distclean || true
  ./configure "$XORG_CONFIG"
  make -j"$LNX_CPU_CORES"
  make install
}

build_xcursor_themes() {
  log_step "xcursor-themes"
  cd /SOURCE_CODE/xcursor-themes
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

setup_font_symlinks() {
    log_step "Setting up X11 font symlinks"
    install -v -d -m755 /usr/share/fonts
    ln -svfn "$XORG_PREFIX"/share/fonts/X11/OTF /usr/share/fonts/X11-OTF
    ln -svfn "$XORG_PREFIX"/share/fonts/X11/TTF /usr/share/fonts/X11-TTF
}

build_xkeyboard_config() {
  log_step "xkeyboard-config"
  cd /SOURCE_CODE/xkeyboard-config
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix="$XORG_PREFIX" --buildtype=release ..
  ninja
  ninja install
}

build_pixman() {
  log_step "pixman"
  cd /SOURCE_CODE/pixman
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr --buildtype=release ..
  ninja
  ninja install
}

build_libepoxy() {
  log_step "libepoxy"
  cd /SOURCE_CODE/libepoxy
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr -Dtests=false -Ddocs=false --buildtype=release ..
  ninja
  ninja install
}

build_libxcvt() {
  log_step "libxcvt (rebuild check)"
  cd /SOURCE_CODE/libxcvt
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix="$XORG_PREFIX" --buildtype=release ..
  ninja
  ninja install
}

build_xorg_server() {
  log_step "X.org Server"
  cd /SOURCE_CODE/xorg-server
  rm -rf build
  mkdir build
  cd build
  meson setup .. \
        --prefix="$XORG_PREFIX" \
        --localstatedir=/var \
        -Dglamor=true \
        -Dsecure-rpc=false \
        -Dxkb_output_dir=/var/lib/xkb \
        -Dudev=false \
        -Dudev_kms=false \
        -Dhal=false
  ninja
  ninja install
  
  log_step "X.org Server (post-install setup)"
  mkdir -pv /etc/X11/xorg.conf.d
  install -v -d -m1777 /tmp/.{ICE,X11}-unix
  
  # Create a file to ensure necessary temp directories are created on boot
  cat > /etc/sysconfig/createfiles << "ENDOFFILE"
/tmp/.ICE-unix dir 1777 root root
/tmp/.X11-unix dir 1777 root root
ENDOFFILE
}


# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting the final X.org components build process..."

# Load the environment variables that were created in a previous script
if [ -f /etc/profile.d/xorg.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/xorg.sh
  log_step "Sourced X.org environment variables."
else
  echo "WARNING: /etc/profile.d/xorg.sh not found. Build may fail."
  # Define a fallback for XORG_CONFIG to prevent the script from failing immediately
  export XORG_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static"
fi

# --- X.org Applications and Fonts (Complex Builds) ---
build_x_packages_in_passes "XApps" "XApps"
pause_for_review "XApps"

build_luit
pause_for_review "luit"

build_xcursor_themes
pause_for_review "xcursor-themes"

build_x_packages_in_passes "XFonts" "XFonts"
pause_for_review "XFonts"

setup_font_symlinks
pause_for_review "Font Symlinks"

# --- Core Graphics Libraries and Server ---
build_xkeyboard_config
pause_for_review "xkeyboard-config"

build_pixman
pause_for_review "pixman"

build_libepoxy
pause_for_review "libepoxy"

build_libxcvt
pause_for_review "libxcvt"

build_xorg_server
pause_for_review "X.org Server"

log_step "🎉 ALL BUILDS IN THIS SCRIPT ARE COMPLETE! 🎉"
EOF





cat > $LNX/SOURCE_CODE/BUILD_SYSTEM4_4 << "EOF"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now building: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The build for '$1' completed."
  echo "===> Review the log above. Press [Enter] to continue to the next package..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD FUNCTIONS (One function per package)
# --------------------------------------------------------------------------

build_mtdev() {
  log_step "mtdev"
  cd /SOURCE_CODE/mtdev
  make distclean || true
  ./configure --prefix=/usr --disable-static
  make -j"$LNX_CPU_CORES"
  make install
}

build_libevdev() {
  log_step "libevdev"
  cd /SOURCE_CODE/libevdev
  # The original script used autotools; meson is commented out.
  # rm -rf build
  # cd build
  # meson setup .. --prefix=$XORG_PREFIX --buildtype=release -Ddocumentation=disabled
  # ninja
  # ninja install
  ./configure "$XORG_CONFIG"
  make
  make install
}

build_xf86_input_evdev() {
  log_step "xf86-input-evdev"
  cd /SOURCE_CODE/xf86-input-evdev
  ./configure "$XORG_CONFIG"
  make
  make install
}

build_xf86_input_mouse() {
  log_step "xf86-input-mouse"
  cd /SOURCE_CODE/xf86-input-mouse
  ./configure "$XORG_CONFIG"
  make
  make install
}

build_xf86_input_keyboard() {
  log_step "xf86-input-keyboard"
  cd /SOURCE_CODE/xf86-input-keyboard
  ./configure "$XORG_CONFIG"
  make
  make install
}

build_xf86_input_synaptics() {
  log_step "xf86-input-synaptics"
  cd /SOURCE_CODE/xf86-input-synaptics
  ./configure "$XORG_CONFIG"
  make
  make install
}

build_twm() {
  log_step "TWM (Tab Window Manager)"
  cd /SOURCE_CODE/twm
  # Modify Makefile template to set the correct resource directory
  sed -i -e '/^rcdir =/s,^\(rcdir = \).*,\1/etc/X11/app-defaults,' src/Makefile.in
  ./configure "$XORG_CONFIG"
  make
  make install
}

build_xinit() {
  log_step "xinit"
  cd /SOURCE_CODE/xinit
  ./configure "$XORG_CONFIG" --with-xinitdir=/etc/X11/app-defaults
  make
  make install
}


# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting X.org input drivers and core apps build process..."

# Update the dynamic linker cache before starting
ldconfig -v

# Load the environment variables that were created in a previous script
if [ -f /etc/profile.d/xorg.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/xorg.sh
  log_step "Sourced X.org environment variables."
else
  echo "WARNING: /etc/profile.d/xorg.sh not found. Build may fail."
  # Define a fallback for XORG_CONFIG to prevent the script from failing immediately
  export XORG_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static"
fi

# --- Input Device Libraries and Drivers ---
build_mtdev
pause_for_review "mtdev"

build_libevdev
pause_for_review "libevdev"

build_xf86_input_evdev
pause_for_review "xf86-input-evdev"

build_xf86_input_mouse
pause_for_review "xf86-input-mouse"

build_xf86_input_keyboard
pause_for_review "xf86-input-keyboard"

build_xf86_input_synaptics
pause_for_review "xf86-input-synaptics"

# --- Core X Applications ---
build_twm
pause_for_review "TWM"

build_xinit
pause_for_review "xinit"

log_step "🎉 ALL BUILDS IN THIS SCRIPT ARE COMPLETE! 🎉"

EOF







cat > $LNX/SOURCE_CODE/BUILD_SYSTEM5 << "EOF"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now building: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The build for '$1' completed."
  echo "===> Review the log above. Press [Enter] to continue to the next package..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD FUNCTIONS (One function per package)
# --------------------------------------------------------------------------

build_libarchive() {
  log_step "libarchive"
  cd /SOURCE_CODE/libarchive
  make distclean || true
  # FROM LFS: Adapt the package to changes in glibc-2.36 ->
  # This may or may not be necessary for musl, but is kept for reference.
  sed '/linux\/fs\.h/d' -i libarchive/archive_read_disk_posix.c
  ./configure --prefix=/usr --disable-static
  make -j"$LNX_CPU_CORES"
  make install
}

build_sqlite() {
  log_step "SQLite (Autoconf)"
  cd /SOURCE_CODE/sqlite-autoconf
  make distclean || true
  ./configure --prefix=/usr --disable-static
  make -j"$LNX_CPU_CORES"
  make install
}

build_nghttp2() {
  log_step "nghttp2"
  cd /SOURCE_CODE/nghttp2
  make distclean || true
  ./configure --prefix=/usr --disable-static
  make -j"$LNX_CPU_CORES"
  make install
}

build_glib_networking() {
  log_step "glib-networking"
  cd /SOURCE_CODE/glib-networking
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr --buildtype=release -Dlibproxy=disabled -Dgnome_proxy=disabled -Dopenssl=enabled ..
  ninja
  ninja install
}

build_vala() {
  log_step "Vala"
  cd /SOURCE_CODE/vala
  make distclean || true
  ./configure --prefix=/usr --disable-valadoc
  make -j"$LNX_CPU_CORES"
  make install
}

build_gmp() {
  log_step "GMP (GNU Multiple Precision)"
  cd /SOURCE_CODE/gmp
  make distclean || true
  ./configure --prefix=/usr --disable-static
  make -j"$LNX_CPU_CORES"
  make check
  make install
}

build_libxcrypt() {
  log_step "libxcrypt"
  cd /SOURCE_CODE/libxcrypt
  [ ! -f configure ] && ./autogen.sh
  make distclean || true
  ./configure --prefix=/usr \
              --enable-hashes=strong,glibc \
              --enable-obsolete-api=no \
              --disable-static \
              --disable-failure-tokens
  make -j"$LNX_CPU_CORES"
  make install
}

build_expat() {
  log_step "Expat"
  cd /SOURCE_CODE/expat
  make distclean || true
  ./configure --prefix=/usr \
              --disable-static
  make -j"$LNX_CPU_CORES"
  make install
}


# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting the core libraries build process..."

# Load the environment variables that were created in a previous script
if [ -f /etc/profile.d/xorg.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/xorg.sh
  log_step "Sourced X.org environment variables."
else
  echo "WARNING: /etc/profile.d/xorg.sh not found. Build may fail."
fi

build_libarchive
pause_for_review "libarchive"

build_sqlite
pause_for_review "SQLite"

build_nghttp2
pause_for_review "nghttp2"

build_glib_networking
pause_for_review "glib-networking"

build_vala
pause_for_review "Vala"

# --- Rebuild GMP as per user's script logic ---
# THIS IS FROM MUCH EARLIER IN THE DOCUMENT, ALREADY COMPILED,
# but there seems to be strange errors...
build_gmp
pause_for_review "GMP (rebuild)"

build_libxcrypt
pause_for_review "libxcrypt"

build_expat
pause_for_review "Expat (rebuild)"

log_step "🎉 ALL BUILDS IN THIS SCRIPT ARE COMPLETE! 🎉"

EOF






cat > $LNX/SOURCE_CODE/BUILD_SYSTEM5_2 << "EOF"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now building: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The build for '$1' completed."
  echo "===> Review the log above. Press [Enter] to continue to the next package..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD FUNCTIONS (One function per package)
# --------------------------------------------------------------------------

build_xz() {
  log_step "xz"
  cd /SOURCE_CODE/xz
  [ ! -f configure ] && ./autogen.sh
  make distclean || true
  ./configure --prefix=/usr \
              --disable-static
  make -j"$LNX_CPU_CORES"
  make install
}

build_e2fsprogs() {
  log_step "e2fsprogs"
  cd /SOURCE_CODE/e2fsprogs
  rm -rf build
  mkdir -v build
  cd build
  ../configure --prefix=/usr \
               --sysconfdir=/etc \
               --enable-libblkid \
               --enable-libuuid \
               --disable-uuidd \
               --enable-blkid-debug \
               --disable-debugfs \
               --disable-resizer \
               --disable-defrag \
               --disable-tls \
               --disable-mmp \
               --disable-tdb \
               --disable-fsck
  make -j"$LNX_CPU_CORES"

  # The following mkdir/touch commands are workarounds to satisfy the build
  # process when header files are not found in their expected locations.
  log_step "e2fsprogs (Applying build workarounds)"
  mkdir -p /usr/include/et/
  touch /usr/include/et/com_err.h
  mkdir -p /usr/share/et/
  touch /usr/share/et/et_c.awk
  mkdir -p /usr/include/ss/
  touch /usr/include/ss/ss.h
  mkdir -p /usr/share/ss/
  touch /usr/share/ss/ct_c.sed
  mkdir -p /usr/include/e2p/
  touch /usr/include/e2p/e2p.h
  mkdir -p /usr/include/uuid/
  touch /usr/include/uuid/uuid.h
  mkdir -p /usr/include/blkid/
  touch /usr/include/blkid/blkid.h
  mkdir -p /usr/include/ext2fs/
  touch /usr/include/ext2fs/hashmap.h
  
  make install
}

build_util_linux() {
  log_step "util-linux"
  cd /SOURCE_CODE/util-linux
  make distclean || true
  ./configure --prefix=/usr \
              --bindir=/usr/bin \
              --libdir=/usr/lib \
              --sbindir=/usr/sbin \
              --disable-chfn-chsh \
              --disable-login \
              --disable-nologin \
              --disable-su \
              --disable-setpriv \
              --disable-runuser \
              --disable-pylibmount \
              --disable-static \
              --without-systemdsystemunitdir
  make -j"$LNX_CPU_CORES"
  make install
}


# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting the core system utilities build process..."

# Load the environment variables that were created in a previous script
if [ -f /etc/profile.d/xorg.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/xorg.sh
  log_step "Sourced X.org environment variables."
else
  echo "WARNING: /etc/profile.d/xorg.sh not found. Build may fail."
fi

build_xz
pause_for_review "xz"

build_e2fsprogs
pause_for_review "e2fsprogs"

build_util_linux
pause_for_review "util-linux"

log_step "🎉 ALL BUILDS IN THIS SCRIPT ARE COMPLETE! 🎉"

EOF




cat > $LNX/SOURCE_CODE/BUILD_SYSTEM5_3 << "EOF"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now building: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The build for '$1' completed."
  echo "===> Review the log above. Press [Enter] to continue to the next package..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD FUNCTIONS (One function per package)
# --------------------------------------------------------------------------

build_xml_parser() {
  log_step "Perl XML-Parser"
  cd /SOURCE_CODE/XML-Parser
  perl Makefile.PL
  make
  make test
  make install
}

build_intltool() {
  log_step "intltool"
  cd /SOURCE_CODE/intltool
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_nasm() {
  log_step "NASM (Netwide Assembler)"
  cd /SOURCE_CODE/nasm
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_libjpeg_turbo() {
  log_step "libjpeg-turbo"
  cd /SOURCE_CODE/libjpeg-turbo
  rm -rf build
  mkdir build
  cd build
  cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=RELEASE \
        -DENABLE_STATIC=FALSE \
        -DCMAKE_INSTALL_DOCDIR=/usr/share/doc/libjpeg-turbo \
        -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib \
        ..
  make -j"$LNX_CPU_CORES"
  make install
}

build_shared_mime_info() {
  log_step "shared-mime-info"
  cd /SOURCE_CODE/shared-mime-info
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr --buildtype=release ..
  ninja
  ninja install
}

build_libpng() {
  log_step "libpng"
  cd /SOURCE_CODE/libpng
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_gdk_pixbuf() {
  log_step "gdk-pixbuf"
  cd /SOURCE_CODE/gdk-pixbuf
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr --buildtype=release -Dman=false -Dtests=false \
        --libdir=/usr/lib \
        --sysconfdir=/etc \
        --mandir=/usr/man ..
  ninja
  ninja install
}

build_yaml() {
  log_step "libyaml"
  cd /SOURCE_CODE/yaml
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_libfuse() {
  log_step "libfuse"
  # Also critical for podman (but not for flatpak).
  cd /SOURCE_CODE/libfuse
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr --buildtype=release \
        -Dexamples=false \
        -Dtests=false \
        -Ddisable-mtab=false \
        -Dutils=true \
        ..
  ninja
  ninja install
}

build_glib() {
  log_step "GLib (rebuild)"
  # Set include path for this build
  export CPLUS_INCLUDE_PATH=/usr/include
  
  cd /SOURCE_CODE/glib
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr \
              --buildtype=release \
              -Dman=false \
              ..
  ninja
  ninja install
  
  # Clean up environment
  unset CPLUS_INCLUDE_PATH
}


# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting the GUI and system libraries build process..."

# Load the environment variables that were created in a previous script
if [ -f /etc/profile.d/xorg.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/xorg.sh
  log_step "Sourced X.org environment variables."
else
  echo "WARNING: /etc/profile.d/xorg.sh not found. Build may fail."
fi

build_xml_parser
pause_for_review "Perl XML-Parser"

build_intltool
pause_for_review "intltool"

build_nasm
pause_for_review "NASM"

build_libjpeg_turbo
pause_for_review "libjpeg-turbo"

build_shared_mime_info
pause_for_review "shared-mime-info"

build_libpng
pause_for_review "libpng"

build_gdk_pixbuf
pause_for_review "gdk-pixbuf"

build_yaml
pause_for_review "libyaml"

build_libfuse
pause_for_review "libfuse"

build_glib
pause_for_review "GLib"

log_step "🎉 ALL BUILDS IN THIS SCRIPT ARE COMPLETE! 🎉"

EOF






cat > $LNX/SOURCE_CODE/BUILD_SYSTEM5_4<< "EOF_"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now processing: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The step for '$1' completed."
  echo "===> Review the log above. Press [Enter] to continue to the next step..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD AND CONFIGURATION FUNCTIONS
# --------------------------------------------------------------------------

build_dbus() {
  log_step "D-Bus"
  cd /SOURCE_CODE/dbus
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback -Dsystemd=disabled ..
  ninja
  ninja install
}

build_iptables() {
  log_step "iptables"
  cd /SOURCE_CODE/iptables
  make distclean || true
  # CFLAGS workaround for __UAPI_DEF_ETHHDR definition issues
  export CFLAGS=" -D__UAPI_DEF_ETHHDR=0"
  ./configure --prefix=/usr --disable-nftables --enable-libipq
  make -j"$LNX_CPU_CORES"
  make install
  # Reset CFLAGS to a sane default
  export CFLAGS="-B/usr/lib -I/usr/include"
}

build_alsa_stack() {
  log_step "ALSA Libraries and Utilities"
  
  log_step "ALSA (alsa-lib)"
  cd /SOURCE_CODE/alsa-lib
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install

  log_step "ALSA (alsa-plugins)"
  cd /SOURCE_CODE/alsa-plugins
  ./configure --prefix=/usr --sysconfdir=/etc
  make -j"$LNX_CPU_CORES"
  make install

  log_step "ALSA (alsa-utils)"
  cd /SOURCE_CODE/alsa-utils
  ./configure --disable-alsaconf \
              --disable-bat \
              --disable-xmlto
  make -j"$LNX_CPU_CORES"
  make install
  ldconfig
}

configure_init_scripts() {
  log_step "Configuring Init Scripts (alsa, dbus)"
  cd /SOURCE_CODE/blfs-bootscripts
  make install-alsa

  cd /etc/rc.d/init.d
  # Patching alsa init script
  sed -i '28 s/./#&/' alsa
  sed -i '32 s/./#&/' alsa
  sed -i '34 s/./#&/' alsa
  sed -i '38 s/./#&/' alsa
  sed -i '40 s/./#&/' alsa
  chmod 754 alsa

  # Patching dbus init script
  sed -i '36 s/./#&/' dbus
  sed -i '40 s/./#&/' dbus
  sed -i '44 s/./#&/' dbus
  sed -i '46 s/./#&/' dbus
  sed -i '39 s/start_daemon//' dbus
  chmod 754 dbus
}

copy_user_configs() {
  log_step "Copying predefined user configurations"
  # This section copies user-specific config files.
  # Ensure the source files (e.g., ~/START) exist on the build host.
  chown -R user:user /home/user/
  cp ~/START /home/user/ || echo "INFO: ~/START not found, skipping."
  cp ~/WIFI /home/user/ || echo "INFO: ~/WIFI not found, skipping."
  cp ~/LOCALE /home/user/ || echo "INFO: ~/LOCALE not found, skipping."
  cp ~/SOUND /home/user/ || echo "INFO: ~/SOUND not found, skipping."
  [ -f ~/xorg.conf ] && mv ~/xorg.conf /etc/X11/xorg.conf.d/
  [ -f ~/xinitrc ] && mv ~/xinitrc /etc/X11/app-defaults/
}

fix_dbus_python() {
  log_step "Fixing dbus-python installation"
  # Temporarily set CC to ensure it links against libm
  export CC="/build-tools/bin/$(uname -m)-linux-musl-gcc -lm"
  pip3 install dbus-python
  # Reset CC to the default toolchain compiler
  export CC=/build-tools/bin/"$(uname -m)"-linux-musl-gcc
}

install_fonts() {
  log_step "Installing DejaVu Fonts"
  cd /SOURCE_CODE/dejavu-fonts-ttf
  install -v -d -m755 /usr/share/fonts/dejavu
  install -v -m644 ttf/*.ttf /usr/share/fonts/dejavu
  fc-cache -v /usr/share/fonts/dejavu
}

setup_podman_prereqs() {
  log_step "Setting up Podman Prerequisites"
  
  log_step "Podman Prereq (libslirp)"
  cd /SOURCE_CODE/libslirp
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr --buildtype=release ..
  ninja
  ninja install

  log_step "Podman Prereq (slirp4netns)"
  cd /SOURCE_CODE/slirp4netns
  git checkout v1.3.3
  ./autogen.sh
  ./configure --prefix=/usr
  make
  make install

  log_step "Podman Prereq (libfuse)"
  cd /SOURCE_CODE/libfuse
  meson setup build --prefix=/usr
  ninja -C build
  ninja -C build install

  log_step "Podman Prereq (fuse-overlayfs)"
  cd /SOURCE_CODE/fuse-overlayfs
  ./autogen.sh
  ./configure --prefix=/usr
  make
  make install
}

build_auth_stack() {
  log_step "Building Authentication Stack (PAM, Shadow)"

  log_step "Auth Prereq (libmd)"
  cd /SOURCE_CODE/libmd
  ./configure --prefix=/usr
  make
  make install

  log_step "Auth Prereq (libbsd)"
  cd /SOURCE_CODE/libbsd
  ./configure --prefix=/usr
  make
  make install

  log_step "Auth Stack (Linux-PAM)"
  cd /SOURCE_CODE/Linux-PAM
  rm -rf build
  mkdir build
  cd build
  meson setup .. --prefix=/usr -D docs=disabled
  ninja
  ninja install
  
  log_step "Auth Stack (Shadow - PAM aware)"
  cd /SOURCE_CODE/shadow
  [ ! -f configure ] && ./autogen.sh
  make distclean || true
  ./configure --prefix=/usr --disable-logind
  make
  make install
}

configure_auth_system() {
  log_step "Configuring Authentication System (PAM, Shadow, Users)"

  # Generate a machine-id for D-Bus
  dbus-uuidgen --ensure

  # Setup subuid/subgid for rootless Podman
  echo "user:100000:65536" > /etc/subuid
  echo "user:100000:65536" > /etc/subgid
  
  # Setup cgroup v2 for rootless Podman delegation
  echo "+cpu +memory +pids" > /sys/fs/cgroup/cgroup.subtree_control
  mkdir -p /sys/fs/cgroup/user/1000
  chown -R user:user /sys/fs/cgroup/user/1000

  # Create minimal, functional PAM configuration files
  log_step "Configuring PAM services (/etc/pam.d)"
  install -v -m755 -d /etc/pam.d

  cat > /etc/pam.d/login << "EOF"
#%PAM-1.0
auth       required   pam_unix.so
account    required   pam_unix.so
password   required   pam_unix.so
session    required   pam_unix.so
EOF

  cat > /etc/pam.d/passwd << "EOF"
#%PAM-1.0
auth       required   pam_unix.so
account    required   pam_unix.so
password   required   pam_unix.so
EOF

  cp /etc/pam.d/login /etc/pam.d/su
  cp /etc/pam.d/login /etc/pam.d/xlock

  # Create /etc/shells file
  cat > /etc/shells << "EOF"
/bin/sh
/bin/ash
EOF

  # Ensure login.defs uses strong encryption
  sed -i 's/^#* *ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/' /etc/login.defs

  # Convert passwd/group to shadow format
  pwconv
  grpconv

  # Set new (SHA512 encrypted) passwords
  echo "Setting password for root..."
  passwd root
  echo "Setting password for user..."
  passwd user

  # Check user status
  chage -l user
}

build_xlockmore_pam() {
  log_step "xlockmore (PAM aware)"
  cd /SOURCE_CODE/xlockmore
  make clean
  ./configure --prefix=/usr --enable-pam --without-gtk --without-gtk2 --without-mesa --without-opengl
  make -j"$LNX_CPU_CORES"
  make install
}

setup_linker_path() {
  log_step "Setting up system-wide linker path for musl"
  ARCH=$(uname -m)
  cat > "/etc/ld-musl-${ARCH}.path" << EOF
/build-tools/${ARCH}-linux-musl/lib64
/build-tools/lib
/build-tools/lib64
/build-tools/${ARCH}-unknown-linux-gnu/${ARCH}-linux-musl/lib
/lib
/lib64
/usr/lib
/usr/lib64
/usr/lib64/security
# Add other paths as needed
EOF
}


# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting final system configuration and build process..."

# Load the environment variables that were created in a previous script
if [ -f /etc/profile.d/xorg.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/xorg.sh
  log_step "Sourced X.org environment variables."
else
  echo "WARNING: /etc/profile.d/xorg.sh not found. Build may fail."
fi

# Temporarily set C++ include path for certain builds
export CPLUS_INCLUDE_PATH=/build-tools/"$(uname -m)"-linux-musl/include/c++/14.1.0

build_dbus
pause_for_review "D-Bus"

# --- System Setup ---
# Install NLS for every language...
localedef -i sv_SE -f UTF-8 UTF-8
setxkbmap -model pc105 -layout se
pause_for_review "Locale and Keymap Setup"

build_iptables
pause_for_review "iptables"

build_alsa_stack
pause_for_review "ALSA Stack"

configure_init_scripts
pause_for_review "Init Scripts"

copy_user_configs
pause_for_review "User Configs"

fix_dbus_python
pause_for_review "dbus-python fix"

install_fonts
pause_for_review "Fonts"

# --- Podman and Auth Stack ---
setup_podman_prereqs
pause_for_review "Podman Prerequisites"

build_auth_stack
pause_for_review "Authentication Stack (PAM, Shadow)"

configure_auth_system
pause_for_review "Authentication System Config"

build_xlockmore_pam
pause_for_review "xlockmore (PAM)"

setup_linker_path
pause_for_review "System Linker Path"

# Clean up environment at the end
unset CPLUS_INCLUDE_PATH

log_step "🎉 ALL BUILDS AND CONFIGURATIONS IN THIS SCRIPT ARE COMPLETE! 🎉"

EOF_



cat > $LNX/SOURCE_CODE/BUILD_SYSTEM5_5<< "EOF_"
#!/bin/ash

# --------------------------------------------------------------------------
# SCRIPT SETUP AND HELPER FUNCTIONS
# --------------------------------------------------------------------------

# This is the most important command in a build script.
# 'set -e' tells the shell to exit immediately if any command fails.
set -e

# Set the number of CPU cores to use for compilation
export LNX_CPU_CORES=$(nproc)

# A simple function to print clean log headers
log_step() {
  echo
  echo "========================================================================"
  echo "=> Now processing: $@"
  echo "========================================================================"
}

# A function that announces success and waits for user input
pause_for_review() {
  echo
  echo "===> ✅ SUCCESS: The step for '$1' completed."
  echo "=> Review the log above. Press [Enter] to continue to the next step..."
  read -r _
}


# --------------------------------------------------------------------------
# BUILD AND CONFIGURATION FUNCTIONS
# --------------------------------------------------------------------------

build_st_terminal() {
  log_step "st (Simple Terminal)"
  cd /SOURCE_CODE/st
  cp config.def.h config.h
  # Apply scrollback patch
  patch -p0 < st.patch
  # Increase default font size
  sed -i.bak 's/pixelsize=12/pixelsize=20/' config.h
  sed -i 's|^PREFIX = /usr/local|PREFIX = /usr|' config.mk
  make
  make install
}

build_gpg_stack() {
  log_step "GPG/Encryption Stack"

  log_step "GPG (libgpg-error)"
  cd /SOURCE_CODE/libgpg-error
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install

  log_step "GPG (libassuan)"
  cd /SOURCE_CODE/libassuan
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install

  log_step "GPG (gpgme)"
  cd /SOURCE_CODE/gpgme
  make distclean || true
  # CFLAGS workaround for ino64_t definitions
  CFLAGS="-Dino64_t=ino_t -Doff64_t=off_t" ./configure --prefix=/usr --disable-gpg-test --disable-static
  make -j"$LNX_CPU_CORES"
  make install
}

build_mksh() {
  log_step "mksh (MirBSD Korn Shell)"
  cd /SOURCE_CODE/mksh-master
  chmod 755 Build.sh
  ./Build.sh
  cp mksh /bin/
  # Replace bash with a symlink to mksh
  ln -fs /bin/mksh /bin/bash
  rm -f /usr/bin/bash
}

setup_go_environment() {
  log_step "Setting up Go Environment"
  cd /SOURCE_CODE/
  
  # LNX checks for target architecture and unpacks the correct Go binary distribution
  ARCH=$(uname -m)
  case "$ARCH" in
    aarch64)
      tar zxvf go1.24.5.linux-arm64.tar.gz -C /tmp
      ;;
    x86_64)
      tar zxvf go1.24.5.linux-amd64.tar.gz -C /tmp
      ;;
    *)
      echo "ERROR: Unsupported architecture for Go binary: $ARCH" >&2
      exit 1
      ;;
  esac
  
  # Add the downloaded Go toolchain to the PATH for this script's session
  export PATH=/tmp/go/bin:$PATH
}

build_conmon() {
  log_step "conmon"
  cd /SOURCE_CODE/conmon
  make clean
  # NOTE: Version 2.1.9 is known to cause OCI errors.
  git checkout v2.1.13
  rm -rf build
  mkdir build
  cd build
  meson setup --prefix=/usr --buildtype=release ..
  ninja
  ninja install
}

build_runc() {
  log_step "runc"
  cd /SOURCE_CODE/runc
  make clean
  git checkout v1.0.0
  make SHELL=/bin/sh BUILDTAGS="seccomp"
  # go build -tags "seccomp" -o runc . # Alternative build command
  cp runc /usr/bin/runc
}

configure_container_defaults() {
  log_step "Configuring Container Defaults (/etc/containers)"
  mkdir -p /etc/containers
  wget --no-check-certificate -O /etc/containers/registries.conf https://raw.githubusercontent.com/containers/image/main/registries.conf
  wget --no-check-certificate -O /etc/containers/policy.json https://raw.githubusercontent.com/containers/image/main/default-policy.json

  cat > /etc/containers/containers.conf << "EOF"
[engine]
cgroup_manager = "cgroupfs"
events_logger = "file"
runtime = "crun"
oom_score_adj = 0
EOF

  cat > /etc/containers/storage.conf << "EOF"
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
EOF

  cat > /etc/containers/registries.conf << "EOF"
unqualified-search-registries = ["docker.io","quay.io"]
EOF
}

build_grep() {
  log_step "grep"
  cd /SOURCE_CODE/grep
  make distclean || true
  ./configure --prefix=/usr
  make -j"$LNX_CPU_CORES"
  make install
}

build_cni_plugins() {
  log_step "CNI Network Plugins (for Podman)"
  cd /SOURCE_CODE/plugins
  git checkout v1.7.1
  ./build_linux.sh
  # Assuming the binaries are created in a 'bin' subdirectory
  cp bin/* /usr/bin/
}

build_podman() {
  log_step "Podman"
  cd /SOURCE_CODE/podman
  # Checkout a specific stable version
  git checkout tags/v5.5.2
  make clean
  # Workaround: Busybox's ln does not have -sfr support (the 'r' flag)
  sed -i.bak 's/ln -sfr/ln -sf/g' Makefile
  make BUILDTAGS="exclude_graphdriver_btrfs seccomp cni" LDFLAGS="-extldflags='-static -B/usr/lib -L/usr/lib'" MAN=/bin/true PREFIX=/usr
  make install.bin PREFIX=/usr
}

build_yajl_manual() {
  log_step "Yajl (Manual Build)"
  # yajl's build system is broken, building manually instead!
  cd /SOURCE_CODE/yajl
  
  # Compile each .c file in src/ to an .o file
  $CC -fPIC -c src/yajl.c -o yajl.o
  $CC -fPIC -c src/yajl_lex.c -o yajl_lex.o
  $CC -fPIC -c src/yajl_parser.c -o yajl_parser.o
  $CC -fPIC -c src/yajl_buf.c -o yajl_buf.o
  $CC -fPIC -c src/yajl_encode.c -o yajl_encode.o
  $CC -fPIC -c src/yajl_gen.c -o yajl_gen.o
  $CC -fPIC -c src/yajl_alloc.c -o yajl_alloc.o
  $CC -fPIC -c src/yajl_tree.c -o yajl_tree.o
  $CC -fPIC -c src/yajl_version.c -o yajl_version.o

  # Link the object files into a shared library
  $CC -shared -o libyajl.so.2.1.1 ./*.o -Wl,-soname,libyajl.so.2

  # Install the library file
  install -m 755 libyajl.so.2.1.1 /usr/lib/
  # Create the necessary symbolic links
  ln -sf libyajl.so.2.1.1 /usr/lib/libyajl.so.2
  ln -sf libyajl.so.2 /usr/lib/libyajl.so

  # Install the public header files
  install -d /usr/include/yajl
  install -m 644 src/api/*.h /usr/include/yajl/

  # Create a pkg-config file for yajl
  cat > /usr/lib/pkgconfig/yajl.pc << "EOF"
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: yajl
Description: Yet Another JSON Library
Version: 2.1.1
Libs: -L${libdir} -lyajl
Cflags: -I${includedir}
EOF

  # Test the pkg-config file
  pkg-config --libs yajl
}

build_argp_standalone() {
  log_step "argp-standalone"
  cd /SOURCE_CODE/argp-standalone
  # Use the static native compiler for this build
  CC="/$(uname -m)-linux-musl-native/bin/$(uname -m)-linux-musl-gcc" cmake -DCMAKE_BUILD_TYPE=Release .
  CC="/$(uname -m)-linux-musl-native/bin/$(uname -m)-linux-musl-gcc" make
  cp include/argp-standalone/argp.h /usr/include/
  cp src/libargp-standalone.a /usr/lib/libargp.a
}

build_crun() {
  log_step "crun"
  cd /SOURCE_CODE/crun
  [ ! -f configure ] && ./autogen.sh
  ./configure --prefix=/usr --disable-systemd
  make
  make install
}

# --------------------------------------------------------------------------
# MAIN EXECUTION BLOCK
# --------------------------------------------------------------------------

log_step "Starting the final build script..."

# Load the environment variables that were created in a previous script
if [ -f /etc/profile.d/xorg.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/xorg.sh
  log_step "Sourced X.org environment variables."
else
  echo "WARNING: /etc/profile.d/xorg.sh not found. Build may fail."
fi

build_st_terminal
pause_for_review "st (Simple Terminal)"

build_gpg_stack
pause_for_review "GPG Stack"

build_mksh
pause_for_review "mksh"

setup_go_environment
pause_for_review "Go Environment Setup"

build_conmon
pause_for_review "conmon"

build_runc
pause_for_review "runc"

build_grep
pause_for_review "grep"

configure_container_defaults
pause_for_review "Container Defaults Configuration"

build_cni_plugins
pause_for_review "CNI Network Plugins"

build_podman
pause_for_review "Podman"

build_yajl_manual
pause_for_review "Yajl"

build_argp_standalone
pause_for_review "argp-standalone"

build_crun
pause_for_review "crun"

log_step "🎉 ALL BUILDS IN THIS SCRIPT ARE COMPLETE! 🎉"
EOF_

chmod 755 $LNX/SOURCE_CODE/BUILD*




STEP 4) MAKE A BACKUP OF THE TARGET SYSTEM:
===========================================
cd $LNX
tar cvf ~/lnx2025.10_musl_before_boot_into_target_NEW.tar --exclude=SOURCE_CODE .
#tar cvf ~/lnx_2024_after_complete_build.tar --exclude=SOURCE_CODE .
# A BUILD_SYSTEM4* COMPLETION SAVEPOINT FROM THE BUILD MACHINE (won't do this from LNX due to busybox tar version)
mount /dev/nvme0n1p4 /MAKE_LNX
mount /dev/nvme0n1p6 /MAKE_LNX
cd /MAKE_LNX
tar cvf ~/lnx2025.10_musl_COMPLETE_SYSTEM_without_SOURCE_CODE.tar --exclude=SOURCE_CODE --exclude=home .
tar cvf ~/lnx2025.10_musl_COMPLETE_SYSTEM.tar --exclude=home .


# Unpack on the TARGET system that will be used as the daily driver:
mount /dev/nvme0n1p5 /LNX
cd ~ && tar xvf lnx2025.10_musl_COMPLETE_SYSTEM_without_SOURCE_CODE.tar -C /LNX/
mount /dev/nvme0n1p4 /LNX
cd ~ && tar xvf  lnx2025.8_COMPLETE_SYSTEM.tar -C /LNX/

STEP 5) LAUNCH LNX 2.0 (the VM boots, tested 2024-04-18), example only:
===============================================================
grub> set root=(hd0,1)
linux /boot/vmlinuz-${LNX_KERNEL_VERSION} root=/dev/sda1
boot

ldconfig -v
export LNX_CPU_CORES=`nproc`

# Start network:
udhcpc

/BUILD_SYSTEM1
/BUILD_SYSTEM2
/BUILD_SYSTEM3
/BUILD_SYSTEM4
/BUILD_SYSTEM4_2
/BUILD_SYSTEM4_3
/BUILD_SYSTEM4_4
source /etc/profile.d/xorg.sh
/BUILD_SYSTEM5
/BUILD_SYSTEM5_2
/BUILD_SYSTEM5_3
/BUILD_SYSTEM5_4






#Finally, change file ownerships and create the following nodes:
#Change some ownership of nodes:
sudo chown -R root:root $LNX
sudo chgrp 13 $LNX/var/run/utmp $LNX/var/log/lastlog
sudo mknod -m 0666 $LNX/dev/null c 1 3
sudo mknod -m 0600 $LNX/dev/console c 5 1
sudo chmod 4755 $LNX/bin/busybox
