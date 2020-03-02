#!/bin/sh

# Replace root filesystem snapshot with one taken of the current filesystem
# (when it powers off). In essence, make the system state when it is next
# powered off permanent.

mv /root/btrfs-root/rootfs /root/btrfs-root/rootfs-tmp
mv /root/btrfs-root/rootfs-snap /root/btrfs-root/rootfs
mv /root/btrfs-root/rootfs-tmp /root/btrfs-root/rootfs-snap

# Swapping the subvolumes above means that on the next boot, the bootloader will
# load the kernel image in /root/btrfs-root/rootfs/boot, which is the OLD one
# (the one from the previous snapshot). To correct that, we copy /boot from the
# current system there.
rm -rf /root/btrfs-root/rootfs/boot
cp -r /root/btrfs-root/rootfs-snap/boot /root/btrfs-root/rootfs/

# TODO OPT: Keep a temporary backup of /boot on the snapshot?
