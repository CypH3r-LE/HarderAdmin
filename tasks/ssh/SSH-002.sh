#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SSH-002
# ==============================================================================
#
# Key-only authentication. Blocked until an administrator has an SSH key
# (SYS-003) and is allowed to log in (AllowUsers/DenyUsers/...).
# ------------------------------------------------------------------------------

ha_task_ssh002_settings() {

    cat <<'EOF'
PasswordAuthentication=no
KbdInteractiveAuthentication=no
PubkeyAuthentication=yes
EOF
}


readonly HA_SSH002_BLOCKED="No administrator with an SSH key may log in via SSH. Add a key with SYS-003 first."


ha_task_ssh002_register() {

    ha_task_register \
    "SSH-002" \
    "SSH key-only authentication" \
    "SSH" \
    "Disable password and keyboard-interactive logins; only SSH keys are accepted." \
    "true" \
    "false" \
    "true" \
    "ha_task_ssh002_check" \
    "ha_task_ssh002_info" \
    "ha_task_ssh002_execute" \
    "ha_task_ssh002_verify" \
    "ha_ssh_rollback_reload"
}


ha_task_ssh002_check() {

    ha_ssh_settings_check ha_task_ssh002_settings key "${HA_SSH002_BLOCKED}"
}


ha_task_ssh002_info() {

    local admins
    local me

    admins="$(ha_ssh_usable_admins key | paste -sd ' ')"
    me="$(ha_invoking_user)"

    ha_ui_info "$(ha_task_get_message)"
    ha_ui_info "Writes PasswordAuthentication no, KbdInteractiveAuthentication no"
    ha_ui_info "to $(ha_ssh_managed_file SSH-002) (wins over 50-cloud-init.conf)."
    ha_ui_info "Administrators with SSH key who can log in afterwards: ${admins}"

    if [[ -n "${me}" && " ${admins} " != *" ${me} "* ]]; then
        ha_ui_warning "You (${me}) have no usable SSH key and could not log in"
        ha_ui_warning "with your password anymore."
    fi

    ha_ui_warning "Test the key login of one of these users BEFORE you continue:"
    ha_ui_warning "  ssh -o PreferredAuthentications=publickey <user>@<server>"

    ha_ssh_warn_root_session
}


ha_task_ssh002_execute() {

    ha_ssh_settings_execute "SSH-002" ha_task_ssh002_settings key \
        "${HA_SSH002_BLOCKED}"
}


ha_task_ssh002_verify() {

    ha_ssh_settings_verify ha_task_ssh002_settings
}


ha_task_ssh002_register
