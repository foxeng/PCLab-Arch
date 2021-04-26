#!/bin/bash

# Ensure next boot from the snapshot


TOP=/root/btrfs-root

# current -> root.curr
# Determine currently booted subvolume
curr=$(findmnt --noheadings --raw --output FSROOT --mountpoint /) || exit 1
if [[ "${curr}" != "/root.curr" ]]; then
    if [[ -d "${TOP}/root.curr" ]]; then
        # Delete leftover root.curr from previous boot
        rec-sub-del.sh root.curr "${TOP}" || exit 1
    fi
    mv -f --no-target-directory "${TOP}/${curr}" "${TOP}/root.curr" || exit 1
fi

# root.bak -> root.next
if [[ -d "${TOP}/root.next" ]]; then
    rec-sub-del.sh "root.next" "${TOP}" || exit 1
fi
btrfs subvolume snapshot "${TOP}/root.bak" "${TOP}/root.next"
