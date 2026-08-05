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

        return "${HA_TASK_ERROR}"

    fi


    if ! apt-get update -qq >/dev/null 2>&1; then

        ha_task_set_message "Unable to update package information."

        return "${HA_TASK_ERROR}"

    fi


    local updates

    updates="$(apt-get -s upgrade | grep -c '^Inst ')"


    if [[ "${updates}" -eq 0 ]]; then

        ha_task_set_message "System is already up to date."

        return "${HA_TASK_COMPLETED}"

    fi


    ha_task_set_message "${updates} package updates available."

    return "${HA_TASK_READY}"
}


ha_task_sys001_info() {

    ha_ui_info "$(ha_task_get_message)"

}


ha_task_sys001_execute() {

    ha_ui_info "Not implemented yet."

    ha_pause
}


ha_task_sys001_verify() {

    return 0
}


ha_task_sys001_rollback() {

    return 0
}

ha_task_sys001_register