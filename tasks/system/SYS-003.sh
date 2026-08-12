#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SYS-003
# ==============================================================================

ha_task_sys003_register() {

    ha_task_register \
    "SYS-003" \
    "Create administrative user" \
    "System" \
    "Create a non-root administrative user with sudo privileges." \
    "true" \
    "possible" \
    "true" \
    "ha_task_sys003_check" \
    "ha_task_sys003_info" \
    "ha_task_sys003_execute" \
    "ha_task_sys003_verify" \
    "ha_task_sys003_rollback"
}


ha_task_sys003_check() {

    local username

    while IFS= read -r username; do

        if [[ -n "${username}" ]] && [[ "${username}" != "root" ]]; then

            ha_task_set_message \
                "Administrative user ${username} is already configured."
            ha_task_set_status "${HA_TASK_COMPLETED}"

            return 0

        fi

    done < <(getent group sudo | cut -d: -f4 | tr ',' '\n')


    ha_task_set_message "No non-root sudo administrator is configured."
    ha_task_set_status "${HA_TASK_READY}"

    return 0
}


ha_task_sys003_info() {

    ha_ui_info "$(ha_task_get_message)"

}


ha_task_sys003_execute() {

    local username

    read -rp "Enter administrative username: " username

    if [[ -z "${username}" ]]; then

        ha_task_set_message "Username cannot be empty."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ ! "${username}" =~ ^[a-z_][a-z0-9_-]*$ ]]; then

        ha_task_set_message "Invalid username."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if id "${username}" >/dev/null 2>&1; then

        ha_task_set_message "User ${username} already exists."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! useradd \
        --create-home \
        --shell /bin/bash \
        "${username}"; then

        ha_task_set_message "Unable to create user ${username}."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! usermod -aG sudo "${username}"; then

        ha_task_set_message "Unable to grant sudo privileges to ${username}."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    echo

    if ! passwd "${username}"; then

        ha_task_set_message "Unable to set password for ${username}."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    ha_task_set_context "SYS-003" "username" "${username}"

    ha_task_set_message \
        "Administrative user ${username} created successfully."
    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}


ha_task_sys003_verify() {

    local username

    username="$(ha_task_get_context "SYS-003" "username")"


    if [[ -z "${username}" ]]; then

        ha_task_set_message \
            "Unable to verify administrative user: username context is missing."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! id "${username}" >/dev/null 2>&1; then

        ha_task_set_message "User ${username} does not exist."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! id -nG "${username}" | grep -qw "sudo"; then

        ha_task_set_message \
            "User ${username} is not a sudo administrator."
        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    ha_task_set_message \
        "Administrative user ${username} is correctly configured."
    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}


ha_task_sys003_rollback() {

    return 0
}


ha_task_sys003_register