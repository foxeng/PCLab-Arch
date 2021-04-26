#!/bin/sh

# Replace root filesystem snapshot with one taken of the current filesystem
# (current as of when it powers off). In essence, make the system state when it
# is next powered off permanent.


TOP=/root/btrfs-root

# current -> root.next
# Determine currently booted subvolume
curr=$(findmnt --noheadings --raw --output FSROOT --mountpoint /) || exit 1
if [[ "${curr}" != "/root.next" ]]; then
    if [[ -d "${TOP}/root.next" ]]; then
        # Delete the root.next probably created by make-current.sh
        rec-sub-del.sh root.next "${TOP}" || exit 1
    fi
    mv -f --no-target-directory "${TOP}/${curr}" "${TOP}/root.next" || exit 1
fi
