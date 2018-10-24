#!/bin/bash

# This should probably be run as root
# See https://wiki.archlinux.org/index.php/Archiso

if [ $# -lt 1 ]
then
	echo "Usage: ${0} <target-dir>"
	exit
fi

target=${1}
mkdir -p ${target}
cp -r /usr/share/archiso/configs/releng/* ${target}
cp -r airootfs/etc/skel/ ${target}/airootfs/etc
cp airootfs/root/.zlogin ${target}/airootfs/root
echo "Run build.sh in ${target} to build the ISO"
