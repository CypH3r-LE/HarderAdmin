#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/status.sh
# ==============================================================================
#

ha_status_ok() {

    printf "%b%s%b %s\n" \
        "${HA_COLOR_GREEN}" \
        "${HA_ICON_OK}" \
        "${HA_COLOR_RESET}" \
        "$1"
}


ha_status_fail() {

    printf "%b%s%b %s\n" \
        "${HA_COLOR_RED}" \
        "${HA_ICON_FAIL}" \
        "${HA_COLOR_RESET}" \
        "$1"
}


ha_status_warning() {

    printf "%b%s%b %s\n" \
        "${HA_COLOR_YELLOW}" \
        "${HA_ICON_WARN}" \
        "${HA_COLOR_RESET}" \
        "$1"
}


ha_status_info() {

    printf "%b%s%b %s\n" \
        "${HA_COLOR_BLUE}" \
        "${HA_ICON_INFO}" \
        "${HA_COLOR_RESET}" \
        "$1"
}