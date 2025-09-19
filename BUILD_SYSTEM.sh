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
export LNX_SOURCE_DIRECTORY=/home/user/Downloads/LNX
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


# LC_ALL=POSIX or "C" will handle input in the environment
export LC_ALL=POSIX

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
# ===================================================================================
# asound.conf: Optimized for low latency, full-duplex and shared access (dmix/dsnoop)
# ===================================================================================

# Ett alias för vårt hårdvarukort för att göra resten enklare
pcm.hw_card {
    type hw
    card 0
}
ctl.hw_card {
    type hw
    card 0
}

# 1. DEFINIERA EN DELAD UPPSpelningSENHET (dmix) - TUNED FOR LOW LATENCY
pcm.dmix_out {
    type dmix
    ipc_key 1024      # Unikt ID för denna mixer
    slave {
        pcm "hw_card"
        # ---- HÄR ÄR OPTIMERINGEN ----
        # Mindre värden här = lägre latency, men högre CPU-last.
        # Experimentera med dessa värden. 512/2048 är en bra start.
        period_size 512
        buffer_size 2048
        # ----------------------------
        rate 48000
        channels 2
    }
}

# 2. DEFINIERA EN DELAD INSPELNINGSENHET (dsnoop)
pcm.dsnoop_in {
    type dsnoop
    ipc_key 1025      # Unikt ID, måste skilja sig från dmix
    slave {
        pcm "hw_card"
        rate 48000
        channels 2
    }
}

# 3. KOMBINERA INSPELNING OCH UPPSPELNING TILL EN DUPLEX-ENHET
# Detta är vad Ardour kommer att använda. "asym" betyder att uppspelning
# och inspelning hanteras av olika (asymmetriska) under-enheter.
pcm.duplex {
    type asym
    playback.pcm "dmix_out"
    capture.pcm "dsnoop_in"
}

# 4. SÄTT VÅR NYA DUPLEX-ENHET SOM SYSTEM-STANDARD
# Alla program som frågar efter "default" kommer nu att använda vår
# låg-latency, delade duplex-enhet.
pcm.!default {
    type plug
    slave.pcm "duplex"
}

# Se till att volymkontroller (amixer) fortfarande pratar direkt med hårdvaran.
ctl.!default {
    type hw
    card 0
}
UNTIL_STOP2



# COPY A PREDEFINED MENU FOR FLUXBOX/TWM:
mkdir $LNX/SOURCE_CODE
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
# Note also that this creates /build-tools/...-unknown-linux-gnu when running make configure-host ...
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
make install-gcc install-target-libgcc

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
# The result should be something like this depending on CPU arch:
# [Requesting program interpreter: /lib/ld-musl-aarch64.so.1]


# --- Done! The entire toolchain is now in $LNX/build-tools ---
# And all necessary C and C++ libraries are in $LNX/usr/lib

# UPDATE THE ENVIRONMENT TO BUILD THE REST OF THE SYSTEM
export PATH=$LNX/build-tools/bin:$PATH
export CC="${LNX_TARGET}-gcc"
export CXX="${LNX_TARGET}-g++"
export CPPFLAGS="-I$LNX/usr/include"
export LDFLAGS="-L$LNX/usr/lib"

# These don't seem to be created on x86 ... but on aarch64 they usually are...but NOT always!
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
# DO NOT INSTALL YET!!!


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
echo -n "Starting virtio-audio: "
modprobe virtio_snd
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
sleep 2
echo -n "Starting eth0: "
ifconfig eth0 up
check_status
sleep 1
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
##cp libstdc++-v3/config/locale/gnu/ctype_members.cc libstdc++-v3/config/locale/gnu/ctype_members.cc_ORG
##vi aarch64-linux-musl/libstdc++-v3/src/c++11/ctype_members.cc
##vi ./libstdc++-v3/config/locale/generic/ctype_members.cc
##diff -u libstdc++-v3/config/locale/gnu/ctype_members.cc libstdc++-v3/config/locale/gnu/ctype_members.cc_ORG > ../patch4.patch
#patch -p1 < $LNX/SOURCE_CODE/gcc-cfenv-musl-fix.patch
#patch -p1 < $LNX/SOURCE_CODE/gcc-fenv.h-musl-fix.patch
#patch -p1 < $LNX/SOURCE_CODE/gcc-cfenv2-musl-fix.patch
patch -p1 < ../patch1.patch
patch -p1 < ../patch2.patch
patch -p1 < ../patch3.patch
patch -p1 < ../patch4.patch
patch -p1 < ../patch5.patch
make -j$LNX_CPU_CORES
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
mount -o ro /dev/vda3 /mnt
#mount -o ro /dev/nvme0n1p6 /mnt

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
# Get Fedora machine-id:
cat /etc/machine-id
ada1319ea6f54481812e84ef67c9655b
# Get the blockid for the disk where LNX is located:
blkid /dev/vda3
#/dev/vda3: UUID="8dc27b24-287a-436f-b9b8-11098f07a4e3" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="952f1861-9c59-4ff7-b871-aed4dd35d7d9"
/dev/vda3: UUID="28bb3e9b-eb91-4b5a-9f42-51cedb531475" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="57908851-3ff3-4a05-a342-910b6718456e"

cd /boot/loader/entries/
vi /boot/loader/entries/custom-otheros.conf
title   LNX Linux
version 2025.10_musl
machine-id ada1319ea6f54481812e84ef67c9655b
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

