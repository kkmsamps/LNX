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
if [ $(uname -m) == "aarch64" ];
then
export LD_LIBRARY_PATH=/build-tools/aarch64-linux-musl/lib64:/build-tools/lib:/build-tools/lib64:/build-tools/aarch64-unknown-linux-gnu/aarch64-linux-musl/lib:/build-tools/aarch64-linux-musl/lib:/build-tools/aarch64-linux-musl/lib64:/lib:/lib64:/usr/lib:/usr/lib64:/usr/lib/xorg/modules/input:/usr/lib64/xorg/modules:/usr/lib64/xorg/modules/drivers:/usr/lib64/xorg/modules/input:/usr/lib64/xorg/modules/extensions:/usr/lib/alsa-lib:/usr/lib/python3.10:/usr/lib/alsa-topology:/usr/lib/dbus-1.0:/usr/lib/bash:/usr/lib/cmake:/usr/lib/engines-3:/usr/lib/jack:/usr/lib64/security
fi
if [ $(uname -m) == "x86_64" ];
then
export LD_LIBRARY_PATH=/build-tools/x86_64-linux-musl/lib64:/build-tools/lib:/build-tools/lib64:/build-tools/x86_64-unknown-linux-gnu/x86_64-linux-musl/lib:/build-tools/x86_64-linux-musl/lib:/build-tools/x86_64-linux-musl/lib64:/lib:/lib64:/usr/lib:/usr/lib64:/usr/lib/xorg/modules/input:/usr/lib64/xorg/modules:/usr/lib64/xorg/modules/drivers:/usr/lib64/xorg/modules/input:/usr/lib64/xorg/modules/extensions:/usr/lib/alsa-lib:/usr/lib/python3.10:/usr/lib/alsa-topology:/usr/lib/dbus-1.0:/usr/lib/bash:/usr/lib/cmake:/usr/lib/engines-3:/usr/lib/jack:/usr/lib64/security
fi

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
# build the complete C/C++ compiler.
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
mount -o ro /dev/vda3 /mnt
#mount -o ro /dev/nvme0n1p4 /mnt

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

export LNX_CPU_CORES=`nproc`


# PERL & BISON (yacc) are needed to be able to compile many programs on target
# when GCC is working on it. GCC needs to be compiled one more time to get rid of references
# to $LNX paths and more.

# BISON
cd /SOURCE_CODE/bison
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make DESTDIR=$LNX install

#flex:
cd /SOURCE_CODE/flex
./autogen.sh
./configure --prefix=/usr
touch src/scan.c
make -j$LNX_CPU_CORES
make install

# FILE
cd /SOURCE_CODE/file
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

#gawk. (awk exists through busybox, but gawk is more capable)
cd /SOURCE_CODE/gawk
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

# LIBFFI
cd /SOURCE_CODE/libffi
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

# Compile NCURSES
# The previously compiled ncurses remains in /usr/lib64, strangely... Why does this one end up in /lib ???
cd /SOURCE_CODE/ncurses
make distclean
make clean
./configure --prefix=/usr \
            --with-shared                \
            --with-cxx-shared            \
            --without-debug              \
            --without-ada   --without-cxx-binding      \
            --disable-stripping
make -j$LNX_CPU_CORES
make install
# The next part doesn't work, they are not installed! Yes, it does!
cd /usr/lib
ln -s libncursesw.so.6 libtinfo.so.6
ln -s libncursesw.so.6 libtinfo.so
ln -s libncursesw.so.6 libncurses.so
ln -s libncursesw.so.6 libncurses.so.6

#python
cd /SOURCE_CODE/Python
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

EOF






cat > $LNX/SOURCE_CODE/BUILD_SYSTEM2 << "EOF"
#!/bin/ash

export LNX_CPU_CORES=`nproc`

# THIS IS NEEDED! Without this, packages will not find /usr/lib64/pkgconfig!
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib64/pkgconfig
# ELFUTILS - NEW 20230324:
# ELFUTILS MUST EXIST!
# It is NOT possible to compile the Linux kernel without ELFUTILS!!! (gelf.h etc. are missing)
cd /SOURCE_CODE/elfutils
./configure --prefix=/usr --disable-debuginfod --disable-libdebuginfod
make -j$LNX_CPU_CORES
make check -j$LNX_CPU_CORES
#make -C libelf install
make install
install -vm644 config/libelf.pc /usr/lib/pkgconfig

# PKG-CONFIG is probably needed, as GNUTLS configure otherwise will not find nettle...
cd $LNX/SOURCE_CODE/pkg-config
make distclean
./configure --prefix=/usr --with-internal-glib
make -j$LNX_CPU_CORES
make install
# THIS IS NEEDED! Without this, packages will not find /usr/lib64/pkgconfig!
#export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib64/pkgconfig

# REMOVED FOR MUSL, 20250701
# Compile MAKE
cd $LNX/SOURCE_CODE/make
make distclean -j8
./configure --prefix=/usr   \
            --without-guile \
            --build=$(build-aux/config.guess)
make -j$LNX_CPU_CORES
make install

# Compile zlib
cd $LNX/SOURCE_CODE/zlib
make distclean
sed -i 's/-O3/-Os/g' configure
./configure --prefix=/usr --shared
make -j$LNX_CPU_CORES
make install

# Compile M4
cd $LNX/SOURCE_CODE/m4
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

#READLINE
cd /SOURCE_CODE/readline
./configure --prefix=/usr    \
            --disable-static \
            --with-curses
make SHLIB_LIBS="-lncursesw"
make install
make SHLIB_LIBS="-lncursesw" install

# REMOVED FOR MUSL, 20250701
# Compile BASH
#cd $LNX/SOURCE_CODE/bash
#make distclean
#./configure --prefix=/usr --enable-readline
#make -j$LNX_CPU_CORES
#make install

# DOES NOT WORK without GLIBC and with GCC having just been recompiled!!!
# PERL
cd $LNX/SOURCE_CODE/perl
make distclean
sh Configure -des                                        \
             -Dprefix=/usr -Dldflags="-B/usr/lib -L/usr/lib" -Dccflags="-I/usr/include -D_GNU_SOURCE -O2"   \
	     -Dcc="`uname -m`-linux-musl-gcc -B/usr/lib" \
             -Dvendorprefix=/usr
make -j$LNX_CPU_CORES
make install

# REMOVED FOR MUSL, 20250701
# Compile AUTOCONF
cd $LNX/SOURCE_CODE/autoconf
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

# REMOVED FOR MUSL, 20250701
# Compile AUTOMAKE
cd $LNX/SOURCE_CODE/automake
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

# TRY TO BUILD OPENSSL AT THIS STAGE!!!
# AFTER OPENSSL/OPENSSH CONTINUE...
# libcrypto and libssl needed for Python pip3 commands!:
cd /SOURCE_CODE/openssl
mkdir -p /etc/ssl/certs
wget --no-check-certificate https://curl.se/ca/cacert.pem
mv cacert.pem /etc/ssl/certs/ca-bundle.crt
make distclean
./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic
make -j$LNX_CPU_CORES
make install


# PKG-CONFIG is probably needed, as GNUTLS configure otherwise will not find nettle...
cd $LNX/SOURCE_CODE/pkg-config
make distclean
./configure --prefix=/usr --with-internal-glib
make -j$LNX_CPU_CORES
make install

# LIBFFI
cd /SOURCE_CODE/libffi
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

# libtasn1
cd /SOURCE_CODE/libtasn1
make distclean
./configure --prefix=/usr --disable-doc
make -j$LNX_CPU_CORES
make install

# libidn2
cd /SOURCE_CODE/libidn2
./configure --prefix=/usr --disable-static --disable-doc
make -j$LNX_CPU_CORES
make install



# GMP needed to build libhogweed in NETTLE source below this:
cd $LNX/SOURCE_CODE/nettle
make distclean
./configure --prefix=/usr --disable-static --enable-shared --enable-arm64-crypto
make -j$LNX_CPU_CORES
make install
chmod   -v   755 /usr/lib64/lib{hogweed,nettle}.so

# NEW at this location also: 2023-03-36.
cd $LNX/SOURCE_CODE/expat
make distclean
./configure --prefix=/usr    \
            --disable-static
make -j$LNX_CPU_CORES
make install


# Check that the compilation succeeds! Sometimes it doesn't work and you need to go through
# line by line and test different arguments etc. Check that /usr/lib/libzstd.so is installed, because it must be!
# sometimes (if you e.g. miss prefix=/usr when running make install) the .so file ends up in /usr/local/lib
cd /SOURCE_CODE/zstd
make prefix=/usr -j$LNX_CPU_CORES
make check -j$LNX_CPU_CORES
make prefix=/usr install
#rm -v /usr/lib/libzstd.a


EOF






cat > $LNX/SOURCE_CODE/BUILD_SYSTEM3 << "EOF"
#!/bin/ash

export LNX_CPU_CORES=`nproc`

# BISON AND FLEX... DOESN'T LOOK LIKE THEY COMPILED SUCCESSFULLY IN BUILD_SYSTEM1
# BISON
cd $LNX/SOURCE_CODE/bison
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make DESTDIR=$LNX install

#flex:
cd /SOURCE_CODE/flex
./autogen.sh
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install


# WiFi:
cd /SOURCE_CODE/wireless_tools
make
make PREFIX=/usr INSTALL_MAN=/usr/share/man install

# WiFi - NETLINK:
cd /SOURCE_CODE/libnl
sed -i '1s|#!/bin/bash|#!/bin/ash|' autogen.sh
./autogen.sh
./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --disable-static
make
make install
rm -f /bin/bash

# WiFi, wpa_supplicant, needed if WEP is not sufficient, which means ALWAYS!
cd /SOURCE_CODE/wpa_supplicant
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
install -v -m644 doc/docbook/wpa_cli doc/docbook/wpa_passphrase doc/docbook/wpa_supplicant.8 /usr/share/man/man8/
mkdir -p /etc/sysconfig
wpa_passphrase str8464 FD27458249 > /etc/sysconfig/wpa_supplicant-wlan0.conf
ifconfig wlan0 up
ifup wlan0


#libcap:
cd /SOURCE_CODE/libcap
make distclean
make prefix=/usr/lib
#make
# Rerun the compilation to avoid:
#/bin/sh: ./mkcapshdoc.sh: not found. -> #make[1]: *** [Makefile:49: capshdoc.c.cf] Error 127
make prefix=/usr/lib
make test
# THIS WORKS:
make prefix=/usr/lib install
# NEXT LINE IS REMOVED 20250101, libcap should not be in /usr
#make prefix=/usr install


#libtool:
cd /SOURCE_CODE/libtool
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

#gettext:
cd /SOURCE_CODE/gettext
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

# MOVED TO AN EARLIER STAGE, but should be compiled here as well... Probably...
# libcrypto and libssl needed for Python pip3 commands!:
#cd /SOURCE_CODE/openssl
#make distclean
#./config --prefix=/usr         \
#         --openssldir=/etc/ssl \
#         --libdir=lib          \
#         shared                \
#         zlib-dynamic
#make -j$LNX_CPU_CORES
#make install

# MOVED TO AN EARLIER STAGE, but should be compiled here as well, probably...
#python
cd /SOURCE_CODE/Python
make distclean
./configure --prefix=/usr --with-openssl=/usr
make -j$LNX_CPU_CORES
make install

#libxml2
cd /SOURCE_CODE/libxml2
make distclean
# Next step is a workaround for Python 3.10, as libxml2 expects 3.1:
autoreconf -fiv
./configure --prefix=/usr  \
	--sysconfdir=/etc       \
     	--disable-static        \
      	--with-history          \
	PYTHON=/usr/bin/python3
make -j$LNX_CPU_CORES
make install


# itstool:
cd /SOURCE_CODE/itstool
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

#libxslt
cd /SOURCE_CODE/libxslt
# Next step is a workaround for Python 3.10, as libxslt expects 3.1:
autoreconf -fiv
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

# ninja  DOESN'T SEEM TO WORK WITH MY MUSL LIBC VERSION... install via pip3 instead...
#cd /SOURCE_CODE/ninja-build
#python3 configure.py --bootstrap
#install -vm755 ninja /usr/bin/
#install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
#install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja

#####################################
#
# meson. (requires internet access)
#
#####################################
cd /SOURCE_CODE/meson
pip3 install --upgrade pip
#pip3 wheel -w dist --no-build-isolation --no-deps $PWD
pip3 install meson
pip3 install ninja


#pcre:
cd /SOURCE_CODE/pcre2
rm -rf build
mkdir build
cd build
export GCC_VERSION=$(ls /build-tools/`uname -m`-linux-musl/include/c++/)
export CPLUS_INCLUDE_PATH=/build-tools/`uname -m`-linux-musl/include/c++/$GCC_VERSION:/usr/include
# FOR ORDINARY PCRE: ../configure --prefix=/usr --enable-utf --enable-pcre16 --enable-pcre32 --enable-jit --enable-unicode-properties
../configure --prefix=/usr --enable-utf --enable-pcre2-16 --enable-pcre2-32 --enable-jit --enable-unicode-properties
make -j$LNX_CPU_CORES
make install
export CPLUS_INCLUDE_PATH=/usr/include



cd /SOURCE_CODE/libpsl
./autogen.sh
#make distclean
#./configure --prefix=/usr --disable-static
#make -j$LNX_CPU_CORES
#make install
rm -rf build
mkdir build
cd build
meson setup --prefix=/usr --buildtype=release
ninja
ninja install


cd /SOURCE_CODE/libiconv
#make distclean
#./configure --prefix=/usr
#make -j$LNX_CPU_CORES
#make install

unset LDFLAGS CFLAGS CXXFLAGS CPPFLAGS
cd /SOURCE_CODE/git
make distclean
make configure
./configure --prefix=/usr LIBS="-lssl -lcrypto -lz"   \
          --with-openssl=/usr  --disable-static
make -j$LNX_CPU_CORES
make install
# Config git to use the certificate we configured in the openssl section:
git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt



cd /SOURCE_CODE/gperf
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install


# Critical for flatpak, docker, podman etc. Places a standard security profile on all containers etc.
cd /SOURCE_CODE/libseccomp
./autogen.sh
make distclean
./configure --prefix=/usr --disable-static
#PATH=/SOURCE_CODE/libseccomp/src:$PATH make -j$LNX_CPU_CORES
sed -i.bak '1s#/bin/bash#/bin/ash#' src/arch-gperf-generate
make
make install

# CURL MUST BE COMPILED BEFORE GIT, as git depends on it, or run this script twice!
cd /SOURCE_CODE/curl
make distclean
./configure --prefix=/usr --with-openssl --enable-threaded-resolver --with-ca-path=/etc/ssl/certs
make -j$LNX_CPU_CORES
make install

# libunistring MUST be built before libpsl as libpsl depends on it, move this or run the script twice
cd /SOURCE_CODE/libunistring
make distclean
./configure --prefix=/usr --disable-static
make -j$LNX_CPU_CORES
make install

EOF






cat > $LNX/SOURCE_CODE/BUILD_SYSTEM4 << "EOF"
#!/bin/ash

export LNX_CPU_CORES=`nproc`

# glib: doesn't work with musl...
cd /SOURCE_CODE/glib
rm -rf build
mkdir build
cd    build
meson --prefix=/usr       \
      --buildtype=release \
      -Dman-pages=false          \
      ..
ninja
ninja install
#mkdir -p /usr/share/doc/glib-2.72.3 &&
#cp -r ../docs/reference/{gio,glib,gobject} /usr/share/doc/glib-2.72.3
#pip3 install glib
# good to have pip-search installed to search pip3 packages
pip3 install pip-search


#Freetype2:
cd /SOURCE_CODE/freetype
#make distclean
#./configure --prefix=/usr
#make -j$LNX_CPU_CORES
#make install
rm -rf build
mkdir build
cd build
meson --prefix=/usr --buildtype=release -Dpng=disabled ..
ninja -J$CPU_CORES
ninja install

cd /SOURCE_CODE/gperf
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

#Fontconfig:
cd /SOURCE_CODE/fontconfig
make distclean
./configure --prefix=/usr --enable-libxml2 --sysconfdir=/etc    \
            --localstatedir=/var \
            --disable-docs
make -j$LNX_CPU_CORES
make install

# FROM LFS BLFS HANDBOOK:
export XORG_PREFIX="/usr"
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
mkdir /etc/profile.d
cat > /etc/profile.d/xorg.sh << END_INNER
XORG_PREFIX="$XORG_PREFIX"
XORG_CONFIG="--prefix=\$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export XORG_PREFIX XORG_CONFIG
END_INNER
chmod 644 /etc/profile.d/xorg.sh
mkdir /etc/sudoers.d
cat > /etc/sudoers.d/xorg << END_INNER2
Defaults env_keep += XORG_PREFIX
Defaults env_keep += XORG_CONFIG
END_INNER2

cat >> /etc/profile.d/xorg.sh << "END_INNER3"
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/share/pkgconfig
export C_INCLUDE_PATH=/usr/include
export CPLUS_INCLUDE_PATH=/usr/include
ACLOCAL="aclocal -I $XORG_PREFIX/share/aclocal"
END_INNER3

####################################################
# Load the environment variables that were created:
source /etc/profile.d/xorg.sh
####################################################

cd /SOURCE_CODE/util-macros
make distclean
./configure $XORG_CONFIG
#make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/xorgproto
make distclean
./configure $XORG_CONFIG
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/libXau
#make distclean
#./configure $XORG_CONFIG
#make -j$LNX_CPU_CORES
#make install
rmdir -rf build
mkdir build
cd build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install

cd /SOURCE_CODE/xcb-proto
make distclean
./configure $XORG_CONFIG
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/libXdmcp
make distclean
./configure $XORG_CONFIG
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/libxcb
make distclean
./configure $XORG_CONFIG
make -j$LNX_CPU_CORES
make install

# Compile all Xlibs:
# KS idea from 0.8a:
cd /SOURCE_CODE/Xlib
# The cpp link below is needed for libX11 and some more X.org libs.
ln -s /build-tools/bin/`uname -m`-lnx-linux-gnu-cpp /build-tools/bin/cpp
rm -f COMPIL*
for package in $(ls -d *|grep -v tar);
do
echo  "cd " $package >> COMPILE
echo "make distclean" >> COMPILE
echo "rm -rf build" >> COMPILE
echo "mkdir build" >> COMPILE
echo "cd build" >> COMPILE
echo "echo $package" >> COMPILE
echo "../configure $XORG_CONFIG" >>COMPILE
echo "make -j`nproc`" >>COMPILE
echo "make install" >>COMPILE
echo "meson --prefix=/usr --buildtype=release .." >>COMPILE
echo "ninja" >>COMPILE
echo "ninja install" >>COMPILE
echo "ldconfig" >>COMPILE
echo "cd ../.." >>COMPILE
done
chmod 755 COMPILE
echo -e "Building Xlibs pass 1/4..."
./COMPILE > COMPILE.log 2>&1
echo -e "Building Xlibs pass 2/4..."
./COMPILE > COMPILE.log 2>&1
echo -e "Building Xlibs pass 3/4..."
./COMPILE > COMPILE.log 2>&1
echo -e "Building Xlibs pass 4/4..."
./COMPILE > COMPILE.log 2>&1
EOF


cat > $LNX/SOURCE_CODE/BUILD_SYSTEM4_1 << "EOF"
#!/bin/ash

export LNX_CPU_CORES=`nproc`


#THIS IS THE COMPLICATED LLVM/CLANG BUILD SYSTEM NEEDED BY MESA, Intel special drivers
# The LLVM/llvm dir will host the source code for the whole llvm distribution.
# LLVM/cmake and LLVM/third-party will be placed as-is, next to the main llvm source code directory.
# LLVM/clang and LLVM/compiler-rt must be moved to LLVM/llvm/tools and LLVM/llvm/resources respectively.
#
cd /SOURCE_CODE/
# Unpack a static compiler:
tar zxf $(uname -m)-linux-musl-native.tgz -C /
cd /SOURCE_CODE/llvm-project/
#yes|mv llvm-third-party third-party
#yes|mv cmake2 cmake
#cd llvm
#yes|mv ../clang tools/
#yes|mv ../compiler-rt resources/
rm -rf build
mkdir -v build
cd       build
#	CC=gcc CXX=g++                               \
#CXXFLAGS="-D__locale_t=locale_t"  \
PATH=/$(uname -m)-linux-musl-native/bin:$PATH \
#LD_LIBRARY_PATH=/$(uname -m)-linux-musl-native/lib:$LD_LIBRARY_PATH \
unset LDFLAGS CXX CPP CC CXXFLAGS CPPFLAGS CFLAGS
#LDFLAGS="-L/$(uname -m)-linux-musl-native/include" \
cmake -G Ninja ../llvm \
	-DCMAKE_CXX_STANDARD=17 \
	-DCMAKE_CXX_STANDARD_REQUIRED=ON \
	-DCMAKE_CXX_EXTENSIONS=ON \
	-DLLVM_ENABLE_BINDINGS=OFF \
	-DLLVM_INCLUDE_BENCHMARKS:BOOL=OFF \
	-DLLVM_INCLUDE_TESTS:BOOL=OFF \
	-DLLVM_INCLUDE_EXAMPLES:BOOL=OFF \
	-DCMAKE_C_COMPILER=/$(uname -m)-linux-musl-native/bin/$(uname -m)-linux-musl-gcc \
	-DCMAKE_CXX_COMPILER=/$(uname -m)-linux-musl-native/bin/$(uname -m)-linux-musl-g++ \
	-DCMAKE_REQUIRED_LIBRARIES=pthread \
       -DLLVM_ENABLE_LIBCXX:BOOL=TRUE \
       -DCMAKE_INSTALL_PREFIX=/usr           \
	-DCMAKE_PREFIX_PATH="/usr;/$(uname -m)-linux-musl-native"	\
      -DCMAKE_BUILD_TYPE=Release            \
     -DLLVM_ENABLE_PROJECTS='' \
      -DLLVM_ENABLE_RUNTIMES=''	     \
	-DLLVM_ENABLE_ZSTD:BOOL=OFF \
      -DLLVM_TARGETS_TO_BUILD=Native
ninja
ninja install



PATH=/$(uname -m)-linux-musl-native/bin:$PATH \

cd /SOURCE_CODE/SPIRV-Headers
mkdir build
cd    build
cmake -DCMAKE_INSTALL_PREFIX=/usr -G Ninja ..
ninja
ninja install

cd /SOURCE_CODE/SPIRV-Tools
rm -rf build
mkdir build
cd    build
#export GCC_VERSION=$(ls /build-tools/`uname -m`-linux-musl/include/c++/)
#export CPLUS_INCLUDE_PATH=/build-tools/`uname -m`-linux-musl/include/c++/$GCC_VERSION
export CFLAGS="-isystem /$(uname -m)-linux-musl-native/include"
export CXXFLAGS="-isystem /$(uname -m)-linux-musl-native/include/c++/11.2.1 -isystem /$(uname -m)-linux-musl-native/include/c++/11.2.1/$(uname -m)-linux-musl"
cmake -DCMAKE_INSTALL_PREFIX=/usr     \
	-DCMAKE_CXX_STANDARD=17 \
	-DCMAKE_CXX_STANDARD_REQUIRED=ON \
	-DCMAKE_CXX_EXTENSIONS=ON \
	-DLLVM_ENABLE_BINDINGS=OFF \
	-DCMAKE_C_COMPILER=/build-tools/bin/$(uname -m)-linux-musl-gcc \
	-DCMAKE_CXX_COMPILER=/build-tools/bin/$(uname -m)-linux-musl-g++ \
	-DCMAKE_PREFIX_PATH="/usr:/$(uname -m)-linux-musl-native" \
      -DCMAKE_BUILD_TYPE=Release      \
      -DSPIRV_WERROR=OFF              \
      -DBUILD_SHARED_LIBS=ON          \
      -DSPIRV_TOOLS_BUILD_STATIC=OFF  \
      -DSPIRV-Headers_SOURCE_DIR=/usr \
      -G Ninja ..
ninja
ninja install




PATH=/$(uname -m)-linux-musl-native/bin:$PATH \
unset LDFLAGS CXX CPP CC CXXFLAGS CPPFLAGS CFLAGS
export CFLAGS="-isystem /$(uname -m)-linux-musl-native/include"
export CXXFLAGS="-isystem /$(uname -m)-linux-musl-native/include/c++/11.2.1 -isystem /$(uname -m)-linux-musl-native/include/c++/11.2.1/$(uname -m)-linux-musl"


cd /SOURCE_CODE/glslang
rm -rf build
mkdir build
cd    build
#export GCC_VERSION=$(ls /build-tools/`uname -m`-linux-musl/include/c++/)
#export CPLUS_INCLUDE_PATH=/build-tools/`uname -m`-linux-musl/include/c++/$GCC_VERSION
cmake -DCMAKE_INSTALL_PREFIX=/usr     \
	-DCMAKE_CXX_STANDARD=17 \
	-DCMAKE_CXX_STANDARD_REQUIRED=ON \
	-DCMAKE_CXX_EXTENSIONS=ON \
	-DCMAKE_C_COMPILER=/build-tools/bin/$(uname -m)-linux-musl-gcc \
	-DCMAKE_CXX_COMPILER=/build-tools/bin/$(uname -m)-linux-musl-g++ \
	-DCMAKE_PREFIX_PATH="/usr:/$(uname -m)-linux-musl-native" \
      -DCMAKE_BUILD_TYPE=Release      \
      -DALLOW_EXTERNAL_SPIRV_TOOLS=ON \
      -DBUILD_SHARED_LIBS=ON          \
      -DGLSLANG_TESTS=ON              \
      -G Ninja ..
ninja
ninja install



# DOESN'T SEEM TO BUILD, requires clang...
#export CPLUS_INCLUDE_PATH=/build-tools/$(uname -m)-linux-musl/include/c++/14.1.0
cd /SOURCE_CODE/libclc
rm -rf build
mkdir build
cd    build
cmake -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_BUILD_TYPE=Release -G Ninja ..
ninja
ninja install



PATH=/$(uname -m)-linux-musl-native/bin:$PATH \
unset LDFLAGS CXX CPP CC CXXFLAGS CPPFLAGS CFLAGS
export CFLAGS="-isystem /$(uname -m)-linux-musl-native/include"
export CXXFLAGS="-isystem /$(uname -m)-linux-musl-native/include/c++/11.2.1 -isystem /$(uname -m)-linux-musl-native/include/c++/11.2.1/$(uname -m)-linux-musl"


source /etc/profile.d/xorg.sh

cd /SOURCE_CODE/mesa
# Remove a line that makes a wrong Mako check... only for this release!
sed -i '935s/^/#/' meson.build
pip3 install PyYAML
#export GCC_VERSION=$(ls /build-tools/`uname -m`-linux-musl/include/c++/)
#export CPLUS_INCLUDE_PATH=/build-tools/`uname -m`-linux-musl/include/c++/$GCC_VERSION
rm -rf build
mkdir build
cd    build
meson setup                   \
      --prefix=$XORG_PREFIX   \
      --buildtype=release     \
      -Dplatforms=x11 \
	-Dglx=dri \
	-Dgallium-drivers=virgl,i915,iris \
      -Dvalgrind=disabled     \
      -Dlibunwind=disabled    \
	-Dllvm=disabled       \
	-Dvulkan-drivers=intel   \
      ..
ninja
ninja install

EOF





cat > $LNX/SOURCE_CODE/BUILD_SYSTEM4_2 << "EOF"
#!/bin/ash

export LNX_CPU_CORES=`nproc`



####################################################
# Load the environment variables that were created:
source /etc/profile.d/xorg.sh
####################################################

export CPLUS_INCLUDE_PATH=/usr/include
export CPLUS_INCLUDE_PATH=/build-tools/$(uname -m)-linux-musl/include/c++/14.1.0:/build-tools/lib/gcc/$(uname -m)-linux-musl/14.1.0/plugin/include

cd /SOURCE_CODE/libxcvt
rm -rf build
mkdir build &&
cd    build &&
meson setup --prefix=$XORG_PREFIX --buildtype=release ..
ninja
ninja install

cd /SOURCE_CODE/xcb-util
make distclean
./configure $XORG_CONFIG
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/xcb-util-image
make distclean
./configure $XORG_CONFIG
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/xcb-util-keysyms
make distclean
./configure $XORG_CONFIG
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/xcb-util-renderutil
make distclean
./configure $XORG_CONFIG
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/xcb-util-wm
make distclean
./configure $XORG_CONFIG
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/xcb-util-cursor
make distclean
./configure $XORG_CONFIG
make -j$LNX_CPU_CORES
make install



cd /SOURCE_CODE/libdrm
mkdir build
cd    build
meson setup --prefix=$XORG_PREFIX \
            --buildtype=release   \
            -Dudev=true           \
            -Dvalgrind=disabled   \
            ..
ninja
ninja install

cd /SOURCE_CODE/Mako
pip3 wheel -w dist --no-deps --no-cache-dir $PWD
pip3 install --no-cache-dir --no-user Mako


export CPLUS_INCLUDE_PATH=/build-tools/$(uname -m)-linux-musl/include/c++/14.1.0
cd /SOURCE_CODE/SPIRV-LLVM-Translator
mkdir build
cd    build
cmake -D CMAKE_INSTALL_PREFIX=/usr                   \
      -D CMAKE_BUILD_TYPE=Release                    \
      -D BUILD_SHARED_LIBS=ON                        \
      -D CMAKE_SKIP_INSTALL_RPATH=ON                 \
      -D LLVM_EXTERNAL_SPIRV_HEADERS_SOURCE_DIR=/usr \
      -G Ninja ..
ninja
ninja install

#export CPLUS_INCLUDE_PATH=/build-tools/$(uname -m)-linux-musl/include/c++/14.1.0
#cd /SOURCE_CODE/libclc
#mkdir build
#cd    build
#cmake -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_BUILD_TYPE=Release -G Ninja ..
#ninja
#ninja install

cd /SOURCE_CODE/xbitmaps
make distclean
./configure $XORG_CONFIG
make install

cd /SOURCE_CODE/libpng
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/xclock
make distclean
./configure $XORG_CONFIG
make -j$LNX_CPU_CORES
make install

EOF




cat > $LNX/SOURCE_CODE/BUILD_SYSTEM4_3 << "EOF"
#!/bin/ash

export LNX_CPU_CORES=`nproc`

####################################################
# Load the environment variables that were created:
source /etc/profile.d/xorg.sh
####################################################

# Compile all XApps:
# KS idea from 0.8a:
cd /SOURCE_CODE/XApps
# The cpp link below is needed for libX11 and some more X.org libs.
#ln -s /build-tools/bin/`uname -m`-linux-musl-cpp /build-tools/bin/cpp
rm -f COMPIL*
for package in $(ls -d *|grep -v tar);
do
echo  "cd " $package >> COMPILE
echo "make distclean" >> COMPILE
echo "rm -rf build" >> COMPILE
echo "mkdir build" >> COMPILE
echo "cd build" >> COMPILE
echo "../configure $XORG_CONFIG" >>COMPILE
echo "make -j`nproc`" >>COMPILE
echo "make install" >>COMPILE
echo "meson --prefix=/usr --buildtype=release .." >>COMPILE
echo "ninja" >>COMPILE
echo "ninja install" >>COMPILE
echo "ldconfig" >>COMPILE
echo "cd ../.." >>COMPILE
done
chmod 755 COMPILE
echo -e "Building XApps pass 1/4..."
./COMPILE > COMPILE.log 2>&1
echo -e "Building XApps pass 2/4..."
./COMPILE > COMPILE.log 2>&1
echo -e "Building XApps pass 3/4..."
./COMPILE > COMPILE.log 2>&1
echo -e "Building XApps pass 4/4..."
./COMPILE > COMPILE.log 2>&1

cd /SOURCE_CODE/luit
make distclean
./configure $XORG_CONFIG
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/xcursor-themes
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

# Compile all XFonts:
# KS idea from 0.8a:
cd /SOURCE_CODE/XFonts
# The cpp link below is needed for libX11 and some more X.org libs.
#ln -s /build-tools/bin/`uname -m`-lnx-linux-gnu-cpp /build-tools/bin/cpp
rm -f COMPIL*
for package in $(ls -d *|grep -v tar);
do
echo  "cd " $package >> COMPILE
echo "make distclean" >> COMPILE
echo "rm -rf build" >> COMPILE
echo "mkdir build" >> COMPILE
echo "cd build" >> COMPILE
echo "../configure $XORG_CONFIG" >>COMPILE
echo "make -j`nproc`" >>COMPILE
echo "make install" >>COMPILE
echo "meson --prefix=/usr --buildtype=release .." >>COMPILE
echo "ninja" >>COMPILE
echo "ninja install" >>COMPILE
echo "ldconfig" >>COMPILE
echo "cd ../.." >>COMPILE
done
chmod 755 COMPILE
echo -e "Building XFonts pass 1/4..."
./COMPILE > COMPILE.log 2>&1
echo -e "Building XFonts pass 2/4..."
./COMPILE > COMPILE.log 2>&1
echo -e "Building XFonts pass 3/4..."
./COMPILE > COMPILE.log 2>&1
echo -e "Building XFonts pass 4/4..."
./COMPILE > COMPILE.log 2>&1
install -v -d -m755 /usr/share/fonts
ln -svfn $XORG_PREFIX/share/fonts/X11/OTF /usr/share/fonts/X11-OTF
ln -svfn $XORG_PREFIX/share/fonts/X11/TTF /usr/share/fonts/X11-TTF

cd /SOURCE_CODE/xkeyboard-config
mkdir build
cd    build
meson setup --prefix=$XORG_PREFIX --buildtype=release ..
ninja
ninja install

cd /SOURCE_CODE/pixman
rm -rf build
mkdir build
cd    build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install

cd /SOURCE_CODE/libepoxy
rm -rf build
mkdir build
cd    build
meson setup --prefix=/usr -Dtests=false -Ddocs=false --buildtype=release ..
ninja
ninja install

# From BUILD_SYSTEM2. Doesn't seem to build there, required for xorg-server...
cd /SOURCE_CODE/libxcvt
mkdir build &&
cd    build &&
meson setup --prefix=$XORG_PREFIX --buildtype=release ..
ninja
ninja install


cd /SOURCE_CODE/xorg-server
rm -rf build
mkdir build
cd    build
meson setup ..              \
      --prefix=$XORG_PREFIX \
      --localstatedir=/var  \
      -Dglamor=true  -Dsecure-rpc=false      \
      -Dxkb_output_dir=/var/lib/xkb -Dudev=false -Dudev_kms=false -Dhal=false
ninja
ninja install
mkdir -pv /etc/X11/xorg.conf.d
install -v -d -m1777 /tmp/.{ICE,X11}-unix
cat >> /etc/sysconfig/createfiles << "ENDOFFILE"
/tmp/.ICE-unix dir 1777 root root
/tmp/.X11-unix dir 1777 root root
ENDOFFILE

EOF





cat > $LNX/SOURCE_CODE/BUILD_SYSTEM4_4 << "EOF"
#!/bin/ash

ldconfig -v
export LNX_CPU_CORES=`nproc`

####################################################
# Load the environment variables that were created:
source /etc/profile.d/xorg.sh
####################################################

cd /SOURCE_CODE/mtdev
make distclean
./configure --prefix=/usr --disable-static
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/libevdev
#mkdir build
#cd    build
#meson setup ..                 \
#      --prefix=$XORG_PREFIX    \
#      --buildtype=release      \
#      -Ddocumentation=disabled
#ninja
#ninja install
./configure $XORG_CONFIG
make
make install

cd /SOURCE_CODE/xf86-input-evdev
./configure $XORG_CONFIG
make
make install

cd /SOURCE_CODE/xf86-input-mouse
./configure $XORG_CONFIG
make
make install

cd /SOURCE_CODE/xf86-input-keyboard
./configure $XORG_CONFIG
make
make install

cd /SOURCE_CODE/xf86-input-synaptics
./configure $XORG_CONFIG
make
make install

cd /SOURCE_CODE/twm
sed -i -e '/^rcdir =/s,^\(rcdir = \).*,\1/etc/X11/app-defaults,' src/Makefile.in
./configure $XORG_CONFIG
make
make install


cd /SOURCE_CODE/xinit
./configure $XORG_CONFIG --with-xinitdir=/etc/X11/app-defaults
make
make install

EOF







cat > $LNX/SOURCE_CODE/BUILD_SYSTEM5 << "EOF"
#!/bin/ash

export LNX_CPU_CORES=`nproc`

source /etc/profile.d/xorg.sh

cd /SOURCE_CODE/libarchive
make distclean
# FROM LFS: First, adapt the package to changes in glibc-2.36 ->:
sed '/linux\/fs\.h/d' -i libarchive/archive_read_disk_posix.c
./configure --prefix=/usr --disable-static
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/sqlite-autoconf
make distclean
./configure --prefix=/usr --disable-static
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/nghttp2
make distclean
./configure --prefix=/usr --disable-static
make -j$LNX_CPU_CORES
make install


cd /SOURCE_CODE/glib-networking
rm -rf build
mkdir build
cd    build
meson --prefix=/usr --buildtype=release -Dlibproxy=disabled -Dgnome_proxy=disabled -Dopenssl=enabled
ninja
ninja install

cd /SOURCE_CODE/vala
make distclean
./configure --prefix=/usr --disable-valadoc
make -j$LNX_CPU_CORES
make install


# THIS IS FROM MUCH EARLIER IN THE DOCUMENT, ALREADY COMPILED, but there seems to be strange errors...
cd /SOURCE_CODE/gmp
make distclean -j8
./configure --prefix=/usr --disable-static
make -j$LNX_CPU_CORES
make check
make install



cd /SOURCE_CODE/libxcrypt
./autogen.sh
make distclean
./configure --prefix=/usr                \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=no     \
            --disable-static             \
            --disable-failure-tokens
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/expat
make distclean
./configure --prefix=/usr    \
            --disable-static
make -j$LNX_CPU_CORES
make install
EOF






cat > $LNX/SOURCE_CODE/BUILD_SYSTEM5_2 << "EOF"
#!/bin/ash

export LNX_CPU_CORES=`nproc`

source /etc/profile.d/xorg.sh


cd /SOURCE_CODE/xz
./autogen.sh
make distclean
./configure --prefix=/usr    \
            --disable-static
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/e2fsprogs
rm -rf build
mkdir -v build
cd       build
../configure --prefix=/usr           \
             --sysconfdir=/etc      \
--enable-libblkid      \
             --enable-libuuid       \
             --disable-uuidd         \
--enable-blkid-debug    \
--disable-debugfs --disable-debugfs  --disable-resizer --disable-defrag --disable-tls  --disable-mmp \
--disable-tdb \
             --disable-fsck
make -j$LNX_CPU_CORES
mkdir /usr/include/et/
touch /usr/include/et/com_err.h
mkdir /usr/share/et/
touch /usr/share/et/et_c.awk
mkdir /usr/include/ss/
touch /usr/include/ss/ss.h
mkdir /usr/share/ss/
touch /usr/share/ss/ct_c.sed
mkdir /usr/include/e2p/
touch /usr/include/e2p/e2p.h
mkdir /usr/include/uuid/
touch /usr/include/uuid/uuid.h
mkdir /usr/include/blkid/
touch /usr/include/blkid/blkid.h
mkdir /usr/include/ext2fs/
touch /usr/include/ext2fs/hashmap.h
make install
# cp ./lib/e2p/e2p.pc /usr/lib/pkgconfig/

cd /SOURCE_CODE/util-linux
make distclean
./configure --prefix=/usr \
	    --bindir=/usr/bin    \
            --libdir=/usr/lib    \
            --sbindir=/usr/sbin  \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-systemdsystemunitdir
make -j$LNX_CPU_CORES
make install

EOF




cat > $LNX/SOURCE_CODE/BUILD_SYSTEM5_3 << "EOF"
#!/bin/ash

export LNX_CPU_CORES=`nproc`

source /etc/profile.d/xorg.sh

cd /SOURCE_CODE/XML-Parser
perl Makefile.PL
make
make test
make install

cd /SOURCE_CODE/intltool
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install


cd /SOURCE_CODE/nasm
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/libjpeg-turbo
rm -rf build
mkdir build
cd    build
cmake -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_BUILD_TYPE=RELEASE  \
      -DENABLE_STATIC=FALSE  -DCMAKE_POLICY_VERSION_MINIMUM=3.5     \
      -DCMAKE_INSTALL_DOCDIR=/usr/share/doc/libjpeg-turbo \
      -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib  \
      ..
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/shared-mime-info
rm -rf build
mkdir build
cd    build
meson --prefix=/usr --buildtype=release ..
ninja
ninja install

cd /SOURCE_CODE/libpng
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/gdk-pixbuf
rm -rf build
mkdir build
cd    build
meson --prefix=/usr --buildtype=release -Dman=false -Dtests=false \
--libdir=/usr/lib \
  --sysconfdir=/etc \
  --mandir=/usr/man ..
ninja
ninja install

cd /SOURCE_CODE/yaml
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install



# Also critical for podman (but not for flatpak).
cd /SOURCE_CODE/libfuse
rm -rf build
mkdir build
cd    build
meson --prefix=/usr --buildtype=release  \
 -Dexamples=false \
 -Dtests=false \
 -Ddisable-mtab=false \
 -Dutils=true \
 ..
ninja
ninja install

export CPLUS_INCLUDE_PATH=/usr/include


# glib:
cd /SOURCE_CODE/glib
rm -rf build
mkdir build
cd    build
meson --prefix=/usr       \
      --buildtype=release \
      -Dman=false          \
      ..
ninja
ninja install


EOF






cat > $LNX/SOURCE_CODE/BUILD_SYSTEM5_4<< "EOF"
#!/bin/ash

export LNX_CPU_CORES=`nproc`

source /etc/profile.d/xorg.sh
export CPLUS_INCLUDE_PATH=/build-tools/$(uname -m)-linux-musl/include/c++/14.1.0



cd /SOURCE_CODE/dbus
mkdir build
cd build
meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback -Dsystemd=disabled ..
ninja
ninja install

# Must be compiled later, needs PAM to work with PAM
#cd /SOURCE_CODE/xlockmore
#./configure --prefix=/usr --without-gtk --without-gtk2 --without-mesa --without-opengl
#make -j$LNX_CPU_CORES
#make install

# Install NLS for every language...
localedef -i sv_SE -f UTF-8 UTF-8
setxkbmap -model pc105 -layout se

cd /SOURCE_CODE/iptables
make distclean
export CFLAGS=" -D__UAPI_DEF_ETHHDR=0"
./configure --prefix=/usr --disable-nftables --enable-libipq
make  -j$LNX_CPU_CORES
make install
export CFLAGS="-B/usr/lib -I/usr/include"



cd /SOURCE_CODE/alsa-lib
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/alsa-plugins
./configure --prefix=/usr --sysconfdir=/etc
make -j$LNX_CPU_CORES
make install

cd /SOURCE_CODE/alsa-utils
./configure --disable-alsaconf \
            --disable-bat      \
            --disable-xmlto
make -j$LNX_CPU_CORES
make install
ldconfig
cd /SOURCE_CODE/blfs-bootscripts
make install-alsa
cd /etc/rc.d/init.d
sed '28 s/./#&/' alsa > alsa2 && rm alsa && mv alsa2 alsa
sed '32 s/./#&/' alsa > alsa2 && rm alsa && mv alsa2 alsa
sed '34 s/./#&/' alsa > alsa2 && rm alsa && mv alsa2 alsa
sed '38 s/./#&/' alsa > alsa2 && rm alsa && mv alsa2 alsa
sed '40 s/./#&/' alsa > alsa2 && rm alsa && mv alsa2 alsa
chmod 754 alsa
sed '36 s/./#&/' dbus > dbus2 && rm dbus && mv dbus2 dbus
sed '40 s/./#&/' dbus > dbus2 && rm dbus && mv dbus2 dbus
sed '44 s/./#&/' dbus > dbus2 && rm dbus && mv dbus2 dbus
sed '46 s/./#&/' dbus > dbus2 && rm dbus && mv dbus2 dbus
sed '39 s/start_daemon//' dbus > dbus2 && rm dbus && mv dbus2 dbus
chmod 754 dbus

# COPY A PREDEFINED MENU FOR FLUXBOX, GRAPHICS, SOUND and more
chown user:user -R /home/user/
cp ~/START /home/user
cp ~/WIFI /home/user
cp ~/LOCALE /home/user
mv ~/xorg.conf /etc/X11/xorg.conf.d/
cp ~/SOUND /home/user
mv ~/xinitrc /etc/X11/app-defaults/


XORG_PREFIX="/usr"
XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export XORG_PREFIX XORG_CONFIG
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/share/pkgconfig
#export C_INCLUDE_PATH=/usr/include
#export CPLUS_INCLUDE_PATH=/usr/include

# This is important to add cut/paste without whitespaces/tabs to Xterm!
#sed -i '7i\xrdb -merge ~/.Xresources' ~/.fluxbox/startup
#chmod +x ~/.fluxbox/startup


#cd /SOURCE_CODE/jack2
#./waf distclean
##./waf configure --prefix=/usr --dbus --profile --alsa=yes --systemd=no
#./waf configure --prefix=/usr --classic --profile --alsa=yes  --systemd=no
#./waf
#./waf install

# FIX DBUS-PYTHON:
export CC="/build-tools/bin/`uname -m`-linux-musl-gcc -lm"
pip3 install dbus-python
export CC=/build-tools/bin/`uname -m`-linux-musl-gcc



cd /SOURCE_CODE/dejavu-fonts-ttf
install -v -d -m755 /usr/share/fonts/dejavu
install -v -m644 ttf/*.ttf /usr/share/fonts/dejavu
fc-cache -v /usr/share/fonts/dejavu

# Run as a container instead
#cd /SOURCE_CODE/nmap
#make distclean
#./configure --prefix=/usr  --without-zenmap --without-ncat --without-ndiff
#make -j$LNX_CPU_CORES
#make install


#LAST TOUCHES ON THE TARGET SYSTEM TO MAKE THE SYSTEM READY:
dbus-uuidgen --ensure

echo "user:100000:65536" > /etc/subuid
echo "user:100000:65536" > /etc/subgid


cd /SOURCE_CODE/libslirp
rm -rf build
mkdir build
cd build
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install

cd /SOURCE_CODE/slirp4netns
git checkout v1.3.3
./autogen.sh
./configure --prefix=/usr
make
make install

cd /SOURCE_CODE/libfuse
meson setup build --prefix=/usr
ninja -C build
ninja -C build install

cd /SOURCE_CODE/fuse-overlayfs
./autogen.sh
./configure --prefix=/usr
make
make install

# prereq to libbsd
cd /SOURCE_CODE/libmd
./configure --prefix=/usr
make
make install

# prereq to shadow
cd /SOURCE_CODE/libbsd
./configure --prefix=/usr
make
make install

cd /SOURCE_CODE/shadow
./autogen.sh
make distclean
./configure --prefix=/usr --disable-logind
make
make install

echo "+cpu +memory +pids" > /sys/fs/cgroup/cgroup.subtree_control
mkdir /sys/fs/cgroup/user
mkdir /sys/fs/cgroup/user/1000
chown -R user:user /sys/fs/cgroup/user/1000

cd /SOURCE_CODE/Linux-PAM
rm -rf build
mkdir build
cd build
meson setup .. --prefix=/usr -D docs=disabled
ninja
ninja install
install -v -m755 -d /etc/pam.d
# NEXT line is needed, /bin/login (from shadow package) won't otherwise find these libpam libraries
# as musl systems look in /usr/lib and NOT in /usr/lib64 during first login, as profile and hence
# LD_LIBRARY_PATH is not yet set:
cp -f /usr/lib64/libpam.so.0 /usr/lib/
cp -f /usr/lib64/libpam_misc.so.0 /usr/lib/
cp -fdpr /usr/etc/l* /etc/

cat > /etc/pam.d/other << "EOF100"
auth     required       pam_deny.so
account  required       pam_deny.so
password required       pam_deny.so
session  required       pam_deny.so
EOF100
ninja test
rm -fv /etc/pam.d/other
ninja install &&
chmod -v 4755 /usr/sbin/unix_chkpwd
rm -rf /usr/lib/systemd

cat > /etc/pam.d/other << "EOF101"
# Begin /etc/pam.d/other

auth            required        pam_unix.so     nullok
account         required        pam_unix.so
session         required        pam_unix.so
password        required        pam_unix.so     nullok

# End /etc/pam.d/other
EOF101

install -vdm755 /etc/pam.d

cat > /etc/pam.d/system-account << "EOF102"
# Begin /etc/pam.d/system-account

account   required    pam_unix.so

# End /etc/pam.d/system-account
EOF102

cat > /etc/pam.d/system-auth << "EOF103"
# Begin /etc/pam.d/system-auth

auth      required    pam_unix.so

# End /etc/pam.d/system-auth
EOF103

cat > /etc/pam.d/system-session << "EOF104"
# Begin /etc/pam.d/system-session

session   required    pam_unix.so

# End /etc/pam.d/system-session
EOF104

cat > /etc/pam.d/system-password << "EOF105"
# Begin /etc/pam.d/system-password

# use yescrypt hash for encryption, use shadow, and try to use any
# previously defined authentication token (chosen password) set by any
# prior module.
password  required    pam_unix.so       yescrypt shadow try_first_pass

# End /etc/pam.d/system-password
EOF105

cat > /etc/pam.d/other << "EOF106"
# Begin /etc/pam.d/other

auth        required        pam_warn.so
auth        required        pam_deny.so
account     required        pam_warn.so
account     required        pam_deny.so
password    required        pam_warn.so
password    required        pam_deny.so
session     required        pam_warn.so
session     required        pam_deny.so

# End /etc/pam.d/other
EOF106

cat > /etc/pam.d/login << "EOF107"
#%PAM-1.0
auth            required        pam_unix.so
account         required        pam_unix.so
password        required        pam_unix.so
session         required        pam_limits.so
EOF107

cat > /etc/pam.d/passwd << "EOF108"
#%PAM-1.0
auth            required        pam_unix.so
account         required        pam_unix.so
password        required        pam_unix.so
EOF108

cat > /etc/pam.d/su << "EOF109"
#%PAM-1.0
auth            required        pam_unix.so
account         required        pam_unix.so
password        required        pam_unix.so
session         required        pam_unix.so
EOF109

cat > /etc/pam.d/login << "EOF110"
#%PAM-1.0
auth            required        pam_unix.so
account         required        pam_unix.so
password        required        pam_unix.so
session         required        pam_limits.so
EOF110

# Make shadow pam-aware:
cd /SOURCE_CODE/shadow
./autogen.sh
make distclean
./configure --prefix=/usr --disable-logind
make
make install

cat > /etc/shells << EOF100
/bin/sh
/bin/ash
EOF100

# add: ENCRYPT_METHOD SHA512 in /etc/login.defs
# to ensure sha512 secure passwords will be used!
sed -i 's/^#* *ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/' /etc/login.defs

# convert passwd and group to shadow files:
pwconv
grpconv

# SET NEW (automatically SHA512 encrypted) passwords:
passwd
passwd user

# Check the user status:
chage -l user

cd /SOURCE_CODE/xlockmore
make clean
./configure --prefix=/usr --enable-pam --without-gtk --without-gtk2 --without-mesa --without-opengl
make -j$LNX_CPU_CORES
make install

# Give xlock rights to use PAM (and essentially work)
cp /etc/pam.d/login /etc/pam.d/xlock

# LET'S add the global PATHS for all LD_LIBRARY_PATH paths; this will help xlock and similar stuff to work!
ARCH=$(uname -m)
cat > /etc/ld-musl-${ARCH}.path << EOF102
/build-tools/${ARCH}-linux-musl/lib64
/build-tools/lib
/build-tools/lib64
/build-tools/${ARCH}-unknown-linux-gnu/x86_64-linux-musl/lib
/build-tools/${ARCH}-linux-musl/lib
/build-tools/${ARCH}-linux-musl/lib64
/lib
/lib64
/usr/lib
/usr/lib64
/usr/lib/xorg/modules/input
/usr/lib64/xorg/modules
/usr/lib64/xorg/modules/drivers
/usr/lib64/xorg/modules/input
/usr/lib64/xorg/modules/extensions
/usr/lib/alsa-lib
/usr/lib/python3.10
/usr/lib/alsa-topology
/usr/lib/dbus-1.0
/usr/lib/bash
/usr/lib/cmake
/usr/lib/engines-3
/usr/lib/jack
/usr/lib64/security
EOF102

EOF



cat > $LNX/SOURCE_CODE/BUILD_SYSTEM5_5<< "EOF"
#!/bin/ash

export LNX_CPU_CORES=`nproc`

cd /SOURCE_CODE/st
cp config.def.h config.h
# Scrollback patch:
patch -p0 < st.patch
# Better font size:
sed -i.bak 's/pixelsize=12/pixelsize=20/' config.h
sed -i 's|^PREFIX = /usr/local|PREFIX = /usr|' config.mk
make
make install

cd /SOURCE_CODE/libgpg-error
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install


cd /SOURCE_CODE/libassuan
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install


cd /SOURCE_CODE/gpgme
#rm /usr/bin/gpg-error-config
# Next line is important, otherwise gpgme won't build as libgpg-error does not provide it anymore...
#ln -s /usr/bin/gpgrt-config /usr/bin/gpg-error-config
make distclean
#sed -e 's/3\.9/3.10/'                    \
#    -e 's/:3/:4/'                        \
#    -i configure
#export GCC_VERSION=$(ls /build-tools/`uname -m`-lnx-linux-gnu/include/c++/)
#export CPLUS_INCLUDE_PATH=/build-tools/`uname -m`-lnx-linux-gnu/include/c++/$GCC_VERSION:/usr/include
#export CPLUS_INCLUDE_PATH=/usr/include/c++/14.1.0:/usr/include
CFLAGS="-Dino64_t=ino_t -Doff64_t=off_t" ./configure --prefix=/usr --disable-gpg-test --disable-static
#./configure --prefix=/usr  --with-libgpg-error-prefix=/usr/lib/libgpg-error.so.0.33.1
make -j$LNX_CPU_CORES
make install
#rm /usr/lib/libgpg*.la
#ldconfig
#export CPLUS_INCLUDE_PATH=/usr/include



cd /SOURCE_CODE/mksh-master
chmod 755 Build.sh
./Build.sh
cp mksh /bin/
ln -fs /bin/mksh /bin/bash
rm -f /usr/bin/bash

cd /SOURCE_CODE/
# LNX checks for target architecture and UNPACKS the correct go arch
if [ $(uname -m) == "aarch64" ];
then
	tar zxvf go1.24.5.linux-arm64.tar.gz -C /tmp
fi
if [ $(uname -m) == "x86_64" ];
then
	tar zxvf go1.24.5.linux-amd64.tar.gz -C /tmp
fi


# DON't build GO, use an official binary dist instead. The tar command above this line...
#cd /SOURCE_CODE/go
export PATH=/tmp/go/bin:$PATH
#cd src
#GOROOT_BOOTSTRAP=/tmp/go ./all.bash

cd /SOURCE_CODE/conmon
make clean
# NOTE: 2.1.9 does NOT WORK, results in an oci error, config.json cannot be read or written...
git checkout v2.1.13
rm -rf build
mkdir build
cd build
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install

cd /SOURCE_CODE/runc
make clean
git checkout v1.0.0
export PATH=/tmp/go/bin:$PATH
make SHELL=/bin/sh BUILDTAGS="seccomp"
go build -tags "seccomp" -o runc .
#main.go
cp runc /usr/bin/runc
mkdir -p /etc/containers
wget --no-check-certificate -O /etc/containers/registries.conf https://raw.githubusercontent.com/containers/image/main/registries.conf
wget --no-check-certificate -O /etc/containers/policy.json https://raw.githubusercontent.com/containers/image/main/default-policy.json

cd /SOURCE_CODE/grep
make distclean
./configure --prefix=/usr
make -j$LNX_CPU_CORES
make install

cat > /etc/containers/containers.conf << "EOF3"
#[network]
#network_backend = "cni"
[engine]
cgroup_manager = "cgroupfs"
events_logger = "file"
#cgroup_parent = "user.slice"
#cgroupfs_rootless_use_dest_mount=true
#systemd=false
runtime = "crun"
oom_score_adj = 0
EOF3

# BUILD network plugin: CNI (for Podman)
cd /SOURCE_CODE/plugins
git checkout v1.7.1
./build_linux.sh
cd bin
cp * /usr/bin/

cd  /SOURCE_CODE/podman
# Check out a version/tag that you can see with: "git tag"
git checkout tags/v5.5.2
make clean
# Busybox's ln does not have -sfr support (the 'r' flag)
sed -i.bak 's/ln -sfr/ln -sf/g' Makefile
#go build -tags "seccomp" -o podman ./cmd/podman
make BUILDTAGS="exclude_graphdriver_btrfs seccomp cni" LDFLAGS="-extldflags='-static -B/usr/lib -L/usr/lib'" MAN=/bin/true PREFIX=/usr
make install.bin PREFIX=/usr


# EXTRA RUNC CONFIG!!!
cat > /etc/containers/storage.conf << "EOF2"
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options.overlay]
#graphroot = "~/.local/share/containers/storage"
#runroot = "~/.local/share/containers/storage/run"
mount_program = "/usr/bin/fuse-overlayfs"
EOF2

cat > /etc/containers/registries.conf << "EOF5"
unqualified-search-registries = ["docker.io","quay.io"]
EOF5

cd /SOURCE_CODE/yajl
# Point to the compiler
#CC=/$(uname -m)-linux-musl-native/bin/$(uname -m)-linux-musl-gcc

cd /SOURCE_CODE/yajl
# yajl's build system is broken, I'll build it myself instead!
# Compile each .c file in src/ to an .o file
$CC -fPIC -c src/yajl.c
$CC -fPIC -c src/yajl_lex.c
$CC -fPIC -c src/yajl_parser.c
$CC -fPIC -c src/yajl_buf.c
$CC -fPIC -c src/yajl_encode.c
$CC -fPIC -c src/yajl_gen.c
$CC -fPIC -c src/yajl_alloc.c
$CC -fPIC -c src/yajl_tree.c
$CC -fPIC -c src/yajl_version.c

# -shared tells the compiler to create a shared library
# -Wl,-soname,... is important information for the dynamic linker
$CC -shared -o libyajl.so.2.1.1 *.o -Wl,-soname,libyajl.so.2

# Install the library file
install -m 755 libyajl.so.2.1.1 /usr/lib/

# Create the necessary symbolic links
ln -sf libyajl.so.2.1.1 /usr/lib/libyajl.so.2
ln -sf libyajl.so.2 /usr/lib/libyajl.so

# Install the public header files
install -d /usr/include/yajl
install -m 644 src/api/*.h /usr/include/yajl/

cat > /usr/lib/pkgconfig/yajl.pc << "EOF4"
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: yajl
Description: Yet Another JSON Library
Version: 2.1.1
Libs: -L${libdir} -lyajl
Cflags: -I${includedir}
EOF4

# DOES IT WORK?
pkg-config --libs yajl




cd /SOURCE_CODE/argp-standalone
#./configure --prefix=/usr
#make
#make install
CC=/$(uname -m)-linux-musl-native/bin/$(uname -m)-linux-musl-gcc cmake -DCMAKE_BUILD_TYPE=Release .
CC=/$(uname -m)-linux-musl-native/bin/$(uname -m)-linux-musl-gcc make
cp include/argp-standalone/argp.h /usr/include/
cp src/libargp-standalone.a /usr/lib/libargp.a
#cp argp.h /usr/include
#cp libargp.a /usr/lib




cd /SOURCE_CODE/crun
./autogen.sh
./configure --prefix=/usr --disable-systemd
make
make install

EOF

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
