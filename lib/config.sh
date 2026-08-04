#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# config.sh
# ==============================================================================
#

readonly HA_CONFIG_FILE="${HA_ROOT_DIR}/config/harderadmin.conf"


ha_config_load() {

    if [[ ! -f "${HA_CONFIG_FILE}" ]]; then
        ha_log_error "Configuration file not found: ${HA_CONFIG_FILE}"
        return 1
    fi

    # shellcheck disable=SC1090
    sed -i 's/\r$//' "${HA_CONFIG_FILE}"
    source "${HA_CONFIG_FILE}"

    ha_log_debug "Configuration loaded."
}


ha_config_get() {

    local key="$1"

    if [[ -z "${key}" ]]; then
        ha_log_error "Config key missing."
        return 1
    fi

    if [[ -v "${key}" ]]; then
        printf "%s\n" "${!key}"
        return 0
    fi

    ha_log_error "Unknown configuration key: ${key}"
    return 1
}


ha_config_set() {

    local key="$1"
    local value="$2"

    if [[ -z "${key}" || -z "${value}" ]]; then
        ha_log_error "Config key or value missing."
        return 1
    fi

    printf -v "${key}" "%s" "${value}"
}