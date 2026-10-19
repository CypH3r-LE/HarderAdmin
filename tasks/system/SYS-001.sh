#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# tasks/system/SYS-001
# ==============================================================================
#
# The check is read-only: it uses the cached package lists and reports READY
# when they are older than HA_SYS001_MAX_LIST_AGE. Execute refreshes them.
# Updates are counted with "full-upgrade" (same as execute), otherwise kernel
# updates that need new packages are "kept back" and not counted.
# ------------------------------------------------------------------------------

readonly HA_SYS001_MAX_LIST_AGE=86400


ha_task_sys001_register() {

    ha_task_register \
    "SYS-001" \
    "System Updates" \
    "System" \
    "Update package lists and install available updates." \
    "false" \
    "possible" \
    "true" \
    "ha_task_sys001_check" \
    "ha_task_sys001_info" \
    "ha_task_sys001_execute" \
    "ha_task_sys001_verify" \
    ""
}


# Prints the number of pending updates. Returns 1 if simulation fails.
ha_task_sys001_count_updates() {

    local simulation

    simulation="$(LC_ALL=C apt-get -s full-upgrade 2>/dev/null)" || return 1

    grep -c '^Inst ' <<< "${simulation}" || true
}


# Prints the age of the package lists in seconds.
ha_task_sys001_list_age() {

    local newest

    newest="$(
        find /var/lib/apt/lists -maxdepth 1 -type f -name '*_Packages*' \
            -printf '%T@\n' 2>/dev/null | sort -n | tail -n 1
    )" || true

    if [[ -z "${newest}" ]]; then
        printf "%s" "-1"
        return 0
    fi

    printf "%s" "$(( $(date +%s) - ${newest%.*} ))"
}


ha_task_sys001_check() {

    local updates
    local age

    if ! ha_command_exists apt-get; then
        ha_task_result "${HA_TASK_NOT_APPLICABLE}" \
            "APT package manager not available."
        return 0
    fi

    age="$(ha_task_sys001_list_age)"

    if (( age < 0 || age > HA_SYS001_MAX_LIST_AGE )); then
        ha_task_result "${HA_TASK_READY}" \
            "Package lists are missing or older than 24 hours."
        return 0
    fi

    if ! updates="$(ha_task_sys001_count_updates)"; then
        ha_task_result "${HA_TASK_ERROR}" \
            "Unable to simulate the upgrade (broken dependencies?)."
        return 0
    fi

    if (( updates == 0 )); then
        ha_task_result "${HA_TASK_COMPLETED}" "System is up to date."
        return 0
    fi

    ha_task_result "${HA_TASK_READY}" "${updates} package updates available."
}


ha_task_sys001_info() {

    ha_ui_info "$(ha_task_get_message)"
    ha_ui_info "Runs: apt-get update && apt-get full-upgrade (non-interactive)."
    ha_ui_info "Existing configuration files are kept on conflicts."
}


ha_task_sys001_execute() {

    if ! ha_apt_get update; then
        ha_task_result "${HA_TASK_ERROR}" \
            "Unable to update package information."
        return 0
    fi

    if ! ha_apt_get -y full-upgrade; then
        ha_task_result "${HA_TASK_ERROR}" "System update failed."
        return 0
    fi

    ha_log_change "SYS-001" "apt-get full-upgrade completed."

    ha_task_result "${HA_TASK_COMPLETED}" \
        "System updates installed successfully."
}


ha_task_sys001_verify() {

    local updates

    if ! updates="$(ha_task_sys001_count_updates)"; then
        ha_task_result "${HA_TASK_ERROR}" "Unable to simulate the upgrade."
        return 0
    fi

    if (( updates == 0 )); then
        ha_task_result "${HA_TASK_COMPLETED}" "System is up to date."
        return 0
    fi

    ha_task_result "${HA_TASK_ERROR}" \
        "${updates} package updates still available (held packages?)."
}


ha_task_sys001_register
