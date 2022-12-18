# Ansible roles and playbooks for configuration management

This includes various playbooks and roles managing the overall configuration of
the PCs plus some day-to-day tasks.

**NOTE**: All playbooks / roles expect to run with administrator privileges.

## Quickstart

Taking over from the [installer](../archlive), to apply the base desktop
configuration:

```sh
ansible-playbook post-install.yml
ansible-playbook reboot.yml
```

Look into the [`extra`](roles/extra) role for course-specific software
configuration.

## Playbooks

- [`persist-play.yml`](persist-play.yml) makes the current configuration
  permanent (see [reversion mechanism](../reversion_mechanism.md)). Optionally
  re-installs GRUB if the `grub-install` tag is specified, e.g. with
  `--tags all,grub-install`.
- [`post-install.yml`](post-install.yml) applies the necessary post-installer
  configuration (desktop, software etc.)
- [`poweroff.yml`](poweroff.yml) powers off
- [`reboot.yml`](reboot.yml) reboots
- [`upgrade.yml`](upgrade.yml) upgrades installed software. Optionally upgrades
  pip packages if the `pip` tag is specified, e.g. with `--tags pip`. Does
  **not** persist the changes.
