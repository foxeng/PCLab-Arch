# Base system installer

Installs and configures the minimal base system, i.e. just enough to hand over
to ansible (bootloader, file system, network, SSH, python). Based on the
installation [guide](https://wiki.archlinux.org/index.php/Installation_guide).

- Supports UEFI and BIOS.
- RTC in localtime (for Win XP compatibility).
- Installs on the n'th largest disk (block device), where n is specified in
  `/root/disk_order`.
- Single root partition (btrfs with subvolumes) + swap [+ FAT32 ESP when on
  UEFI].
- If `/etc/pacman.d/mirrorlist.override` exists, it is used as the mirrorlist
  (during installation and for the installed system). Else a mirrorlist is
  generated at installation time using
  [reflector](https://wiki.archlinux.org/index.php/Reflector).
- Installs the packages specified in `/root/packages` (one package name per
  line) to the new system.
- Uses `/root/config/` as an overlay directory for the new system (i.e. copies
  anything under it to the corresponding location in the new system). **NOTE**
  that file ownership and permissions are _lost_ when creating the image with
  [archiso](https://wiki.archlinux.org/index.php/Archiso#Adding_files_to_image).
- Configures DHCP on all ethernet interfaces, using
  [systemd-networkd](https://wiki.archlinux.org/index.php/Systemd-networkd).
- If `/root/hostnames` exists, it is used for looking up the desirable hostname
  by MAC (one entry per line, formatted as IP;MAC;hostname). Else, a default
  hostname is assigned.
- Enables and configures both english the greek UTF locales.
- Generates the
  [initramfs](https://wiki.archlinux.org/index.php/Arch_boot_process#initramfs)
  with [mkinitcpio](https://wiki.archlinux.org/index.php/Mkinitcpio), adding the
  `revert` hook responsible for reverting the file systems state on boot.
- Uses the contents of `/root/root_password` as the root password in the new
  system.
- Sets up root SSH access, key-only, using the public key in
  `/root/ssh_key.pub`.

# Quickstart

The bare minimum one needs to specify for a vanilla installation is:

1. The order of the disk to install to, in `root/disk_order`. e.g.:

   ```sh
   echo '1' > root/disk_order
   ```

1. The root password, in `root/root_password`, e.g.:

   ```sh
   echo '12345' > root/root_password
   ```

1. The public SSH key, in `root/ssh_key.pub`, e.g.:

   ```sh
   ssh-keygen -t rsa -b 4096 -f root/ssh_key
   ```
