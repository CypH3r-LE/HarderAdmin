#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Server Hardening Suite for Linux
#
# File      : harderadmin.sh
# Author    : Paul Schallenberg
# License   : MIT
# Repository: https://github.com/CypH3r-LE/HarderAdmin
#
# Description:
# Main entry point for HarderAdmin.
# ==============================================================================
#

set -Eeuo pipefail

# Run with a known, safe environment: HarderAdmin runs as root.
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH
umask 027

HA_ROOT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
readonly HA_ROOT_DIR
readonly HA_LOADER="${HA_ROOT_DIR}/lib/loader.sh"

# ------------------------------------------------------------------------------
# File trust check
#
# Every file HarderAdmin sources runs as root. A file (or its directory) that
# another user can modify would therefore be a privilege escalation.
# Accepted owners: root, or the admin who invoked sudo (they already have root).
# Group write is accepted only for root's group or a user-private group.
# ------------------------------------------------------------------------------

ha_trust_check_path() {

    local path="$1"
    local owner group mode

    [[ ${EUID} -eq 0 ]] || return 0

    if [[ ! -e "${path}" ]]; then
        printf "ERROR: File not found: %s\n" "${path}" >&2
        return 1
    fi

    read -r owner group mode < <(stat -L -c '%U %G %a' -- "${path}")

    if [[ "${owner}" != "root" && "${owner}" != "${SUDO_USER:-root}" ]]; then
        printf "ERROR: Untrusted owner '%s': %s\n" "${owner}" "${path}" >&2
        return 1
    fi

    if (( 8#${mode} & 8#0002 )); then
        printf "ERROR: World-writable path refused: %s\n" "${path}" >&2
        return 1
    fi

    if (( 8#${mode} & 8#0020 )) \
        && [[ "${group}" != "root" && "${group}" != "${owner}" ]]; then
        printf "ERROR: Group-writable path refused (group %s): %s\n" \
            "${group}" "${path}" >&2
        return 1
    fi

    return 0
}

ha_trust_check_file() {

    local file="$1"

    ha_trust_check_path "$(dirname -- "${file}")" \
        && ha_trust_check_path "${file}"
}

# ------------------------------------------------------------------------------
# Load loader
# ------------------------------------------------------------------------------

if [[ ! -f "${HA_LOADER}" ]]; then
    printf "ERROR: Loader not found: %s\n" "${HA_LOADER}" >&2
    exit 1
fi

ha_trust_check_path "${HA_ROOT_DIR}" || exit 1
ha_trust_check_file "${HA_LOADER}" || exit 1

# shellcheck source=lib/loader.sh
source "${HA_LOADER}"

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {

    # Libraries only define functions and constants; nothing is executed yet.
    ha_load_libraries

    # Handle options that work without root (--help, --version).
    ha_cli_parse "$@"

    # Root check, configuration, logging.
    ha_init

    # Checks, tasks and modules are loaded after the environment is ready.
    ha_load_checks
    ha_load_tasks
    ha_load_modules

    ha_log_info "HarderAdmin ${HA_VERSION} started (mode: ${HA_CLI_MODE})."

    case "${HA_CLI_MODE}" in

        audit)
            local exit_code=0
            ha_task_audit_report || exit_code=$?
            exit "${exit_code}"
            ;;

        *)
            ha_dashboard_start
            ;;

    esac
}

main "$@"
