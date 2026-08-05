#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SYS-002
# ==============================================================================


ha_task_sys002_register() {

    ha_task_register \
    "SYS-002" \
    "Automatic security updates" \
    "System" \
    "Configure automatic security updates." \
    "false" \
    "possible" \
    "true" \
    "ha_task_sys002_check" \
    "ha_task_sys002_info" \
    "ha_task_sys002_execute" \
    "ha_task_sys002_verify" \
    "ha_task_sys002_rollback"
}

ha_task_sys002_check() {

    if ! command -v unattended-upgrade >/dev/null 2>&1; then

        ha_task_set_message "Automatic security updates are not installed."

        return "${HA_TASK_READY}"

    fi


    ha_task_set_message "Automatic security updates are already configured."

    return "${HA_TASK_COMPLETED}"
}

ha_task_sys002_info() {

    ha_ui_info "$(ha_task_get_message)"

}

ha_task_sys002_execute() {

    ha_task_set_message "Installing unattended upgrades."


    if ! apt-get install -y unattended-upgrades; then

        ha_task_set_message "Unable to install unattended upgrades."

        return "${HA_TASK_ERROR}"

    fi


    if ! dpkg-reconfigure -plow unattended-upgrades; then

        ha_task_set_message "Unable to configure unattended upgrades."

        return "${HA_TASK_ERROR}"

    fi


    ha_task_set_message "Automatic security updates configured successfully."

    return "${HA_TASK_COMPLETED}"
}


ha_task_sys002_verify() {

    local config_file="/etc/apt/apt.conf.d/20auto-upgrades"
    local unattended_file="/etc/apt/apt.conf.d/50unattended-upgrades"


    if [[ ! -f "${config_file}" ]]; then

        ha_task_set_message "20auto-upgrades configuration file is missing."

        return "${HA_TASK_ERROR}"

    fi


    if [[ ! -f "${unattended_file}" ]]; then

        ha_task_set_message "50unattended-upgrades configuration file is missing."

        return "${HA_TASK_ERROR}"

    fi


    if ! grep -q 'APT::Periodic::Update-Package-Lists "1";' "${config_file}"; then

        ha_task_set_message "Package list updates are not enabled."

        return "${HA_TASK_ERROR}"

    fi


    if ! grep -q 'APT::Periodic::Unattended-Upgrade "1";' "${config_file}"; then

        ha_task_set_message "Automatic security updates are not enabled."

        return "${HA_TASK_ERROR}"

    fi


    ha_task_set_message "Automatic security updates are configured."

    return "${HA_TASK_COMPLETED}"
}


ha_task_sys002_rollback() {

    return "${HA_TASK_COMPLETED}"

}


ha_task_sys002_register