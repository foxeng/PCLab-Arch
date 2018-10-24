#!/bin/sh

# Replace root filesystem snapshot with one taken of the current filesystem
# (when it powers off). In essence, make the system state when it is next
# powered off permanent.

mv /root/btrfs-root/rootfs /root/btrfs-root/rootfs-tmp
mv /root/btrfs-root/rootfs-snap /root/btrfs-root/rootfs
mv /root/btrfs-root/rootfs-tmp /root/btrfs-root/rootfs-snap
