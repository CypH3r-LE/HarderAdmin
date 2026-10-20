#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SYS-003
# ==============================================================================
#
# Creates a non-root administrator, or adds an SSH public key to an existing
# one. The SSH key matters: SSH-002 disables password logins and is blocked
# until at least one administrator has a key.
# ------------------------------------------------------------------------------

ha_task_sys003_register() {

    ha_task_register \
    "SYS-003" \
    "Administrative user and SSH key" \
    "System" \
    "Create a non-root sudo administrator or add an SSH key to an existing one." \
    "true" \
    "false" \
    "true" \
    "ha_task_sys003_check" \
    "ha_task_sys003_info" \
    "ha_task_sys003_execute" \
    "ha_task_sys003_verify" \
    "ha_task_sys003_rollback"
}


ha_task_sys003_check() {

    local group
    local admins
    local user
    local without_key=()

    if ! group="$(ha_admin_group)"; then
        ha_task_result "${HA_TASK_BLOCKED}" \
            "No admin group (sudo/wheel) found. Is sudo installed?"
        return 0
    fi

    admins="$(ha_group_members "${group}")"

    if [[ -z "${admins}" ]]; then
        ha_task_result "${HA_TASK_READY}" \
            "No non-root administrator in group '${group}'."
        return 0
    fi

    while IFS= read -r user; do

        if ! ha_user_has_ssh_key "${user}"; then
            without_key+=("${user}")
        fi

    done <<< "${admins}"

    admins="$(paste -sd ' ' <<< "${admins}")"

    if [[ "$(ha_admin_users_with_key | head -n 1)" == "" ]]; then
        ha_task_result "${HA_TASK_READY}" \
            "Administrator(s) ${admins} without SSH key (needed before SSH-002)."
        return 0
    fi

    if (( ${#without_key[@]} > 0 )); then
        ha_task_result "${HA_TASK_COMPLETED}" \
            "Administrator(s): ${admins} (without SSH key: ${without_key[*]})"
        return 0
    fi

    ha_task_result "${HA_TASK_COMPLETED}" \
        "Administrator(s) with SSH key: ${admins}"
}


ha_task_sys003_info() {

    ha_ui_info "$(ha_task_get_message)"
    ha_ui_info "New user     : you set a password, the SSH key is optional."
    ha_ui_info "Existing admin: an SSH key is added to ~/.ssh/authorized_keys."
    ha_ui_info "Paste the PUBLIC key from your workstation, e.g. ~/.ssh/id_ed25519.pub"
    ha_ui_info "(create one with: ssh-keygen -t ed25519)."
}


ha_task_sys003_valid_ssh_key() {

    local key="$1"
    local type
    local blob
    local embedded

    [[ "${key}" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com)[[:space:]]+([A-Za-z0-9+/]+={0,3})([[:space:]].*)?$ ]] \
        || return 1

    type="${BASH_REMATCH[1]}"
    blob="${BASH_REMATCH[3]}"

    # Let ssh-keygen do the full validation if available.
    if ha_command_exists ssh-keygen; then
        ssh-keygen -l -f - <<< "${key}" >/dev/null 2>&1
        return
    fi

    # Fallback: the base64 blob must start with <uint32 length><key type>.
    embedded="$(base64 -d <<< "${blob}" 2>/dev/null \
        | head -c $(( 4 + ${#type} )) | tail -c "${#type}")" || true

    [[ "${embedded}" == "${type}" ]]
}


ha_task_sys003_install_ssh_key() {

    local username="$1"
    local key="$2"
    local home
    local group

    home="$(ha_user_home "${username}")"
    group="$(id -gn "${username}")"

    if [[ -z "${home}" || ! -d "${home}" ]]; then
        return 1
    fi

    # Root writes into a directory the user controls: never follow symlinks.
    if [[ -L "${home}/.ssh" || -L "${home}/.ssh/authorized_keys" ]]; then
        ha_log_error "Refusing symlinked ~/.ssh or authorized_keys of ${username}."
        return 1
    fi

    install -d -m 0700 -o "${username}" -g "${group}" -- "${home}/.ssh" \
        || return 1

    ha_backup_file "${home}/.ssh/authorized_keys" || return 1

    if [[ -f "${home}/.ssh/authorized_keys" ]] \
        && grep -qxF -- "${key}" "${home}/.ssh/authorized_keys"; then
        return 0
    fi

    printf "%s\n" "${key}" >> "${home}/.ssh/authorized_keys" || return 1

    chown "${username}:${group}" -- "${home}/.ssh/authorized_keys" || return 1
    chmod 0600 -- "${home}/.ssh/authorized_keys" || return 1

    ha_log_change "SYS-003" "Installed SSH key for ${username}"
}


ha_task_sys003_execute() {

    local username
    local group
    local ssh_key
    local existing=false

    if ! group="$(ha_admin_group)"; then
        ha_task_result "${HA_TASK_ERROR}" "No admin group (sudo/wheel) found."
        return 0
    fi

    if ! ha_ui_read username "Enter administrative username: "; then
        ha_task_result "${HA_TASK_ERROR}" "No username entered."
        return 0
    fi

    if [[ ! "${username}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        ha_task_result "${HA_TASK_ERROR}" \
            "Invalid username (lowercase letters, digits, _ and -, max. 32)."
        return 0
    fi

    if getent passwd "${username}" >/dev/null 2>&1; then

        if [[ " $(id -nG -- "${username}" 2>/dev/null) " != *" ${group} "* ]]; then
            ha_task_result "${HA_TASK_ERROR}" \
                "User ${username} exists but is not in group '${group}'."
            return 0
        fi

        ha_ui_info "${username} is an existing administrator: adding an SSH key."
        existing=true

        ha_task_set_context "SYS-003" "username" "${username}"
        ha_task_set_context "SYS-003" "created" "false"

    else

        if ! useradd --create-home --shell /bin/bash \
            --groups "${group}" -- "${username}"; then
            ha_task_result "${HA_TASK_ERROR}" "Unable to create user ${username}."
            return 0
        fi

        # From here on, a failure can be rolled back by deleting the user.
        ha_task_set_context "SYS-003" "username" "${username}"
        ha_task_set_context "SYS-003" "created" "true"
        ha_log_change "SYS-003" "Created user ${username} (group ${group})"

        echo

        if ! passwd -- "${username}"; then
            ha_task_result "${HA_TASK_ERROR}" \
                "Unable to set password for ${username}."
            return 0
        fi

    fi

    echo

    if ! ha_ui_read ssh_key "SSH public key (leave empty to skip): "; then
        ssh_key=""
    fi

    if [[ -n "${ssh_key}" ]]; then

        if ! ha_task_sys003_valid_ssh_key "${ssh_key}"; then
            ha_task_result "${HA_TASK_ERROR}" "Invalid SSH public key."
            return 0
        fi

        if ! ha_task_sys003_install_ssh_key "${username}" "${ssh_key}"; then
            ha_task_result "${HA_TASK_ERROR}" \
                "Unable to install SSH key for ${username}."
            return 0
        fi

        ha_task_set_context "SYS-003" "ssh_key" "true"

    elif [[ "${existing}" == true ]]; then

        ha_task_result "${HA_TASK_ERROR}" "No SSH key entered."
        return 0

    else

        ha_ui_warning "No SSH key installed. Add one before hardening SSH."

    fi

    if [[ "${existing}" == true ]]; then
        ha_task_result "${HA_TASK_COMPLETED}" "SSH key added for ${username}."
        return 0
    fi

    ha_task_result "${HA_TASK_COMPLETED}" \
        "Administrative user ${username} created successfully."
}


ha_task_sys003_verify() {

    local username
    local group
    local groups

    username="$(ha_task_get_context "SYS-003" "username")"

    if [[ -z "${username}" ]]; then
        ha_task_result "${HA_TASK_ERROR}" \
            "Unable to verify administrative user: username context is missing."
        return 0
    fi

    if ! getent passwd "${username}" >/dev/null 2>&1; then
        ha_task_result "${HA_TASK_ERROR}" "User ${username} does not exist."
        return 0
    fi

    group="$(ha_admin_group)" || group="sudo"
    groups=" $(id -nG "${username}" 2>/dev/null) "

    if [[ "${groups}" != *" ${group} "* ]]; then
        ha_task_result "${HA_TASK_ERROR}" \
            "User ${username} is not a member of '${group}'."
        return 0
    fi

    if [[ "$(ha_task_get_context "SYS-003" "ssh_key")" == "true" ]] \
        && ! ha_user_has_ssh_key "${username}"; then
        ha_task_result "${HA_TASK_ERROR}" \
            "SSH key for ${username} is missing."
        return 0
    fi

    ha_task_result "${HA_TASK_COMPLETED}" \
        "Administrative user ${username} is correctly configured."
}


# Removes the user created in this run (only if this run created it).
ha_task_sys003_rollback() {

    local username

    username="$(ha_task_get_context "SYS-003" "username")"

    # An added key was already removed by restoring authorized_keys.
    if [[ "$(ha_task_get_context "SYS-003" "created")" != "true" \
        || -z "${username}" ]]; then
        ha_task_result "${HA_TASK_COMPLETED}" "No user to remove."
        return 0
    fi

    if ! userdel --remove -- "${username}" 2>/dev/null; then
        ha_task_result "${HA_TASK_ERROR}" "Unable to remove user ${username}."
        return 0
    fi

    ha_task_set_context "SYS-003" "created" "false"
    ha_log_change "SYS-003" "Rollback: removed user ${username}"

    ha_task_result "${HA_TASK_COMPLETED}" "User ${username} removed."
}


ha_task_sys003_register
