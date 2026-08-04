#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# checks.sh
# ==============================================================================
#

ha_check_root() {

    if [[ "${EUID}" -eq 0 ]]; then
        return 0
    fi

    return 1
}


ha_check_config() {

    if [[ -f "${HA_CONFIG_FILE}" ]]; then
        return 0
    fi

    return 1
}


ha_check_logging() {

    if [[ -f "${HA_LOG_FILE}" ]]; then
        return 0
    fi

    return 1
}