#!/bin/sh

# Revert /home before login (assuming we are successfully booted already, /home
# should be mounted).


TOP=/root/btrfs-root

if umount -R /home; then
	rec-sub-del.sh home "${TOP}" &&
		btrfs subvolume snapshot "${TOP}/home-snap" "${TOP}/home" &&
		mount /home || exit 1
else
	# /home could not be unmounted (there's probably a process keeping it busy).
	# Fallback to just purging and copying it from the snapshot.
	# TODO OPT: Use cp --reflink?
	rm -rf /home/* &&
		cp -r --preserve=all "${TOP}/home-snap/"* /home/ || exit 1
fi
