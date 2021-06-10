# A GNU/Linux installation at an ECE school PC lab

An [Arch Linux](https://archlinux.org/) installation at the PC lab of the NTUA
ECE [school](https://www.ece.ntua.gr/), including automatic filesystem
reversion.

## Why Arch Linux, Xfce

We choose Arch for its rolling release model, avoiding major distribution
upgrades and any incompatibilities therein, or even a reinstallation. Also, for
its excellent documentation (one of the best and most complete distribution
[wikis](https://wiki.archlinux.org/) online), its large, committed community of
users and maintainers (a strong history is an assuring sign for the future), as
well as the fact that the software in its repositories is on the bleeding edge,
following upstream versions very closely.

We choose [Xfce](https://xfce.org/) due to its satisfying compromise between low
hardware requirements and a complete, user friendly environment. Another reason
for is the ease with which it can be configured to make a Windows user feel at
home with its user interface.

[LightDM](https://github.com/canonical/lightdm) is the display manager of
choice, owing to its straightforward approach, full functionality and
configurability, as well as the fact that it is independent of any particular
desktop environment.

## Installation

Supporting initial installation (provisioning), there are:

- A mechanism for painlessly generating Arch ISOs (in [`image/`](image/))
- A mechanism for PXE booting Arch ISOs (in [`pxe/`](pxe/))
- An automated, unattended installer, built to work in tandem with the image
generation utility (in [`archlive/`](archlive/))

## Configuration management

We use [Ansible](https://www.ansible.com/) for managing the systems once
deployed, in a centralized, uniform and convenient manner (see
[`ansible/`](ansible/)). Owing to its agentless architecture (SSH access and a
python interpreter are the only requirements on the managed hosts), its
widespread use and its straightforward approach for simple tasks, it is
preferred over the alternatives (e.g. Puppet and Chef).

### User environment

The desktop environment is configured with Windows users in mind. System actions
the user should (not) be able to perform and how are:

- log out: by default
- **NOT** poweroff, suspend, hibernate: Via
  [polkit](https://www.freedesktop.org/software/polkit/docs/latest/polkit.8.html)
  rule. Also, remove power menu from lightdm-gtk-greeter configuration
  (`/etc/lightdm/lightdm-gtk-greeter.conf`).
- reboot: by default
- blank screen: by default
- **NOT** lock: No screen locker installed, so xflock4 can't
  [use](https://wiki.archlinux.org/index.php/Xfce#Lock_the_screen) any
- **NOT** switch users: gdmflexiserver is
  [required](https://wiki.archlinux.org/index.php/Xfce#User_switching_action_button_is_greyed_out)
  to do it, but not installed
- **NOT** use LightDM's dm-tool for session locking, user switching, etc:
  actions disabled in LightDM's configuration
  (`/etc/lightdm/lightdm.conf.d/50-local.conf`)

## Reversion of system state

The goal is for every user to find the system in a specific desired state when
they log in, independently of what the previous user might have performed. To
achieve this we employ filesystem snapshots, as provided by
[BTRFS](https://btrfs.wiki.kernel.org/index.php/Main_Page).

In particular, during system bootup the whole filesystem is reverted using a
snapshot of the desired state. In addition to that, at every user login, `/home`
is reverted as well (can't do it for root, would require to unmount it). These
actions are performed as late as possible (not e.g. at shut down and logout,
respectively), in order to give the system administrator a chance to intervene
before the modified state is lost, e.g. for troubleshooting.

### Implementation

The btrfs file system is hosted on a single disk partition.
[Subvolumes](https://btrfs.wiki.kernel.org/index.php/SysadminGuide#Subvolumes)
are organized in a
[flat](https://btrfs.wiki.kernel.org/index.php/SysadminGuide#Flat) layout:

```
toplevel             (volume root directory, mounted at /root/btrfs-root)
    +-- root.next    (subvolume root directory, to be mounted at / at next boot)
    +-- root.curr    (subvolume root directory, mounted at /)
    +-- root.bak     (subvolume root directory, snapshot of the desired state for /)
    +-- home         (subvolume root directory, mounted at /home)
    \-- home-snap    (subvolume root directory, snapshot of the desired state for /home)
```

A typical lifecycle includes (see
[boot process](https://wiki.archlinux.org/title/Arch_boot_process) for
reference):

1. Initramfs: the
   [`revert`](archlive/airootfs/root/config/etc/initcpio/hooks/revert)
   [mkinitcpio](https://wiki.archlinux.org/title/Mkinitcpio) hook creates a
   copy of the (still untouched) `root.next`. Conceptually:
   ```sh
   cp root.next root.bak
   ```
1. Init: the
   [`revert-next`](archlive/airootfs/root/config/etc/systemd/system/revert-next.service)
   systemd service moves the currently booted subvolume (typically `root.next`,
   dirty by now) to `root.curr` and creates a copy of `root.bak` (clean) at
   `root.next`, readying for the next boot. Conceptually:
   ```sh
   current=$(get_current_subvolume)
   mv current root.curr
   cp root.bak root.next
   ```
1. Login (posbbily recurring): the
   [`revert-home.sh`](archlive/airootfs/root/config/usr/local/sbin/revert-home.sh)
   LightDM session-setup script creates a copy of `home-snap` at `home`.
   Conceptually:
   ```sh
   cp home-snap home
   ```
1. [**OPTIONAL**] Regular operation: the
   [`replace-snap.sh`](archlive/airootfs/root/config/usr/local/sbin/replace-snap.sh)
   script moves the currently booted subvolume (typically `root.curr`,
   changed) to `root.next`, to persist the changes made to it (new desired
   system state). Conceptually:
   ```sh
   current=$(get_current_subvolume)
   mv current root.next
   ```

**NOTE**: When on UEFI, the
[EFI system partition](https://wiki.archlinux.org/title/EFI_system_partition)
(mounted at `/efi`) is _not_ covered by the reversion mechanism.

### How-to

- Make a change under **`/home`** permanent (e.g. change user settings for the
  desktop environment): either make the desired change in `home-snap` directly
  (it will take effect the next time the user logs in) or change `home` and then
  recreate `home-snap` from it (user should **not be logged in** when the new
  snapshot is taken).
- Make a change to the **system** permanent (e.g. add/remove/upgrade packages):
  run `replace-snap.sh`. This effectively sets as the desired state for the root
  filesystem the state of the currently booted subvolume **when the system
  is next powered off**. Use with **caution**.

  **NOTE**: Always re-generate the GRUB configuration (i.e. run `grub-mkconfig`)
  _after_ running `replace-snap.sh`. This is necessary to always boot from
  `root.next`. A `grub-mkconfig`
  [wrapper](archlive/airootfs/root/config/usr/local/sbin/grub-mkconfig) is
  provided to enforce this.

### References

- https://wiki.archlinux.org/index.php/Btrfs
- man btrfs
- man btrfs-subvolume
- https://btrfs.wiki.kernel.org/index.php/SysadminGuide
- https://wiki.gentoo.org/wiki/Btrfs
