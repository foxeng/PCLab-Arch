#!/bin/bash

# Script to perform initial system configuration inside chroot

set -v
set -o pipefail

# Figure out which device we are on
# TODO OPT: Receive as argument
disk=$(lsblk --nodeps --noheadings --list --output PKNAME \
	$(findmnt --noheadings --list --nofsroot --output SOURCE / \
		| head --lines 1)) || exit 1
echo "chroot disk=${disk}"
# Enable TRIM, if supported
trim=$(lsblk --nodeps --noheadings --list --output DISC-GRAN "/dev/${disk}" \
	| head --lines 1 | xargs) || exit 1   # xargs to remove whitespace
if [[ "${trim}" != "0B" ]]; then
	systemctl enable fstrim.timer || exit 1
fi

# Timezone
# We can't use timedatectl under a chroot because it requires an active dbus
# (see note in https://wiki.archlinux.org/index.php/Time#Time_standard)
ln -sf /usr/share/zoneinfo/Europe/Athens /etc/localtime &&
	hwclock --systohc --localtime || exit 1 # necessary to create /etc/adjtime

# Localization
# Uncomment en_US.UTF-8 UTF-8 and el_GR.UTF-8 UTF-8 in /etc/locale.gen
sed -i -e 's/#en_US\.UTF-8 UTF-8/en_US\.UTF-8 UTF-8/g
	   s/#el_GR\.UTF-8 UTF-8/el_GR\.UTF-8 UTF-8/g' /etc/locale.gen &&
	locale-gen &&
	cat > /etc/locale.conf <<-'EOF' || exit 1
	LANG=en_US.UTF-8
	LC_NUMERIC=el_GR.UTF-8
	LC_TIME=el_GR.UTF-8
	LC_MONETARY=el_GR.UTF-8
	LC_PAPER=el_GR.UTF-8
	LC_MEASUREMENT=el_GR.UTF-8
	EOF

# Network configuration
hostname="${1}"
echo ${hostname} > /etc/hostname &&
	cat >> /etc/hosts <<-EOF &&
	127.0.0.1	localhost
	::1		localhost
	127.0.1.1	${hostname}.localdomain	${hostname}
	EOF
	cat > /etc/systemd/network/20-wired.network <<-EOF &&
	[Match]
	Type=ether

	[Network]
	DHCP=yes
	EOF
	systemctl enable systemd-networkd.service systemd-resolved.service || exit 1

# Initramfs
# Add 'revert' as the last hook in mkinitcpio.conf
gawk -i inplace -f - /etc/mkinitcpio.conf <<-'EOF' &&
	BEGIN		{ FS = ")" }

	/^HOOKS=/	{
		print $1 " revert)"
		next
	}

	{ print }	# Default action
	EOF
	mkinitcpio -P || exit 1

# Root password
root_password="${2}"
echo "root:${root_password}" | chpasswd || exit 1

# Configure SSH (root access, only with a key)
ssh_key="${3}"
install --directory --mode 700 /root/.ssh &&
	echo "${ssh_key}" > /root/.ssh/authorized_keys &&
	chmod 600 /root/.ssh/authorized_keys &&
	cat >> /etc/ssh/sshd_config <<-'EOF' &&
	# Disable password logins (only use SSH keys)
	PasswordAuthentication no
	EOF
	systemctl enable sshd.service || exit 1

# Boot loader
if [[ -d /efi ]]; then
	grub-install \
		--target=x86_64-efi \
		--efi-directory=/efi \
		--bootloader-id=GRUB || exit 1
else
	grub-install --target=i386-pc "/dev/${disk}" || exit 1
fi
grub-mkconfig -o /boot/grub/grub.cfg || exit 1

# Enable the root file system reversion service
systemctl enable revert-next.service || exit 1

# Backup the ESP
if [[ -d /efi ]]; then
	mkdir /root/bak && cp -a /efi /root/bak/ || exit 1
fi
