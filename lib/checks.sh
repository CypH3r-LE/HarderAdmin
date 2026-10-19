#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/checks.sh
# ==============================================================================
#

ha_check_root() {

    [[ "${EUID}" -eq 0 ]]
}


ha_check_config() {

    [[ -f "${HA_CONFIG_FILE}" ]]
}


ha_check_logging() {

    [[ -n "${HA_LOG_FILE}" && -w "${HA_LOG_FILE}" ]]
}


ha_check_backup() {

    ha_backup_enabled \
        && install -d -m 0700 -- "${BACKUP_DIR}" 2>/dev/null \
        && [[ -w "${BACKUP_DIR}" ]]
}
