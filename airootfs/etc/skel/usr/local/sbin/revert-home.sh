#!/bin/sh

# Revert /home before login (assuming we are successfully booted already, /home
# should be mounted).

umount -R /home
/usr/local/sbin/rec-sub-del.sh home /root/btrfs-root
btrfs subvolume snapshot /root/btrfs-root/home-snap /root/btrfs-root/home
mount /home
