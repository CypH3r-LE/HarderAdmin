#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SSH-003
# ==============================================================================
#
# Restricts SSH logins to a list of users (AllowUsers).
#
# Note: AllowUsers accumulates over all sshd config files. If another file
# also sets AllowUsers, the effective list is the union of both.
# ------------------------------------------------------------------------------

ha_task_ssh003_register() {

    ha_task_register \
    "SSH-003" \
    "Restrict SSH users (AllowUsers)" \
    "SSH" \
    "Allow SSH logins only for selected users." \
    "true" \
    "false" \
    "true" \
    "ha_task_ssh003_check" \
    "ha_task_ssh003_info" \
    "ha_task_ssh003_execute" \
    "ha_task_ssh003_verify" \
    "ha_ssh_rollback_reload"
}


ha_task_ssh003_check() {

    local allow_users
    local allow_groups

    ha_ssh_require || return 0

    allow_users="$(ha_ssh_values allowusers)"
    allow_groups="$(ha_ssh_values allowgroups)"

    if [[ -n "${allow_users}" || -n "${allow_groups}" ]]; then
        ha_task_result "${HA_TASK_COMPLETED}" \
            "SSH login restricted to${allow_users:+ users: ${allow_users}}${allow_groups:+ groups: ${allow_groups}}"
        return 0
    fi

    if [[ -z "$(ha_ssh_usable_admins any)" ]]; then
        ha_task_result "${HA_TASK_BLOCKED}" \
            "No administrator can log in via SSH. Run SYS-003 first."
        return 0
    fi

    ha_task_result "${HA_TASK_READY}" "Every account may log in via SSH."
}


# Default list: administrators who can log in, plus the invoking admin.
ha_task_ssh003_default_users() {

    {
        ha_ssh_usable_admins any
        ha_invoking_user
        printf "\n"
    } | grep . | sort -u | paste -sd ' ' || true
}


ha_task_ssh003_info() {

    ha_ui_info "$(ha_task_get_message)"
    ha_ui_info "Suggested users: $(ha_task_ssh003_default_users)"
    ha_ui_info "Service accounts that log in via SSH (backup, deploy, git) must be"
    ha_ui_info "added to the list as well, otherwise they are rejected."
}


ha_task_ssh003_execute() {

    local default_users
    local input
    local users=()
    local user
    local me
    local others

    ha_ssh_require || return 0

    default_users="$(ha_task_ssh003_default_users)"

    if ! ha_ui_read input "Users allowed to log in via SSH [${default_users}]: "; then
        ha_task_result "${HA_TASK_ERROR}" "No input."
        return 0
    fi

    input="${input:-${default_users}}"

    for user in ${input//,/ }; do

        if [[ ! "${user}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
            ha_task_result "${HA_TASK_ERROR}" "Invalid username: ${user}"
            return 0
        fi

        if ! getent passwd "${user}" >/dev/null 2>&1; then
            ha_task_result "${HA_TASK_ERROR}" "User does not exist: ${user}"
            return 0
        fi

        if [[ "${user}" == "root" ]]; then
            ha_ui_warning "root is in the list. SSH-001 disables root login anyway."
        fi

        users+=("${user}")

    done

    if (( ${#users[@]} == 0 )); then
        ha_task_result "${HA_TASK_ERROR}" "The list is empty."
        return 0
    fi

    if [[ -z "$(ha_ssh_usable_admins any "${users[*]}")" ]]; then
        ha_task_result "${HA_TASK_ERROR}" \
            "The list contains no administrator who can log in. Nothing changed."
        return 0
    fi

    me="$(ha_invoking_user)"

    if [[ -n "${me}" && " ${users[*]} " != *" ${me} "* ]] \
        && ! ha_ui_confirm "You (${me}) are not in the list. Continue"; then
        ha_task_result "${HA_TASK_ERROR}" "Aborted."
        return 0
    fi

    others="$(ha_ssh_files_setting AllowUsers)"

    if [[ -n "${others}" ]]; then
        ha_ui_warning "AllowUsers is also set in: ${others}"
        ha_ui_warning "Those users stay allowed (AllowUsers accumulates)."
    fi

    ha_task_set_context "SSH-003" "users" "${users[*]}"

    if ! ha_ssh_managed_set AllowUsers "${users[*]}"; then
        ha_backup_restore_session || true
        ha_task_result "${HA_TASK_ERROR}" "Unable to write $(ha_ssh_managed_file SSH-003)."
        return 0
    fi

    ha_ssh_validate_or_restore || return 0

    ha_guard_run "SSH-003" ha_ssh_activate_reload "$(ha_ssh_test_hint "")"
}


ha_task_ssh003_verify() {

    local expected
    local effective
    local user

    expected="$(ha_task_get_context "SSH-003" "users")"

    if ! ha_ssh_load_effective; then
        ha_task_result "${HA_TASK_ERROR}" \
            "sshd configuration is invalid: ${HA_SSH_ERROR}"
        return 0
    fi

    effective=" $(ha_ssh_values allowusers) "

    for user in ${expected}; do

        if [[ "${effective}" != *" ${user} "* ]]; then
            ha_task_result "${HA_TASK_ERROR}" "${user} is not in the effective AllowUsers."
            return 0
        fi

    done

    ha_task_result "${HA_TASK_COMPLETED}" "SSH login restricted to:${effective% }"
}


ha_task_ssh003_register
