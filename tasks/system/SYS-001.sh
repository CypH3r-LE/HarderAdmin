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

    return 0
}


ha_task_sys001_info() {

    ha_ui_info "Updates package lists and installs available updates."
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