#!/bin/sh

# Recursively delete all subvolumes under the directory given in the first
# argument (as a path relative to the top level subvolume). If this directory
# is a subvolume, delete it as well. Need to provide the mount point for the
# top level subvolume as the second argument as an absolute path.

if [ $# -lt 2 ]
then
	echo "Usage: ${0} <target-dir> <top-level-mount-point>"
	exit
fi
target=${1}
# Mount point for top level subvolume (remove trailing / if there is any)
top=${2%/}

# List of subvolume paths (relative to the top level subvolume) under the target
# subvolume (including the target), sorted by their path (descending, ie bottom-up).
# 'btrfs subvolume list' lists all subvolumes in the filesystem.
# NOTE: '^${target}' instead of '^${target}$|^${target}/' would include eg
# 'home-snap' when target is 'home'
subvols=$(btrfs subvolume list --sort=-path ${top} | awk '{print $NF}' | grep -E "^${target}$|^${target}/")

# Delete all subvolumes in subvols
for sub in ${subvols}
do
	btrfs subvolume delete ${top}/${sub}
done
