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
    "ha_task_sys002_rollback" \
    "ha_task_sys002_correction"
}

ha_task_sys002_check() {

    local config_file="/etc/apt/apt.conf.d/20auto-upgrades"
    local unattended_file="/etc/apt/apt.conf.d/50unattended-upgrades"


    if ! command -v unattended-upgrade >/dev/null 2>&1; then

        ha_task_set_message "Automatic security updates are not installed."
        ha_task_set_status "${HA_TASK_READY}"

        return 0

    fi


    if [[ ! -f "${config_file}" ]]; then

        ha_task_set_message "Automatic security updates are not configured."
        ha_task_set_status "${HA_TASK_READY}"

        return 0

    fi


    if [[ ! -f "${unattended_file}" ]]; then

        ha_task_set_message "Automatic security updates are not configured."
        ha_task_set_status "${HA_TASK_READY}"

        return 0

    fi


    if ! grep -q 'APT::Periodic::Update-Package-Lists "1";' "${config_file}"; then

        ha_task_set_message "Automatic security updates are not fully configured."
        ha_task_set_status "${HA_TASK_READY}"

        return 0

    fi


    if ! grep -q 'APT::Periodic::Unattended-Upgrade "1";' "${config_file}"; then

        ha_task_set_message "Automatic security updates are not fully configured."
        ha_task_set_status "${HA_TASK_READY}"

        return 0

    fi


    ha_task_set_message "Automatic security updates are already configured."
    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}

ha_task_sys002_info() {

    ha_ui_info "$(ha_task_get_message)"

}

ha_task_sys002_execute() {

    ha_task_set_message "Installing unattended upgrades."


    if ! apt-get install -y unattended-upgrades; then

        ha_task_set_message "Unable to install unattended upgrades."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! dpkg-reconfigure -plow unattended-upgrades; then

        ha_task_set_message "Unable to configure unattended upgrades."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    ha_task_set_message "Automatic security updates configured successfully."
    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}


ha_task_sys002_verify() {

    local config_file="/etc/apt/apt.conf.d/20auto-upgrades"
    local unattended_file="/etc/apt/apt.conf.d/50unattended-upgrades"


    if [[ ! -f "${config_file}" ]]; then

        ha_task_set_message "20auto-upgrades configuration file is missing."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ ! -f "${unattended_file}" ]]; then

        ha_task_set_message "50unattended-upgrades configuration file is missing."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! grep -q 'APT::Periodic::Update-Package-Lists "1";' "${config_file}"; then

        ha_task_set_message "Package list updates are not enabled."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! grep -q 'APT::Periodic::Unattended-Upgrade "1";' "${config_file}"; then

        ha_task_set_message "Automatic security updates are not enabled."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    ha_task_set_message "Automatic security updates are configured."
    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}

ha_task_sys002_correction() {

    local config_file="/etc/apt/apt.conf.d/20auto-upgrades"

    ha_task_set_message "Correcting automatic security updates configuration."


    if [[ ! -f "${config_file}" ]]; then

        ha_task_set_message "Configuration file missing: ${config_file}"
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    sed -i 's/APT::Periodic::Update-Package-Lists "[01]";/APT::Periodic::Update-Package-Lists "1";/' "${config_file}"

    sed -i 's/APT::Periodic::Unattended-Upgrade "[01]";/APT::Periodic::Unattended-Upgrade "1";/' "${config_file}"


    ha_task_set_message "Automatic security updates configuration corrected."
    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}

ha_task_sys002_rollback() {

    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0

}




ha_task_sys002_register