#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/logger.sh
# ==============================================================================
#
# Log file : ${LOG_DIR}/harderadmin.log (default /var/log/harderadmin)
# Syslog   : WARN and ERROR are also sent to syslog/journal (tag "harderadmin")
#
# Messages logged before ha_logger_init (e.g. configuration errors) are not
# written to the file; WARN and ERROR are printed to stderr instead, so
# logging can never abort the program.
# ------------------------------------------------------------------------------

HA_LOG_DIR=""
HA_LOG_FILE=""
HA_LOG_LEVEL_NUM=20

declare -Agr HA_LOG_LEVELS=(
    [DEBUG]=10
    [INFO]=20
    [WARN]=30
    [ERROR]=40
)


ha_logger_init() {

    local log_dir="$1"
    local level="${2:-INFO}"

    HA_LOG_LEVEL_NUM="${HA_LOG_LEVELS[${level}]:-20}"

    if ! install -d -m 0750 -- "${log_dir}" 2>/dev/null; then
        printf "WARNING: Unable to create log directory: %s\n" "${log_dir}" >&2
        return 0
    fi

    HA_LOG_DIR="${log_dir}"
    HA_LOG_FILE="${HA_LOG_DIR}/harderadmin.log"

    if ! touch -- "${HA_LOG_FILE}" 2>/dev/null; then
        printf "WARNING: Unable to write log file: %s\n" "${HA_LOG_FILE}" >&2
        HA_LOG_FILE=""
        return 0
    fi

    chmod 0640 -- "${HA_LOG_FILE}" 2>/dev/null || true
}


ha_log_write() {

    local level="$1"
    local message="$2"
    local level_num="${HA_LOG_LEVELS[${level}]:-20}"

    if (( level_num < HA_LOG_LEVEL_NUM )); then
        return 0
    fi

    if [[ -z "${HA_LOG_FILE}" ]]; then

        if (( level_num >= 30 )); then
            printf "%s: %s\n" "${level}" "${message}" >&2
        fi

        return 0
    fi

    {
        printf "%s [%s] %s\n" \
            "$(date '+%Y-%m-%d %H:%M:%S')" \
            "${level}" \
            "${message}" >> "${HA_LOG_FILE}"
    } 2>/dev/null || true

    if (( level_num >= 30 )) && command -v logger >/dev/null 2>&1; then
        logger -t harderadmin -p "user.${level,,}" -- "${message}" \
            2>/dev/null || true
    fi
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


# Audit trail for every change HarderAdmin makes to the system.
ha_log_change() {

    local task_id="$1"
    local message="$2"

    ha_log_write "INFO" "[CHANGE] [${task_id}] ${message}"
}
