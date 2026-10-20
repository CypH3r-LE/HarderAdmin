#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SSH-001
# ==============================================================================
#
# Baseline sshd hardening (guide step 3, without port and password settings,
# which are separate tasks because they carry a higher lockout risk).
# ------------------------------------------------------------------------------

ha_task_ssh001_settings() {

    cat <<EOF
PermitRootLogin=no
PermitEmptyPasswords=no
PubkeyAuthentication=yes
MaxAuthTries=3,2
LoginGraceTime=20,15,10
ClientAliveInterval=300
ClientAliveCountMax=2,1,0
X11Forwarding=no
AllowAgentForwarding=no
AllowTcpForwarding=${SSH_TCP_FORWARDING:-no}
EOF
}


readonly HA_SSH001_BLOCKED="No administrator can log in via SSH (key or password). Disabling root login would lock you out. Run SYS-003 first."


ha_task_ssh001_register() {

    ha_task_register \
    "SSH-001" \
    "SSH baseline hardening" \
    "SSH" \
    "Disable root login and forwarding, limit authentication attempts and idle sessions." \
    "true" \
    "false" \
    "true" \
    "ha_task_ssh001_check" \
    "ha_task_ssh001_info" \
    "ha_task_ssh001_execute" \
    "ha_task_ssh001_verify" \
    "ha_ssh_rollback_reload"
}


ha_task_ssh001_check() {

    ha_ssh_settings_check ha_task_ssh001_settings any "${HA_SSH001_BLOCKED}"
}


ha_task_ssh001_info() {

    local admins

    admins="$(ha_ssh_usable_admins any | paste -sd ' ')"

    ha_ui_info "$(ha_task_get_message)"
    ha_ui_info "Writes $(ha_ssh_managed_file SSH-001):"
    ha_task_ssh001_settings | sed 's/=\([^,]*\).*/ \1/; s/^/      /'
    echo
    ha_ui_info "Administrators who can log in afterwards: ${admins}"

    if [[ "${SSH_TCP_FORWARDING:-no}" == "no" ]]; then
        ha_ui_warning "AllowTcpForwarding no breaks SSH tunnels and VS Code Remote-SSH."
        ha_ui_warning "Set SSH_TCP_FORWARDING=\"yes\" in the configuration if you need them."
    fi

    ha_ssh_warn_root_session
}


ha_task_ssh001_execute() {

    ha_ssh_settings_execute "SSH-001" ha_task_ssh001_settings any \
        "${HA_SSH001_BLOCKED}"
}


ha_task_ssh001_verify() {

    ha_ssh_settings_verify ha_task_ssh001_settings
}


ha_task_ssh001_register
