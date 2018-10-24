The addition of a GNU/Linux OS (Arch) with automatic filesystem reversion to a
PC lab with 128 systems running Windows XP at the ECE school of the NTUA (c.
2018).

-General
We chose Arch Linux [1] for its rolling release model (which avoids the need for
major distribution upgrades and any incompatibilities these might entail, or
even a reinstallation). Also, for its excellent documentation (one of the best
and most complete distribution wikis [2] online), its committed and large
community of users and maintainers (which if you also look at the distribution's
history are an assuring sign for its future), as well as the fact that the
software in its repositories is on the bleeding edge, following upstream
versions very closely.
We chose Xfce [3] for the desktop environment due to its satisfying compromise
between low hardware requirements and a complete and user friendly environment.
Another reason for this choice was the ease with which it can be configured to
make a Windows user feel at home with its user interface. Other alternatives
would have been LXDE or LXQt and MATE.
LightDM [4] is the display manager of choice, owing to its straightforward
approach, full functionality and configurability, as well as the fact that it is
independent of any particular desktop environment.

-Installation
The installation is performed from a live environment, booted via the network.
This live environment is a slightly modified version of the one provided by the
distribution, with some additions and a few modifications to enable it to
perform an unattended and automatic system installation. As for the production
of the live ISO image see [5] (just run install.sh providing the target
directory as the single argument). Care should be taken for all the files
under the target directory to have root ownership and execute permissions if
necessary, say for install.sh and install_chroot.sh). The actual installation
is performed by a shell script (skel/install.sh) which runs automatically upon
login to the live environment. The installation process is based on the
installation guide [6]. For more, one should refer to the installation guide
and the script itself, which should be fairly easy to follow and with inline
documentation.

- Reversion of system state (like Windows SteadyState)
The goal is for every user to find the system in a specific desired state,
independently of what the previous user might have performed. To achieve this we
employ filesystem snapshots, as provided by BTRFS [7]. A viable alternative
would be to depend on the permission system in Linux, as a normal user is very
restricted in what they can perform outside their home directory (and this
directory can easily be restored from a skeleton between user logins).
In particular, during system bootup, the whole filesystem is reverted using a
snapshot of the desired state. In addition to that, during every user login,
/home is reverted as well. We chose for these actions to be performed as late as
possible (not at shut down and logout, respectively) in order to give the system
administrator a chance to intervene before the modified state is lost, eg for
troubleshooting. For more, see revert.txt.

- User environment configuration
The user environment was configured with Windows users in mind, with a single
panel at the bottom, its elements laid out in a manner very close to what one
would expect from the Windows XP desktop. All configuration was performed as
necessary using the graphical settings application and then cloned (all
configuration files reside in ~/.config/xfce). For restricting the system
actions the user can perform, see target.txt.
Installation of the required software is performed via the package manager
(pacman [8]) wherever this is possible. For software that is not available
in the repositories, the AUR [9] is the primary alternative. Although it
contains packages that are not officially supported, in practice the vast
majority of them are trustworthy and regularly maintained, while enabling
their administration through pacman once installed. For the packages installed
initially, see skel/packages and skel/install_chroot.sh.

- Management and maintenance
We chose Ansible [10] for managing the systems once deployed, in a centralized,
uniform and convenient manner. This takes care of both everyday tasks like
shutting down or rebooting as well as less often employed tasks such as
installing or upgrading software. Owing to its agentless architecture (SSH
access and a python interpreter are the only requirements on the managed PCs),
its widespread use and its straightforward approach for simple tasks, it was
preferred over the alternatives (eg, Puppet and Chef).

[1] https://www.archlinux.org/
[2] https://wiki.archlinux.org/
[3] https://xfce.org/
[4] https://www.freedesktop.org/wiki/Software/LightDM/
[5] https://wiki.archlinux.org/index.php/Archiso
[6] https://wiki.archlinux.org/index.php/Installation_guide
[7] https://btrfs.wiki.kernel.org/index.php/Main_Page
[8] https://www.archlinux.org/pacman/
[9] https://aur.archlinux.org/
[10] https://www.ansible.com/
