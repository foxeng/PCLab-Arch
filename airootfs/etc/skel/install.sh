#!/bin/bash

# Script to perform unattended system installation (see https://wiki.archlinux.org/index.php/Installation_guide)
# TODO: separate (some, independent) sections in different scripts to make it
# more modular (eg, DE configuration)

set -v

# Update system clock (assuming RTC in localtime)
timedatectl set-local-rtc true --adjust-system-clock

# Partition the disk
# The kernel name descriptor of the target disk for the installation (such as sda)
# NOTE: we don't want a full path ('/dev/sda') because this variable is substituted
# in a sed command (and thus, a full path would require escaping).
disk=$(lsblk --nodeps --noheadings --output NAME --sort SIZE | tail --lines 1 | tr --delete '\n')	# the largest disk in the system
#disk=$(lsblk --nodeps --noheadings --output NAME --sort SIZE | tail --lines 2 | head --lines 1 | tr --delete '\n')	# the second largest disk in the system
echo disk=$disk
# The basis of partition.in is created with (s)fdisk's 'dump' option (from a
# drive with the desired partition table). The output should then be edited as
# necessary (eg, to remove 'label-id:' and 'device:' header lines). Consult the
# respective documentation for (s)fdisk for more.
# NOTE: if you leave start, size or device unspecified in partition.in, make sure
# the defaults fit you. Add the '--wipe always' option to make sure we start with
# a wiped disk.
sfdisk --wipe always /dev/$disk < partition.in
fspart=/dev/${disk}1
echo fspart=$fspart
swpart=/dev/${disk}2
echo swpart=$swpart

# Format the partitions
fslabel=ROOT
echo fslabel=$fslabel
swlabel=SWAP
echo swlabel=$swlabel
mkfs.btrfs -f -L $fslabel $fspart
mkswap -f -L $swlabel $swpart
swapon $swpart

# Mount the filesystems
mount -o subvol=/ $fspart /mnt
btrfs subvolume create /mnt/rootfs
btrfs subvolume create /mnt/home
umount -R /mnt
mount -o subvol=/rootfs $fspart /mnt

# Select the mirrors
cp etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist

# Install the packages
# NOTE: this runs non-interactively and auto-confirms every prompt, so make sure
# that this is ok (package selection and default provider for packages)
pacstrap /mnt $(tr '\n' ' ' < packages/packages.txt)

# Mount the rest of the file system
mkdir /mnt/root/btrfs-root
mount -o subvol=/ $fspart /mnt/root/btrfs-root
mount -o subvol=/home $fspart /mnt/home

# Fstab
genfstab -L /mnt >> /mnt/etc/fstab
# Edit fstab to make sure the options are right. By default, genfstab specifies
# the subvolume to mount using both 'subvol=' and 'subvolid=', but the subvolid
# is different every time we revert a snapshot, so we shouldn't use it ('subvol='
# is enough).
# TODO: Maybe we should use an fstab skeleton and not rely on genfstab?
sed -i -e 's/\(,subvolid=[[:digit:]]*\)\|\(subvolid=[[:digit:]]*,\)\|\([[:space:]]subvolid=[[:digit:]]*[[:space:]]\)//g' /mnt/etc/fstab

# Copy necessary system files to the new system
cp etc/locale.conf /mnt/etc/
cp etc/hosts /mnt/etc/
cp etc/initcpio/install/revert /mnt/etc/initcpio/install/revert
cp etc/initcpio/hooks/revert /mnt/etc/initcpio/hooks/revert
cp usr/local/sbin/* /mnt/usr/local/sbin/
cp etc/polkit-1/rules.d/10-admin-override.rules /mnt/etc/polkit-1/rules.d/
cp etc/lightdm/lightdm-gtk-greeter.conf /mnt/etc/lightdm/

# Chroot
# Determine parameters for the fresh system
source root_passwd.cfg
iface=$(basename $(ls -d /sys/class/net/enp*))
echo iface=$iface
hostname=pclab-arch
echo hostname=$hostname
# Copy user files to the new system (temporary)
mkdir /mnt/config
cp config/id_rsa.pub /mnt/config/
tar -xf config/chromium.tar.gz -C /mnt/config/
tar -xf config/geany.tar.gz -C /mnt/config/
tar -xf config/mozilla.tar.gz -C /mnt/config/
tar -xf config/xfce4.tar.gz -C /mnt/config/
cp config/vimrc /mnt/config/
mkdir /mnt/packages
cp packages/package_deps.txt /mnt/packages/
cp packages/*.pkg.tar.xz /mnt/packages/
mkdir /mnt/packages/tomcat
tar -xf packages/apache-tomcat*.tar.gz -C /mnt/packages/tomcat/ --strip-components 1
# Embed parameters in install_chroot.sh
cp install_chroot.sh /mnt/
sed -i -e "s/<hostname>/$hostname/g
	   s/<iface>/$iface/g
	   s/<disk>/$disk/g
	   s/<root_passwd>/$root_passwd/g" /mnt/install_chroot.sh
arch-chroot /mnt /install_chroot.sh
# Cleanup
rm /mnt/install_chroot.sh
rm -rf /mnt/packages/
rm -rf /mnt/config/
# The RTC is changed in the chroot, so we need to correct it here
hwclock --systohc

# Create snapshots
umount -R /mnt
mount -o subvol=/ $fspart /mnt
btrfs subvolume snapshot /mnt/home /mnt/home-snap
btrfs subvolume snapshot /mnt/rootfs /mnt/rootfs-snap

poweroff
