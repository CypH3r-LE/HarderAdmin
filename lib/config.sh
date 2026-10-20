#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/config.sh
# ==============================================================================
#
# The configuration file is parsed, never sourced: only whitelisted
# KEY="value" lines are accepted, so it cannot execute code as root.
# ------------------------------------------------------------------------------

readonly HA_CONFIG_FILE="${HA_ROOT_DIR}/config/harderadmin.conf"
readonly HA_TASK_STATUS_FILE="${HA_ROOT_DIR}/config/task_status.conf"

# Allowed keys with their default values and validation patterns.
declare -Agr HA_CONFIG_DEFAULTS=(
    [LANGUAGE]="de"
    [THEME]="default"
    [DEBUG]="false"
    [LOG_LEVEL]="INFO"
    [LOG_DIR]="/var/log/harderadmin"
    [BACKUP_ENABLED]="true"
    [BACKUP_DIR]="/var/lib/harderadmin/backups"
    [SYSCTL_RP_FILTER]="1"
    [GUARD_TIMEOUT]="180"
    [SSH_TCP_FORWARDING]="no"
)

declare -Agr HA_CONFIG_PATTERNS=(
    [LANGUAGE]='^[a-z]{2}$'
    [THEME]='^[a-z0-9_-]+$'
    [DEBUG]='^(true|false)$'
    [LOG_LEVEL]='^(DEBUG|INFO|WARN|ERROR)$'
    [LOG_DIR]='^/[A-Za-z0-9._/-]+$'
    [BACKUP_ENABLED]='^(true|false)$'
    [BACKUP_DIR]='^/[A-Za-z0-9._/-]+$'
    [SYSCTL_RP_FILTER]='^[12]$'
    [GUARD_TIMEOUT]='^([6-9][0-9]|[1-8][0-9]{2}|900)$'
    [SSH_TCP_FORWARDING]='^(no|yes|local)$'
)


ha_config_is_key() {

    [[ "${1:-}" =~ ^[A-Z_][A-Z0-9_]*$ && -v "HA_CONFIG_DEFAULTS[$1]" ]]
}


ha_config_load() {

    local line
    local line_number=0
    local key
    local value

    # Defaults first, so a missing key never leaves a variable unset.
    for key in "${!HA_CONFIG_DEFAULTS[@]}"; do
        printf -v "${key}" "%s" "${HA_CONFIG_DEFAULTS[${key}]}"
    done

    if [[ ! -f "${HA_CONFIG_FILE}" ]]; then
        ha_ui_warning "Configuration file not found, using defaults: ${HA_CONFIG_FILE}" >&2
    else

        ha_trust_check_file "${HA_CONFIG_FILE}" || return 1

        while IFS= read -r line || [[ -n "${line}" ]]; do

            line_number=$(( line_number + 1 ))

            line="${line%$'\r'}"

            # Skip empty lines and comments.
            [[ "${line}" =~ ^[[:space:]]*(#.*)?$ ]] && continue

            if [[ ! "${line}" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                ha_ui_warning "Config line ${line_number} ignored (invalid syntax)." >&2
                continue
            fi

            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"

            # Strip trailing whitespace and one level of matching quotes.
            value="${value%"${value##*[![:space:]]}"}"

            if [[ "${value}" =~ ^\"(.*)\"$ || "${value}" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi

            if ! ha_config_set "${key}" "${value}"; then
                ha_ui_warning "Config line ${line_number} ignored (${key})." >&2
            fi

        done < "${HA_CONFIG_FILE}"
    fi

    if [[ "${DEBUG}" == "true" ]]; then
        # shellcheck disable=SC2034 # used in common.sh
        LOG_LEVEL="DEBUG"
    fi

    ha_config_load_task_status
}


ha_config_get() {

    local key="${1:-}"

    if ! ha_config_is_key "${key}"; then
        ha_log_error "Unknown configuration key: ${key}"
        return 1
    fi

    printf "%s\n" "${!key}"
}


ha_config_set() {

    local key="${1:-}"
    local value="${2:-}"

    if ! ha_config_is_key "${key}"; then
        ha_log_error "Unknown configuration key: ${key}"
        return 1
    fi

    if [[ ! "${value}" =~ ${HA_CONFIG_PATTERNS[${key}]} ]]; then
        ha_log_error "Invalid value for ${key}: ${value}"
        return 1
    fi

    printf -v "${key}" "%s" "${value}"
}


ha_config_load_task_status() {

    # Constants are readonly; load them only once.
    if [[ -v HA_TASK_READY ]]; then
        return 0
    fi

    ha_load_file "${HA_TASK_STATUS_FILE}"
}
