#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/colors.sh
# ==============================================================================

# Colors and icons are exported as framework constants.
# They are consumed by other sourced libraries.

# shellcheck disable=SC2034

readonly HA_COLOR_RESET="\033[0m"

readonly HA_COLOR_RED="\033[0;31m"
readonly HA_COLOR_GREEN="\033[0;32m"
readonly HA_COLOR_YELLOW="\033[1;33m"
readonly HA_COLOR_BLUE="\033[0;34m"
readonly HA_COLOR_MAGENTA="\033[0;35m"
readonly HA_COLOR_CYAN="\033[0;36m"
readonly HA_COLOR_WHITE="\033[1;37m"

readonly HA_ICON_OK="✔"
readonly HA_ICON_FAIL="✖"
readonly HA_ICON_WARN="⚠"
readonly HA_ICON_INFO="ℹ"
readonly HA_ICON_ARROW="❯"