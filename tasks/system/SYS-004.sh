#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SYS-004
# ==============================================================================


ha_task_sys004_register() {

    ha_task_register \
    "SYS-004" \
    "Kernel hardening" \
    "System" \
    "Apply kernel and network security hardening using sysctl." \
    "false" \
    "possible" \
    "true" \
    "ha_task_sys004_check" \
    "ha_task_sys004_info" \
    "ha_task_sys004_execute" \
    "ha_task_sys004_verify" \
    "ha_task_sys004_rollback" \
    "ha_task_sys004_correction"
}


ha_task_sys004_check() {

    local config_file="/etc/sysctl.d/99-hardening.conf"


    if [[ ! -f "${config_file}" ]]; then

        ha_task_set_message "Kernel hardening is not configured."
        ha_task_set_status "${HA_TASK_READY}"

        return 0

    fi


    if ! grep -q '^net.ipv4.conf.default.rp_filter = 1$' \
        "${config_file}" \
        || ! grep -q '^net.ipv4.conf.all.rp_filter = 1$' \
        "${config_file}" \
        || ! grep -q '^net.ipv4.conf.all.accept_source_route = 0$' \
        "${config_file}" \
        || ! grep -q '^net.ipv6.conf.all.accept_source_route = 0$' \
        "${config_file}" \
        || ! grep -q '^net.ipv4.conf.all.send_redirects = 0$' \
        "${config_file}" \
        || ! grep -q '^net.ipv4.conf.default.send_redirects = 0$' \
        "${config_file}" \
        || ! grep -q '^net.ipv4.conf.all.accept_redirects = 0$' \
        "${config_file}" \
        || ! grep -q '^net.ipv6.conf.all.accept_redirects = 0$' \
        "${config_file}" \
        || ! grep -q '^net.ipv4.icmp_echo_ignore_broadcasts = 1$' \
        "${config_file}" \
        || ! grep -q '^net.ipv4.tcp_syncookies = 1$' \
        "${config_file}" \
        || ! grep -q '^net.ipv4.tcp_max_syn_backlog = 2048$' \
        "${config_file}" \
        || ! grep -q '^net.ipv4.tcp_synack_retries = 2$' \
        "${config_file}" \
        || ! grep -q '^net.ipv4.tcp_syn_retries = 5$' \
        "${config_file}" \
        || ! grep -q '^net.ipv4.conf.all.log_martians = 1$' \
        "${config_file}" \
        || ! grep -q '^kernel.randomize_va_space = 2$' \
        "${config_file}" \
        || ! grep -q '^kernel.kptr_restrict = 2$' \
        "${config_file}" \
        || ! grep -q '^kernel.dmesg_restrict = 1$' \
        "${config_file}" \
        || ! grep -q '^kernel.yama.ptrace_scope = 1$' \
        "${config_file}" \
        || ! grep -q '^fs.protected_hardlinks = 1$' \
        "${config_file}" \
        || ! grep -q '^fs.protected_symlinks = 1$' \
        "${config_file}" \
        || ! grep -q '^fs.suid_dumpable = 0$' \
        "${config_file}"; then

        ha_task_set_message "Kernel hardening is not fully configured."
        ha_task_set_status "${HA_TASK_READY}"

        return 0

    fi


    # Verify the currently active kernel values as well.
    ha_task_sys004_verify

    if [[ "${HA_TASK_STATUS}" != "${HA_TASK_COMPLETED}" ]]; then

        ha_task_set_message "Kernel hardening is not fully configured."
        ha_task_set_status "${HA_TASK_READY}"

        return 0

    fi


    ha_task_set_message "Kernel hardening is already configured."
    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}


ha_task_sys004_info() {

    ha_ui_info "$(ha_task_get_message)"

}


ha_task_sys004_execute() {

    local config_file="/etc/sysctl.d/99-hardening.conf"


    if ! cat > "${config_file}" <<'EOF'
# ==============================================================================
# HarderAdmin
# Kernel and network hardening
# ==============================================================================

# IP spoofing and routing protections
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# ICMP and SYN flood protection
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.conf.all.log_martians = 1

# Kernel and process hardening
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.suid_dumpable = 0
EOF
    then

        ha_task_set_message \
            "Unable to create kernel hardening configuration."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! sysctl --system >/dev/null; then

        ha_task_set_message \
            "Unable to apply kernel hardening configuration."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    ha_task_set_message "Kernel hardening configured successfully."
    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}


ha_task_sys004_verify() {

    if [[ "$(sysctl -n net.ipv4.conf.default.rp_filter)" != "1" ]]; then

        ha_task_set_message \
            "Default reverse path filtering is not configured correctly."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv4.conf.all.rp_filter)" != "1" ]]; then

        ha_task_set_message \
            "Global reverse path filtering is not configured correctly."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv4.conf.all.accept_source_route)" != "0" ]]; then

        ha_task_set_message \
            "IPv4 source routing is not disabled."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv6.conf.all.accept_source_route)" != "0" ]]; then

        ha_task_set_message \
            "IPv6 source routing is not disabled."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv4.conf.all.send_redirects)" != "0" ]]; then

        ha_task_set_message \
            "IPv4 send redirects are not disabled."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv4.conf.default.send_redirects)" != "0" ]]; then

        ha_task_set_message \
            "Default IPv4 send redirects are not disabled."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv4.conf.all.accept_redirects)" != "0" ]]; then

        ha_task_set_message \
            "IPv4 accept redirects are not disabled."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv6.conf.all.accept_redirects)" != "0" ]]; then

        ha_task_set_message \
            "IPv6 accept redirects are not disabled."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv4.icmp_echo_ignore_broadcasts)" != "1" ]]; then

        ha_task_set_message \
            "ICMP broadcast echo protection is not configured correctly."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv4.tcp_syncookies)" != "1" ]]; then

        ha_task_set_message \
            "TCP SYN cookies are not enabled."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv4.tcp_max_syn_backlog)" != "2048" ]]; then

        ha_task_set_message \
            "TCP SYN backlog is not configured correctly."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv4.tcp_synack_retries)" != "2" ]]; then

        ha_task_set_message \
            "TCP SYN-ACK retries are not configured correctly."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv4.tcp_syn_retries)" != "5" ]]; then

        ha_task_set_message \
            "TCP SYN retries are not configured correctly."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n net.ipv4.conf.all.log_martians)" != "1" ]]; then

        ha_task_set_message \
            "Martian packet logging is not enabled."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n kernel.randomize_va_space)" != "2" ]]; then

        ha_task_set_message \
            "ASLR is not configured correctly."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n kernel.kptr_restrict)" != "2" ]]; then

        ha_task_set_message \
            "Kernel pointer restriction is not configured correctly."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n kernel.dmesg_restrict)" != "1" ]]; then

        ha_task_set_message \
            "dmesg restriction is not configured correctly."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n kernel.yama.ptrace_scope)" != "1" ]]; then

        ha_task_set_message \
            "ptrace restriction is not configured correctly."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n fs.protected_hardlinks)" != "1" ]]; then

        ha_task_set_message \
            "Protected hardlinks are not configured correctly."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n fs.protected_symlinks)" != "1" ]]; then

        ha_task_set_message \
            "Protected symlinks are not configured correctly."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if [[ "$(sysctl -n fs.suid_dumpable)" != "0" ]]; then

        ha_task_set_message \
            "SUID core dumps are not disabled."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    ha_task_set_message "Kernel hardening is correctly configured."
    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}


ha_task_sys004_correction() {

    local config_file="/etc/sysctl.d/99-hardening.conf"


    ha_task_set_message "Correcting kernel hardening configuration."


    if ! cat > "${config_file}" <<'EOF'
# ==============================================================================
# HarderAdmin
# Kernel and network hardening
# ==============================================================================

# IP spoofing and routing protections
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# ICMP and SYN flood protection
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.conf.all.log_martians = 1

# Kernel and process hardening
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.suid_dumpable = 0
EOF
    then

        ha_task_set_message \
            "Unable to correct kernel hardening configuration."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! sysctl --system >/dev/null; then

        ha_task_set_message \
            "Unable to apply corrected kernel hardening configuration."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    ha_task_set_message \
        "Kernel hardening configuration corrected."

    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}


ha_task_sys004_rollback() {

    return 0
}


ha_task_sys004_register