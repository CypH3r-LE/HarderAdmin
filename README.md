# HarderAdmin

Server Hardening Suite for Linux (Debian / Ubuntu).

The tasks follow the
[Ubuntu 26.04 server hardening guide](https://computingforgeeks.com/harden-ubuntu-2604-server/)
step by step; deviations are documented in the task files.

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
sudo harderadmin --rollback SSH-002   # undo the last run of a task (console recovery)
sudo harderadmin --help
```

`--audit` exit codes: `0` compliant, `1` findings, `2` errors or blocked tasks.

## Tasks

| ID      | Task                       | What it does |
|---------|----------------------------|--------------|
| SYS-001 | System updates             | `apt-get update` + `full-upgrade`, non-interactive |
| SYS-002 | Automatic security updates | unattended-upgrades, APT periodic settings, timers |
| SYS-003 | Administrative user        | non-root sudo user, or SSH key for an existing admin |
| SYS-004 | Kernel hardening           | sysctl network/kernel settings in `/etc/sysctl.d/99-zz-harderadmin.conf` |
| SYS-005 | AppArmor                   | enable AppArmor, enforce profiles of installed services |
| SSH-001 | SSH baseline               | no root login, no X11/agent/TCP forwarding, MaxAuthTries 3, LoginGraceTime 20, ClientAlive 300/2 |
| SSH-002 | SSH key-only               | PasswordAuthentication / KbdInteractiveAuthentication no |
| SSH-003 | AllowUsers                 | SSH login only for selected users |
| SSH-004 | SSH port                   | move sshd (socket activation aware), UFW rule first |

Recommended order: SYS-001 … SYS-003 (admin **with SSH key**), then SSH-001 … SSH-004.

## Lockout protection (SSH)

SSH tasks refuse to run when no administrator could log in afterwards
(SSH-002 needs an admin with an SSH key). Every SSH change is protected by a
safety net:

1. A systemd timer is armed that rolls the change back after `GUARD_TIMEOUT`
   seconds (default 180).
2. sshd is reloaded. **Keep your session open** and test a login in a new
   terminal.
3. Type `yes` to keep the change. Without confirmation, or if your connection
   breaks, the change is rolled back automatically.

Each SSH task writes its own drop-in `/etc/ssh/sshd_config.d/00-harderadmin-ssh-00X.conf`.
The `00-` prefix makes the values win over `50-cloud-init.conf` (which sets
`PasswordAuthentication yes` on many cloud images); a `99-*.conf` file as in
the guide would lose against it. All checks use `sshd -T`, the effective
configuration.

`AllowTcpForwarding no` (SSH-001) breaks SSH tunnels and **VS Code
Remote-SSH**; set `SSH_TCP_FORWARDING="yes"` in the configuration if you use them.

## Files

| Path                           | Content |
|--------------------------------|---------|
| `config/harderadmin.conf`      | configuration (parsed, never executed) |
| `/var/log/harderadmin/`        | log file, every change is logged with `[CHANGE]` |
| `/var/lib/harderadmin/backups/`| backups per task run, used for rollback (menu "Backups / Rollback" or `--rollback`) |

## Writing a task

A task is a file in `tasks/<category>/` that defines its functions and calls
`ha_task_register`. The menu is generated from the registry: a task shows up
in the menu of its category (`lib/menu.sh`, `HA_MENU_CATEGORIES`). The contract (check is read-only, backups before changes,
status values) is documented at the top of `lib/task_registry.sh`.

## Development

```bash
make check     # bash -n + ShellCheck
make audit     # read-only audit from the checkout (root)
```

## License

MIT, see [LICENSE](LICENSE).
