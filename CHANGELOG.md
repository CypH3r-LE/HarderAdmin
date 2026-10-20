# Changelog

## [0.2.0] - Unreleased

### Added
- SSH module: SSH-001 baseline hardening, SSH-002 key-only authentication,
  SSH-003 AllowUsers, SSH-004 port change.
- Lockout guard (`lib/guard.sh`): systemd timer rolls SSH changes back unless
  a new login is confirmed; works when the connection drops.
- Lockout prevention: SSH tasks are blocked when no administrator could log
  in afterwards (keys, password state, AllowUsers/DenyUsers/Groups).
- `--rollback <TASK-ID>` and menu "Backups / Rollback"; the task context is
  saved with each backup so rollbacks work in a new process.
- SYS-003 can add an SSH key to an existing administrator; reports READY
  while no administrator has a key.
- Shared helpers for admin users (`lib/users.sh`) and ports (`ha_port_listening`).
- Config: `GUARD_TIMEOUT`, `SSH_TCP_FORWARDING`.

### Changed
- Menus are generated from the task registry by category; audit output is
  grouped by category. `modules/system_hardening.sh` removed.
- SYS-002 also sets `APT::Periodic::Download-Upgradeable-Packages "1"` (guide).

### Notes
- SSH drop-ins use the `00-` prefix (wins over `50-cloud-init.conf`), one file
  per task so rollbacks stay independent.
- SSH-004 uses the socket generator of Ubuntu 24.04+ (`daemon-reload` +
  restart `ssh.socket`) and falls back to the guide's method (disable
  `ssh.socket`, enable `ssh.service`) when the generator is missing.

## [0.1.0] - Unreleased

### Fixed
- HarderAdmin did not start from a fresh checkout: the log directory was
  relative and never created.
- A failed or blocked task terminated the whole program instead of returning
  to the menu.
- `pipefail` combined with `grep -q` / `awk … exit` caused false results and
  crashes (SYS-005).
- `clear` aborted the program without a usable `TERM`.
- Menu input with a leading zero (`08`) caused an arithmetic error.
- Closed stdin (EOF) aborted the program instead of exiting cleanly.
- SYS-001 did not count kernel updates (`upgrade` vs. `full-upgrade`).
- SYS-002 opened an interactive debconf dialog; correction reported success
  without changing anything.
- SYS-005 looped forever on systems without chrony and reported "completed"
  while profiles were not enforced.

### Security
- Files are only sourced if they are owned by root (or the invoking sudo
  user) and not writable by other users.
- The configuration file is parsed with a key whitelist instead of being
  sourced; it is no longer modified at startup.
- Fixed `PATH` and `umask 027` at startup.
- `/etc/os-release` is read in a subshell instead of overwriting globals.

### Added
- `--audit`, `--help`, `--version` command line options.
- Backups before every change and rollback (files + task rollback hooks).
- Task status `NOT_APPLICABLE`; registry validates IDs and functions.
- Reboot hint when `/var/run/reboot-required` exists.
- Log levels, syslog for warnings/errors, `[CHANGE]` audit trail.
- SYS-003: SSH public key installation.
- SYS-004: settings defined once (data-driven), additional settings,
  rollback of runtime values, `SYSCTL_RP_FILTER` option.
- `install.sh`, `uninstall.sh`, `Makefile`, CI workflow, README.

### Changed
- SYS-004 writes `/etc/sysctl.d/99-zz-harderadmin.conf` (sorts after
  `99-sysctl.conf`); the old `99-hardening.conf` is migrated.
- SYS-004 no longer sets `tcp_max_syn_backlog` and `tcp_syn_retries`
  (could lower the kernel defaults, not security relevant).
- Colors are disabled when output is not a terminal or `NO_COLOR` is set.
