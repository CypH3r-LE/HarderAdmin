#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# logger.sh
# ==============================================================================
#

readonly HA_LOG_DIR="logs"
readonly HA_LOG_FILE="${HA_LOG_DIR}/harderadmin.log"


ha_logger_init() {

    mkdir -p "${HA_LOG_DIR}"

    touch "${HA_LOG_FILE}"
}


ha_log_write() {

    local level="$1"
    local message="$2"

    printf "%s [%s] %s\n" \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "${level}" \
        "${message}" >> "${HA_LOG_FILE}"
}


ha_log_info() {

    ha_log_write "INFO" "$1"
}


ha_log_warn() {

    ha_log_write "WARN" "$1"
}


ha_log_error() {

    ha_log_write "ERROR" "$1"
}


ha_log_debug() {

    ha_log_write "DEBUG" "$1"
}