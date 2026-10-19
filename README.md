# HarderAdmin

Server Hardening Suite for Linux (Debian / Ubuntu).

HarderAdmin checks and hardens a server step by step. Every task first checks
the current state, explains what it will change, asks for confirmation,
verifies the result and can roll back its changes.

> **Status:** early development. Test on a non-production system or take a
> snapshot first. Keep a second root session open while hardening remote
> servers.

## Requirements

- Debian 12+ or Ubuntu 22.04+ (or a derivative with `ID_LIKE=debian`)
- Bash 4.4+
- Root privileges

## Installation

```bash
git clone https://github.com/CypH3r-LE/HarderAdmin.git
cd HarderAdmin
sudo ./install.sh          # installs to /opt/harderadmin, links /usr/local/sbin/harderadmin
```

Running directly from the checkout works too (`sudo ./harderadmin.sh`).
HarderAdmin refuses to load files that users other than root (or the admin who
invoked `sudo`) can modify, because they would run as root.

## Usage

```bash
sudo harderadmin            # interactive menu
sudo harderadmin --audit    # read-only report of all tasks
sudo harderadmin --help
```

`--audit` exit codes: `0` compliant, `1` findings, `2` errors or blocked tasks.

## Tasks

| ID      | Task                       | What it does |
|---------|----------------------------|--------------|
| SYS-001 | System updates             | `apt-get update` + `full-upgrade`, non-interactive |
| SYS-002 | Automatic security updates | unattended-upgrades, APT periodic settings, timers |
| SYS-003 | Administrative user        | non-root sudo user, optional SSH public key |
| SYS-004 | Kernel hardening           | sysctl network/kernel settings in `/etc/sysctl.d/99-zz-harderadmin.conf` |
| SYS-005 | AppArmor                   | enable AppArmor, enforce profiles of installed services |

## Files

| Path                           | Content |
|--------------------------------|---------|
| `config/harderadmin.conf`      | configuration (parsed, never executed) |
| `/var/log/harderadmin/`        | log file, every change is logged with `[CHANGE]` |
| `/var/lib/harderadmin/backups/`| backups per task run, used for rollback |

## Writing a task

A task is a file in `tasks/<category>/` that defines its functions and calls
`ha_task_register`. The contract (check is read-only, backups before changes,
status values) is documented at the top of `lib/task_registry.sh`.

## Development

```bash
make check     # bash -n + ShellCheck
make audit     # read-only audit from the checkout (root)
```

## License

MIT, see [LICENSE](LICENSE).
