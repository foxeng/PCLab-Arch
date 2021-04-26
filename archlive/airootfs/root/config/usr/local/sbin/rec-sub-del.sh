#!/bin/sh

USAGE="Usage: ${0} <target-dir> <top-level-mount-point>

Recursively delete all subvolumes under a directory.

where:
<target-dir>
	path relative to <top-level-mount-point> to delete subvolumes under. If
	<target-dir> is a subvolume, it too is deleted.
<top-level-mount-point>
	mount point of the btrfs top-level subvolume"


if [ ${#} -lt 2 ]; then
	echo "${USAGE}" >&2
	exit 1
fi
target="${1}"
top="${2}"

# List of subvolume paths (relative to top) under the target subvolume
# (including the target), sorted by their path (descending, i.e. bottom-up).
# 'btrfs subvolume list' lists all subvolumes in the filesystem.
# NOTE: '^${target}' instead of '^${target}$|^${target}/' would include e.g.
# 'home-snap' when target is 'home'.
subvols=$(btrfs subvolume list --sort=-path "${top}" \
	| awk "\$NF ~ /^${target}$|^${target}\// {print \$NF}") || exit 1

for sub in ${subvols}; do
	btrfs subvolume delete "${top}/${sub}"
done
