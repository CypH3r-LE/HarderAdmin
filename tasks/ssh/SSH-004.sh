#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SSH-004
# ==============================================================================
#
# Moves sshd to another port. This mainly reduces log noise from bots; it is
# not a replacement for key-only authentication (SSH-002) and Fail2Ban.
#
# Order of operations (each step is rolled back on failure):
#   1. Port must be free and must not be set in other sshd config files
#      (Port accumulates over all files).
#   2. UFW active -> "ufw limit <port>/tcp" BEFORE sshd moves.
#   3. Port written to the managed drop-in, "sshd -t".
#   4. Guard armed, sshd moved (socket activation aware), port must listen.
#   5. Admin confirms a login on the new port.
# ------------------------------------------------------------------------------

readonly HA_SSH004_DEFAULT_PORT=2202


ha_task_ssh004_register() {

    ha_task_register \
    "SSH-004" \
    "Change SSH port" \
    "SSH" \
    "Move sshd from port 22 to another port (firewall rule included)." \
    "true" \
    "false" \
    "true" \
    "ha_task_ssh004_check" \
    "ha_task_ssh004_info" \
    "ha_task_ssh004_execute" \
    "ha_task_ssh004_verify" \
    "ha_task_ssh004_rollback"
}


ha_task_ssh004_check() {

    local ports

    ha_ssh_require || return 0

    ports="$(ha_ssh_values port)"

    if [[ " ${ports} " == *" 22 "* ]]; then
        ha_task_result "${HA_TASK_READY}" "sshd listens on the default port 22."
        return 0
    fi

    ha_task_result "${HA_TASK_COMPLETED}" "sshd port: ${ports}"
}


ha_task_ssh004_info() {

    ha_ui_info "$(ha_task_get_message)"
    ha_ui_info "Changing the port reduces bot noise in the logs; it is no real"
    ha_ui_info "protection on its own. Key-only login (SSH-002) matters more."

    if ha_ufw_active; then
        ha_ui_info "UFW is active: a rate-limited rule for the new port is added first."
    else
        ha_ui_info "UFW is not active: no local firewall rule needed."
    fi

    ha_ui_warning "Open the new port in any EXTERNAL firewall first"
    ha_ui_warning "(cloud security group, hoster firewall, router)."

    if ha_check_systemd && ha_ssh_socket_mode; then
        ha_ui_info "sshd uses socket activation (ssh.socket); the socket is moved as well."
    fi
}


ha_task_ssh004_read_port() {

    local -n _ha_ssh004_port="$1"
    local input

    if ! ha_ui_read input "New SSH port [${HA_SSH004_DEFAULT_PORT}]: "; then
        return 1
    fi

    input="${input:-${HA_SSH004_DEFAULT_PORT}}"

    if [[ ! "${input}" =~ ^[0-9]{1,5}$ ]] \
        || (( 10#${input} < 1024 || 10#${input} > 65535 )); then
        ha_ui_error "Port must be a number between 1024 and 65535."
        return 1
    fi

    _ha_ssh004_port=$(( 10#${input} ))
}


ha_task_ssh004_activate() {

    local port

    port="$(ha_task_get_context "SSH-004" "port")"

    if ! ha_ssh_activate_port "SSH-004" apply; then
        ha_task_result "${HA_TASK_ERROR}" "Unable to restart sshd on the new port."
        return 0
    fi

    if ! ha_wait_for 10 ha_port_listening "${port}"; then
        ha_task_result "${HA_TASK_ERROR}" "sshd does not listen on port ${port}."
        return 0
    fi

    ha_log_change "SSH-004" "sshd moved to port ${port}"
    ha_task_result "${HA_TASK_COMPLETED}" "sshd listens on port ${port}."
}


ha_task_ssh004_execute() {

    local port=""
    local others
    local current_ports

    ha_ssh_require || return 0

    current_ports="$(ha_ssh_values port)"

    if ! ha_task_ssh004_read_port port; then
        ha_task_result "${HA_TASK_ERROR}" "No valid port entered."
        return 0
    fi

    if [[ " ${current_ports} " == *" ${port} "* ]]; then
        ha_task_result "${HA_TASK_COMPLETED}" "sshd already uses port ${port}."
        return 0
    fi

    if ha_port_listening "${port}"; then
        ha_task_result "${HA_TASK_ERROR}" "Port ${port} is already in use."
        return 0
    fi

    others="$(ha_ssh_files_setting Port)"

    if [[ -n "${others}" ]]; then
        ha_task_result "${HA_TASK_BLOCKED}" \
            "Port is also set in: ${others}- sshd would listen on both. Remove it there first."
        return 0
    fi

    ha_task_set_context "SSH-004" "port" "${port}"
    ha_task_set_context "SSH-004" "previous_ports" "${current_ports}"

    if ! ha_ssh_plan_port_activation "SSH-004"; then
        ha_task_result "${HA_TASK_ERROR}" "Unable to determine the sshd service."
        return 0
    fi

    # Firewall first, so the new port is reachable the moment sshd moves.
    if ha_ufw_active; then

        if ! ufw limit "${port}/tcp" comment "SSH (HarderAdmin)" >/dev/null; then
            ha_task_result "${HA_TASK_ERROR}" "Unable to add the UFW rule for port ${port}."
            return 0
        fi

        ha_task_set_context "SSH-004" "ufw_port" "${port}"
        ha_log_change "SSH-004" "ufw limit ${port}/tcp"

    fi

    if ! ha_ssh_managed_set Port "${port}"; then
        ha_backup_restore_session || true
        ha_task_ssh004_remove_ufw_rule
        ha_task_result "${HA_TASK_ERROR}" "Unable to write $(ha_ssh_managed_file SSH-004)."
        return 0
    fi

    if ! ha_ssh_test_config; then
        ha_backup_restore_session || true
        ha_task_ssh004_remove_ufw_rule
        ha_task_result "${HA_TASK_ERROR}" \
            "New sshd configuration is invalid (${HA_SSH_ERROR}). Nothing activated."
        return 0
    fi

    ha_guard_run "SSH-004" ha_task_ssh004_activate "$(ha_ssh_test_hint "${port}")"

    if [[ "${HA_TASK_STATUS}" != "${HA_TASK_COMPLETED}" ]]; then
        # Aborted before activation: the guard restored only the files.
        ha_task_ssh004_remove_ufw_rule
    else
        ha_task_result "${HA_TASK_COMPLETED}" "sshd moved to port ${port}."

        if ha_ufw_active; then
            ha_ui_info "The firewall rule for port 22 still exists. Remove it once"
            ha_ui_info "everything works (Firewall module or: ufw status numbered)."
        fi
    fi
}


ha_task_ssh004_verify() {

    local port
    local ports

    port="$(ha_task_get_context "SSH-004" "port")"

    if ! ha_ssh_load_effective; then
        ha_task_result "${HA_TASK_ERROR}" \
            "sshd configuration is invalid: ${HA_SSH_ERROR}"
        return 0
    fi

    ports="$(ha_ssh_values port)"

    if [[ "${ports}" != "${port}" ]]; then
        ha_task_result "${HA_TASK_ERROR}" "Effective sshd ports: ${ports} (expected ${port})."
        return 0
    fi

    if ! ha_port_listening "${port}"; then
        ha_task_result "${HA_TASK_ERROR}" "Nothing listens on port ${port}."
        return 0
    fi

    ha_task_result "${HA_TASK_COMPLETED}" "sshd listens on port ${port} only."
}


ha_task_ssh004_remove_ufw_rule() {

    local ufw_port

    ufw_port="$(ha_task_get_context "SSH-004" "ufw_port")"

    if [[ -n "${ufw_port}" ]] && ha_command_exists ufw; then
        ufw delete limit "${ufw_port}/tcp" >/dev/null 2>&1 || true
        ha_log_change "SSH-004" "Rollback: ufw delete limit ${ufw_port}/tcp"
        ha_task_set_context "SSH-004" "ufw_port" ""
    fi
}


# Runs after the runner restored the drop-in file (or from the guard timer).
ha_task_ssh004_rollback() {

    local failed=false

    if [[ -n "$(ha_task_get_context "SSH-004" "activation")" ]]; then
        ha_ssh_activate_port "SSH-004" revert || failed=true
    else
        ha_ssh_reload || failed=true
    fi

    ha_task_ssh004_remove_ufw_rule

    if [[ "${failed}" == true ]]; then
        ha_task_result "${HA_TASK_ERROR}" \
            "Files restored, but sshd could not be restarted on the old port."
        return 0
    fi

    ha_log_change "SSH-004" "Rollback: sshd back on port(s) $(ha_task_get_context "SSH-004" "previous_ports")"
    ha_task_result "${HA_TASK_COMPLETED}" \
        "sshd is back on port(s) $(ha_task_get_context "SSH-004" "previous_ports")."
}


ha_task_ssh004_register
