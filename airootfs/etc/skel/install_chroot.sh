#!/bin/bash

# Script to perform initial system configuration inside chroot

set -v

# Timezone
# We can't use timedatectl under a chroot because it requires an active dbus
# (see note in https://wiki.archlinux.org/index.php/Time#Time_standard)
ln -sf /usr/share/zoneinfo/Europe/Athens /etc/localtime
# This is necessary to create adjtime, but it will also alter the RTC because
# of the timezone. We correct the RTC when we exit the chroot.
hwclock --systohc --local

# Locale
# Uncomment en_US.UTF-8 UTF-8 and el_GR.UTF-8 UTF-8 in /etc/locale.gen
sed -i -e 's/#en_US\.UTF-8 UTF-8/en_US\.UTF-8 UTF-8/g
	   s/#el_GR\.UTF-8 UTF-8/el_GR\.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen
# locale.conf is placed in the new system in install.sh

# Network configuration
hostname=<hostname>
echo $hostname > /etc/hostname
sed -i -e "s/<myhostname>/$hostname/g" /etc/hosts
systemctl enable dhcpcd@<iface>.service

# Initramfs
# Add 'revert' as the last hook in mkinitcpio.conf
awk 'BEGIN { FS = ")" }
/^HOOKS=/ { print $1 " revert)" }
!/^HOOKS=/ { print }' /etc/mkinitcpio.conf > mkinitcpio.tmp
mv mkinitcpio.tmp /etc/mkinitcpio.conf
mkinitcpio -p linux

# Root password
echo "root:<root_passwd>" | chpasswd

# Create user
useradd -m labuser
# Create direcotries in labuser's home
mkdir /home/labuser/Desktop
chown labuser:labuser /home/labuser/Desktop/
mkdir /home/labuser/Documents
chown labuser:labuser /home/labuser/Documents/
mkdir /home/labuser/Downloads
chown labuser:labuser /home/labuser/Downloads/

# Setup user authentication
echo 'labuser:labuser' | chpasswd

# Install package dependencies
pacman -S --noconfirm --asdeps $(tr '\n' ' ' < /packages/package_deps.txt)
# Install additional packages
# Install VirtualBox (we do this here because we need virtualbox-host-modules-arch
# as a dependency, installed right above since pulling the default provider for
# virtualbox host modules would give us virtualbox-host-dkms, see
# https://wiki.archlinux.org/index.php/VirtualBox#Install_the_core_packages)
pacman -S --noconfirm virtualbox
# Install hyphen-el
pacman -U --noconfirm /packages/hyphen-el-*.pkg.tar.xz
# Install mythes-el
pacman -U --noconfirm /packages/mythes-el-*.pkg.tar.xz
# Install Tomcat (a local installation in the user's home is the only way to
# avoid the need to grant the user unnecessary privileges to use a system-wide
# installation)
mkdir /home/labuser/opt
cp -r /packages/tomcat/ /home/labuser/opt/
chown -R labuser:labuser /home/labuser/opt/
# Install Python packages with pip (do a user install)
mkdir -p /home/labuser/.local
PYTHONUSERBASE=/home/labuser/.local pip install --user -r /packages/requirements.txt
chown -R labuser:labuser /home/labuser/.local/

# Configure SSH (root access, only with a key)
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat /config/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
echo '
# Disable password logins (only use SSH keys)
PasswordAuthentication no' >> /etc/ssh/sshd_config
systemctl enable sshd.socket
# Configure LightDM (run revert-home.sh right before the user is logged in)
# NOTE: if the user has logged out and upon trying to login again, although the
# password entered is right, the screen flickers and the LightDM greeter
# reappears with no feedback, it's probably because revert-home.sh has failed
# (which in turn probably happens because it can't unmount /home, in which case
# just waiting for a couple of minutes before retrying the login might work).
sed -i -e 's/#session-setup-script=/session-setup-script=\/usr\/local\/sbin\/revert-home.sh/g' /etc/lightdm/lightdm.conf
systemctl enable lightdm.service
# Don't let labuser use dm-tool (because it enables session locking, user
# switching, etc): remove execute permission for labuser using an ACL. Also
# set up a post-transaction pacman hook to do this every time the binary
# is upgraded.
setfacl -m "u:labuser:r--" /usr/bin/dm-tool
mkdir -p /etc/pacman.d/hooks
cp /config/disable-dm-tool.hook /etc/pacman.d/hooks/
# Configure Xfce
mkdir /home/labuser/.config
cp -r /config/xfce4/ /home/labuser/.config/
chown -R labuser:labuser /home/labuser/.config/
# Configure Wireshark (see https://wiki.archlinux.org/index.php/Wireshark#Capturing_as_normal_user)
gpasswd -a labuser wireshark
# Configure VirtualBox (see https://wiki.archlinux.org/index.php/VirtualBox)
gpasswd -a labuser vboxusers
# Configure Chromium
cp -r /config/chromium/ /home/labuser/.config/
chown -R labuser:labuser /home/labuser/.config/chromium/
# Configure Firefox
cp -r /config/mozilla/ /home/labuser/.mozilla/
chown -R labuser:labuser /home/labuser/.mozilla/
# Configure Geany
cp -r /config/geany/ /home/labuser/.config/
chown -R labuser:labuser /home/labuser/.config/geany/
# Configure (g)Vim
cp /config/vimrc /home/labuser/.vimrc
chown labuser:labuser /home/labuser/.vimrc
# Configure SMB client (see https://wiki.archlinux.org/index.php/Samba#Client)
touch /etc/samba/smb.conf
# Configure Jupyter Notebook (see https://wiki.archlinux.org/index.php/Jupyter#Installation)
jupyter nbextension enable --py --sys-prefix widgetsnbextension
# Configure tcpdump (one needs to run it as a superuser to enable promiscuous
# mode for the desired interface, so we configure sudo to let labuser only run
# tcpdump with it)
echo '## Allow labuser to use tcpdump
labuser ALL=(ALL) NOPASSWD: /usr/bin/tcpdump' >> /etc/sudoers
# Configure Arduino IDE (see https://wiki.archlinux.org/index.php/Arduino#Installation)
gpasswd -a labuser uucp
gpasswd -a labuser lock

# Boot loader
# Make the third entry (this should be Windows) the default in GRUB's menu and
# give it a 15 minute timeout.
sed -i -e 's/GRUB_DEFAULT=0/GRUB_DEFAULT=2/g
	   s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=900/g' /etc/default/grub
grub-install --target=i386-pc /dev/<disk>
grub-mkconfig -o /boot/grub/grub.cfg
