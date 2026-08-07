#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# tasks/system/SYS-001
# ==============================================================================

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
    "ha_task_sys001_rollback"
}


ha_task_sys001_check() {

    if ! command -v apt >/dev/null 2>&1; then

        ha_task_set_message "APT package manager not available."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! apt-get update -qq >/dev/null 2>&1; then

        ha_task_set_message "Unable to update package information."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    local updates

    updates="$(apt-get -s upgrade | grep -c '^Inst ' || true)"


    if [[ "${updates}" -eq 0 ]]; then

        ha_task_set_message "System is already up to date."
        ha_task_set_status "${HA_TASK_COMPLETED}"

        return 0

    fi


    ha_task_set_message "${updates} package updates available."
    ha_task_set_status "${HA_TASK_READY}"

    return 0
}


ha_task_sys001_info() {

    ha_ui_info "$(ha_task_get_message)"

}


ha_task_sys001_execute() {

    ha_task_set_message "Installing system updates."

    if ! apt-get update; then

        ha_task_set_message "Unable to update package information."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! apt-get full-upgrade -y; then

        ha_task_set_message "System update failed."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    ha_task_set_message "System updates installed successfully."
    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}


ha_task_sys001_verify() {

    local updates

    updates="$(apt-get -s upgrade | grep -c '^Inst ' || true)"


    if [[ "${updates}" -eq 0 ]]; then

        ha_task_set_message "System is up to date."
        ha_task_set_status "${HA_TASK_COMPLETED}"

        return 0

    fi


    ha_task_set_message "${updates} package updates still available."
    ha_task_set_status "${HA_TASK_ERROR}"

    return 0
}


ha_task_sys001_rollback() {

    return 0
}

ha_task_sys001_register