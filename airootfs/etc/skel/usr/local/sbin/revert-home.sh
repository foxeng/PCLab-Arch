#!/bin/sh

# Revert /home before login (assuming we are successfully booted already, /home
# should be mounted).

if umount -R /home
then
	/usr/local/sbin/rec-sub-del.sh home /root/btrfs-root
	btrfs subvolume snapshot /root/btrfs-root/home-snap /root/btrfs-root/home
	mount /home
else
	rm -rf /home/labuser/
	cp -r /root/btrfs-root/home-snap/labuser/ /home/	# could use --reflink
	chown -R labuser:labuser /home/labuser/
fi
