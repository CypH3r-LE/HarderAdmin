#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# install.sh
# ==============================================================================
#
# Installs HarderAdmin to /opt/harderadmin (owned by root, not writable for
# other users) and links /usr/local/sbin/harderadmin.
# An existing config/harderadmin.conf in the target is kept.
#
# Usage: sudo ./install.sh [--prefix /opt/harderadmin]
# ------------------------------------------------------------------------------

set -Eeuo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
umask 022

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/opt/harderadmin"
LINK="/usr/local/sbin/harderadmin"

while (( $# > 0 )); do
    case "$1" in
        --prefix)
            TARGET_DIR="${2:?--prefix needs a directory}"
            shift
            ;;
        -h|--help)
            sed -n '9,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf "Unknown option: %s\n" "$1" >&2
            exit 64
            ;;
    esac
    shift
done

if [[ ${EUID} -ne 0 ]]; then
    printf "install.sh must be run as root.\n" >&2
    exit 1
fi

if [[ "${TARGET_DIR}" != /* ]]; then
    printf "Target must be an absolute path: %s\n" "${TARGET_DIR}" >&2
    exit 1
fi

printf "Installing HarderAdmin %s to %s\n" \
    "$(head -n 1 "${SOURCE_DIR}/VERSION" 2>/dev/null || echo dev)" "${TARGET_DIR}"

# Keep the existing configuration.
saved_config=""
if [[ -f "${TARGET_DIR}/config/harderadmin.conf" ]]; then
    saved_config="$(mktemp)"
    cp -a "${TARGET_DIR}/config/harderadmin.conf" "${saved_config}"
fi

install -d -m 0755 -o root -g root "${TARGET_DIR}"

for item in harderadmin.sh VERSION LICENSE lib modules tasks config; do
    if [[ -e "${SOURCE_DIR}/${item}" ]]; then
        rm -rf -- "${TARGET_DIR:?}/${item}"
        cp -r -- "${SOURCE_DIR}/${item}" "${TARGET_DIR}/${item}"
    fi
done

if [[ -n "${saved_config}" ]]; then
    cp -a "${saved_config}" "${TARGET_DIR}/config/harderadmin.conf"
    rm -f -- "${saved_config}"
    printf "Existing configuration kept.\n"
fi

# Ownership and permissions: root only may modify anything.
chown -R root:root -- "${TARGET_DIR}"
find "${TARGET_DIR}" -type d -exec chmod 0755 {} +
find "${TARGET_DIR}" -type f -exec chmod 0644 {} +
chmod 0755 -- "${TARGET_DIR}/harderadmin.sh"
chmod 0640 -- "${TARGET_DIR}/config/harderadmin.conf"

ln -sfn -- "${TARGET_DIR}/harderadmin.sh" "${LINK}"

printf "Done. Start with: sudo harderadmin   (audit only: sudo harderadmin --audit)\n"
