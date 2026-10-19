#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# uninstall.sh
# ==============================================================================
#
# Removes the HarderAdmin program files. Hardening changes on the system are
# NOT reverted. Logs and backups are kept unless --purge is given.
#
# Usage: sudo ./uninstall.sh [--prefix /opt/harderadmin] [--purge]
# ------------------------------------------------------------------------------

set -Eeuo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

TARGET_DIR="/opt/harderadmin"
LINK="/usr/local/sbin/harderadmin"
PURGE=false

while (( $# > 0 )); do
    case "$1" in
        --prefix)
            TARGET_DIR="${2:?--prefix needs a directory}"
            shift
            ;;
        --purge)
            PURGE=true
            ;;
        *)
            printf "Unknown option: %s\n" "$1" >&2
            exit 64
            ;;
    esac
    shift
done

if [[ ${EUID} -ne 0 ]]; then
    printf "uninstall.sh must be run as root.\n" >&2
    exit 1
fi

if [[ ! -f "${TARGET_DIR}/harderadmin.sh" ]]; then
    printf "No HarderAdmin installation found in %s\n" "${TARGET_DIR}" >&2
    exit 1
fi

if [[ -L "${LINK}" && "$(readlink -f "${LINK}")" == "${TARGET_DIR}/harderadmin.sh" ]]; then
    rm -f -- "${LINK}"
fi

rm -rf -- "${TARGET_DIR:?}"
printf "Removed %s\n" "${TARGET_DIR}"

if [[ "${PURGE}" == true ]]; then
    rm -rf -- /var/log/harderadmin /var/lib/harderadmin
    printf "Removed logs and backups.\n"
else
    printf "Logs (/var/log/harderadmin) and backups (/var/lib/harderadmin) were kept.\n"
fi
