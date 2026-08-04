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

readonly HA_VERSION_FILE="VERSION"
readonly HA_LIB_DIR="lib"
readonly HA_CONFIG_DIR="config"
readonly HA_MODULE_DIR="modules"

# ------------------------------------------------------------------------------
# Load libraries
# ------------------------------------------------------------------------------

source "${HA_LIB_DIR}/colors.sh"
source "${HA_LIB_DIR}/logger.sh"
source "${HA_LIB_DIR}/ui.sh"
source "${HA_LIB_DIR}/common.sh"

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {

    ha_init

    ha_draw_header

    ha_log_info "HarderAdmin started."

    ha_pause
}

main "$@"