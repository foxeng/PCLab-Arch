#!/bin/bash

# Script to perform unattended system installation (see
# https://wiki.archlinux.org/index.php/Installation_guide)

set -v
set -o pipefail

DISK_ORDER_FILE=/root/disk_order
PASSWORD_FILE=/root/root_password
HOSTNAMES_FILE=/root/hostnames
MIRROLIST_OVERRIDE=/etc/pacman.d/mirrorlist.override
PACKAGES_FILE=/root/packages
CONFIG_DIR=/root/config
SSH_KEY_FILE=/root/ssh_key.pub

# Return the device path (e.g. /dev/sda) of the n'th largest block device on the
# system (e.g. "sda"), where n is specified in $DISK_ORDER_FILE.
get_disk() {
	local disk_order
	disk_order=$(cat ${DISK_ORDER_FILE}) || return 1

	local disk
	disk=$(lsblk --nodeps --noheadings --list --sort SIZE --output PATH \
		| tac | sed "${disk_order}q;d") || return 1

	[[ -n "${disk}" ]] || return 1

	echo "${disk}"
}

# Return the desirable swap size, in MiB.
get_swap_size() {
	# System memory (KiB)
	local mem_kib
	mem_kib=$(grep 'MemTotal' /proc/meminfo | awk '{print $2}') || return 1
	(( ${mem_kib} > 0 )) || return 1

	echo $(( ${mem_kib} / 1024 ))
}

# Return the desirable hostname.
get_hostname() {
	if [[ ! -f "${HOSTNAMES_FILE}" ]]; then
		echo 'pclab-arch'
		return 0
	fi

	local iface
	local mac
	iface=$(basename $(ls -d /sys/class/net/enp*)) &&
		mac=$(cat /sys/class/net/${iface}/address) &&
		awk -f - "${HOSTNAMES_FILE}" <<-EOF || return 1
		BEGIN { FS = ";" }

		NF >= 3 && \$2 == "${mac}" { print \$3 }
		EOF
}

# Return the desirable root password.
get_root_passwd() {
	cat "${PASSWORD_FILE}" || return 1
}

# Return the desirable public ssh key.
get_ssh_key() {
	cat "${SSH_KEY_FILE}" || return 1
}


# Examine if booted in EUFI
[[ -d /sys/firmware/efi/efivars ]] && UEFI=true

# Configure the time of the live system
timedatectl set-timezone Europe/Athens &&
	timedatectl set-ntp true &&
	timedatectl set-local-rtc true || exit 1

# Partition the disk
disk=$(get_disk) || exit 1
echo "disk=${disk}"
swsize=$(get_swap_size) || exit 1
echo "swsize=${swsize}MiB"
sfdisk --wipe always --wipe-partitions always "${disk}" <<EOF || exit 1
label: $([[ ${UEFI} ]] && echo 'gpt' || echo 'dos')

$([[ ${UEFI} ]] && echo 'size=512MiB, type=uefi')
size=${swsize}MiB, type=swap
type=linux, bootable
EOF
# Figure out new partition device paths
partitions=$(lsblk --noheadings --list --sort NAME --output PATH "${disk}" \
	| tail --lines +2) || exit 1
if [[ ${UEFI} ]]; then
	esp=$(echo "${partitions}" | head --lines 1)  # 1st partition
	echo "esp=${esp}"
fi
swpart=$(echo "${partitions}" | tail --lines 2 | head --lines 1)   # 2nd to last partition
echo "swpart=${swpart}"
rootpart=$(echo "${partitions}" | tail --lines 1) # last partition
echo "rootpart=${rootpart}"

# Format the partitions
if [[ ${UEFI} ]]; then
	esplabel=EFI
	echo "esplabel=${esplabel}"
	mkfs.fat -F32 -n ${esplabel} "${esp}" || exit 1
fi
rootlabel=ROOT
echo "rootlabel=${rootlabel}"
mkfs.btrfs --force --label ${rootlabel} "${rootpart}" || exit 1
swlabel=SWAP
echo "swlabel=${swlabel}"
mkswap --label ${swlabel} "${swpart}" || exit 1

# Create main btrfs subvolumes
mount -o subvol=/ "${rootpart}" /mnt &&
	btrfs subvolume create /mnt/rootfs &&
	btrfs subvolume create /mnt/home &&
	umount /mnt || exit 1

# Mount the file systems
mount -o subvol=rootfs "${rootpart}" /mnt || exit 1
if [[ ${UEFI} ]]; then
	mkdir /mnt/boot &&
		mount "${esp}" /mnt/boot || exit 1
fi
swapon "${swpart}" || exit 1

# Select the mirrors
if [[ -f "${MIRROLIST_OVERRIDE}" ]]; then
	cp "${MIRROLIST_OVERRIDE}" /etc/pacman.d/mirrorlist || exit 1
else
	# Source the mirrorlist with the 50 most recently updated https mirrors,
	# sorted by download rate.
	reflector \
		--save /etc/pacman.d/mirrorlist \
		--protocol 'https' \
		--latest 50 \
		--sort rate || exit 1
fi

# Install the packages
# NOTE: this runs non-interactively and auto-confirms every prompt, so make sure
# that this is ok (package selection and default provider for packages).
pacstrap /mnt $(tr '\n' ' ' < "${PACKAGES_FILE}") || exit 1

# Mount the other subvolumes
mkdir /mnt/root/btrfs-root &&
	mount -o subvol=/ "${rootpart}" /mnt/root/btrfs-root &&
	mount -o subvol=home "${rootpart}" /mnt/home || exit 1

# Fstab
genfstab -L /mnt >> /mnt/etc/fstab || exit 1
# Make sure we use the "subvol=" and not the "subvolid=" option in the fstab,
# since the subvolid changes every time we revert a snapshot
gawk -i inplace -f - /mnt/etc/fstab <<'EOF' || exit 1
/LABEL=ROOT/    {
	# Map mount points to subvolumes
	subvols["/"] = "rootfs"
	subvols["/home"] = "home"
	subvols["/root/btrfs-root"] = "/"

	split($4, options, ",")
	# Remove existing "subvol=" and "subvolid=" options
	for (i in options) {
		if (options[i] ~ /^subvol=|^subvolid=/)
			delete options[i]
	}
	# Reconstruct options, adding the right "subvol="
	$4 = ""
	for (i in options)
		$4 = $4 options[i] ","
	$4 = $4 "subvol=" subvols[$2]

	print $0
	next
}

{ print }   # Default action
EOF

# Copy configuration files over to new system
CONFIG_DIR="${CONFIG_DIR%/}/" # Ensure trailing '/' for rsync
# Make everything under /usr/local/sbin (the reversion scripts) executable.
# TODO: If/when archiso's profiledef.sh matures, we could depend on it for all
# such ownership/permission issues.
chmod +x "${CONFIG_DIR}/usr/local/sbin/"*
rsync -a -r "${CONFIG_DIR}" /mnt/ || exit 1

# Chroot
# Determine parameters for the fresh system
hostname=$(get_hostname) || exit 1
echo "hostname=${hostname}"
root_passwd=$(get_root_passwd) || exit 1
ssh_key=$(get_ssh_key) || exit 1
# Run install-chroot inside the chroot
install --mode 755 /root/install-chroot.sh /mnt/ &&
	arch-chroot /mnt /install-chroot.sh \
		"${hostname}" \
		"${root_passwd}" \
		"${ssh_key}" &&
	rm -f /mnt/install-chroot.sh || exit 1

# Create snapshots
umount -R /mnt &&
	mount -o subvol=/ "${rootpart}" /mnt &&
	btrfs subvolume snapshot /mnt/home /mnt/home-snap &&
	btrfs subvolume snapshot /mnt/rootfs /mnt/rootfs-snap || exit 1

poweroff
