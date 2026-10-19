#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SYS-003
# ==============================================================================
#
# Creates a non-root administrator and optionally installs an SSH public key.
# The SSH key matters: the SSH module will disable root and password logins,
# without a key the server would no longer be reachable.
# ------------------------------------------------------------------------------

readonly HA_SYS003_ADMIN_GROUPS=("sudo" "wheel" "admin")


ha_task_sys003_register() {

    ha_task_register \
    "SYS-003" \
    "Create administrative user" \
    "System" \
    "Create a non-root administrative user with sudo privileges and SSH key." \
    "true" \
    "false" \
    "true" \
    "ha_task_sys003_check" \
    "ha_task_sys003_info" \
    "ha_task_sys003_execute" \
    "ha_task_sys003_verify" \
    "ha_task_sys003_rollback"
}


# Prints the admin group of this distribution (sudo on Debian/Ubuntu).
ha_task_sys003_admin_group() {

    local group

    for group in "${HA_SYS003_ADMIN_GROUPS[@]}"; do

        if getent group "${group}" >/dev/null 2>&1; then
            printf "%s" "${group}"
            return 0
        fi

    done

    return 1
}


# Prints all non-root members (supplementary and primary) of a group.
ha_task_sys003_group_members() {

    local group="$1"
    local entry
    local gid
    local members

    entry="$(getent group "${group}" 2>/dev/null)" || return 0

    gid="$(cut -d: -f3 <<< "${entry}")"
    members="$(cut -d: -f4 <<< "${entry}")"

    {
        tr ',' '\n' <<< "${members}"
        getent passwd | awk -F: -v gid="${gid}" '$4 == gid { print $1 }'
    } | grep -vx -e '' -e 'root' | sort -u || true
}


ha_task_sys003_user_home() {

    getent passwd "$1" | cut -d: -f6
}


ha_task_sys003_has_ssh_key() {

    local home

    home="$(ha_task_sys003_user_home "$1")"

    [[ -n "${home}" && -s "${home}/.ssh/authorized_keys" ]]
}


ha_task_sys003_check() {

    local group
    local admins
    local user
    local without_key=()

    if ! group="$(ha_task_sys003_admin_group)"; then
        ha_task_result "${HA_TASK_BLOCKED}" \
            "No admin group (sudo/wheel) found. Is sudo installed?"
        return 0
    fi

    admins="$(ha_task_sys003_group_members "${group}")"

    if [[ -z "${admins}" ]]; then
        ha_task_result "${HA_TASK_READY}" \
            "No non-root administrator in group '${group}'."
        return 0
    fi

    while IFS= read -r user; do

        if ! ha_task_sys003_has_ssh_key "${user}"; then
            without_key+=("${user}")
        fi

    done <<< "${admins}"

    admins="$(paste -sd ' ' <<< "${admins}")"

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
    ha_ui_info "You will be asked for a username, a password and optionally"
    ha_ui_info "an SSH public key (e.g. the content of ~/.ssh/id_ed25519.pub)."
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

    home="$(ha_task_sys003_user_home "${username}")"
    group="$(id -gn "${username}")"

    if [[ -z "${home}" || ! -d "${home}" ]]; then
        return 1
    fi

    install -d -m 0700 -o "${username}" -g "${group}" -- "${home}/.ssh" \
        || return 1

    printf "%s\n" "${key}" >> "${home}/.ssh/authorized_keys" || return 1

    chown "${username}:${group}" -- "${home}/.ssh/authorized_keys" || return 1
    chmod 0600 -- "${home}/.ssh/authorized_keys" || return 1

    ha_log_change "SYS-003" "Installed SSH key for ${username}"
}


ha_task_sys003_execute() {

    local username
    local group
    local ssh_key

    if ! group="$(ha_task_sys003_admin_group)"; then
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
        ha_task_result "${HA_TASK_ERROR}" "User ${username} already exists."
        return 0
    fi

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

    else

        ha_ui_warning "No SSH key installed. Add one before hardening SSH."

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

    group="$(ha_task_sys003_admin_group)" || group="sudo"
    groups=" $(id -nG "${username}" 2>/dev/null) "

    if [[ "${groups}" != *" ${group} "* ]]; then
        ha_task_result "${HA_TASK_ERROR}" \
            "User ${username} is not a member of '${group}'."
        return 0
    fi

    if [[ "$(ha_task_get_context "SYS-003" "ssh_key")" == "true" ]] \
        && ! ha_task_sys003_has_ssh_key "${username}"; then
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

    if [[ "$(ha_task_get_context "SYS-003" "created")" != "true" \
        || -z "${username}" ]]; then
        ha_task_result "${HA_TASK_COMPLETED}" "Nothing to roll back."
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
