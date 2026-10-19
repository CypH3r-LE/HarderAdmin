# Changelog

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
