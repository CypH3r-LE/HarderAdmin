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

HA_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HA_ROOT_DIR
readonly HA_LOADER="${HA_ROOT_DIR}/lib/loader.sh"

# ------------------------------------------------------------------------------
# Load loader
# ------------------------------------------------------------------------------

if [[ ! -f "${HA_LOADER}" ]]; then
    printf "ERROR: Loader not found: %s\n" "${HA_LOADER}" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${HA_LOADER}"


# ------------------------------------------------------------------------------
# Load framework
# ------------------------------------------------------------------------------

ha_load_libraries
ha_config_load

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {

    ha_init

    ha_menu_main

    ha_log_info "HarderAdmin started."

    }

main "$@"