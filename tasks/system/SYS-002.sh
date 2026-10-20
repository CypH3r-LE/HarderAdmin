#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SYS-002
# ==============================================================================
#
# Checks the EFFECTIVE APT configuration (apt-config), so overrides in other
# files of /etc/apt/apt.conf.d are detected as well. No debconf dialog is used:
# 20auto-upgrades is written directly.
# ------------------------------------------------------------------------------

readonly HA_SYS002_PERIODIC_FILE="/etc/apt/apt.conf.d/20auto-upgrades"
readonly HA_SYS002_UNATTENDED_FILE="/etc/apt/apt.conf.d/50unattended-upgrades"
readonly HA_SYS002_TIMERS=("apt-daily.timer" "apt-daily-upgrade.timer")


ha_task_sys002_register() {

    ha_task_register \
    "SYS-002" \
    "Automatic security updates" \
    "System" \
    "Configure automatic security updates (unattended-upgrades)." \
    "false" \
    "possible" \
    "true" \
    "ha_task_sys002_check" \
    "ha_task_sys002_info" \
    "ha_task_sys002_execute" \
    "ha_task_sys002_verify" \
    "" \
    "ha_task_sys002_correction"
}


# Prints the effective value of an APT configuration option.
ha_task_sys002_apt_value() {

    local key="$1"
    local output

    output="$(apt-config shell HA_VALUE "${key}" 2>/dev/null)" || return 1

    # Output format: HA_VALUE='1'
    output="${output#HA_VALUE=\'}"
    printf "%s" "${output%\'}"
}


# Files (other than ours) that set a periodic option.
ha_task_sys002_find_overrides() {

    local key="$1"

    grep -l -s -- "${key}" /etc/apt/apt.conf.d/* 2>/dev/null \
        | grep -vxF -- "${HA_SYS002_PERIODIC_FILE}" \
        | paste -sd ' ' || true
}


# Evaluates the state. Returns 0 if compliant, otherwise 1 with a message.
ha_task_sys002_evaluate() {

    local key
    local value
    local timer

    if ! ha_package_installed unattended-upgrades; then
        ha_task_set_message "unattended-upgrades is not installed."
        return 1
    fi

    for key in \
        "APT::Periodic::Update-Package-Lists" \
        "APT::Periodic::Unattended-Upgrade"
    do

        value="$(ha_task_sys002_apt_value "${key}")" || value=""

        if [[ -z "${value}" || "${value}" == "0" ]]; then

            local overrides
            overrides="$(ha_task_sys002_find_overrides "${key}")"

            ha_task_set_message \
                "${key} is not enabled (effective value: '${value}')${overrides:+; also set in: ${overrides}}"
            return 1
        fi

    done

    if [[ ! -f "${HA_SYS002_UNATTENDED_FILE}" ]]; then
        ha_task_set_message "${HA_SYS002_UNATTENDED_FILE} is missing."
        return 1
    fi

    # An active (not commented) origin line for security updates, e.g.
    # Ubuntu: "${distro_id}:${distro_codename}-security";
    # Debian: "origin=Debian,codename=${distro_codename},label=Debian-Security";
    if ! grep -Eq '^[[:space:]]*"[^"]*[Ss]ecurity' "${HA_SYS002_UNATTENDED_FILE}"; then
        ha_task_set_message \
            "No security origin enabled in ${HA_SYS002_UNATTENDED_FILE}."
        return 1
    fi

    if ha_check_systemd; then

        for timer in "${HA_SYS002_TIMERS[@]}"; do

            if ! systemctl is-enabled --quiet "${timer}" 2>/dev/null; then
                ha_task_set_message "${timer} is not enabled."
                return 1
            fi

        done

    fi

    ha_task_set_message "Automatic security updates are configured."
    return 0
}


ha_task_sys002_check() {

    if ! ha_command_exists apt-get; then
        ha_task_result "${HA_TASK_NOT_APPLICABLE}" \
            "APT package manager not available."
        return 0
    fi

    if ha_task_sys002_evaluate; then
        ha_task_set_status "${HA_TASK_COMPLETED}"
    else
        ha_task_set_status "${HA_TASK_READY}"
    fi
}


ha_task_sys002_info() {

    ha_ui_info "$(ha_task_get_message)"
    ha_ui_info "Installs unattended-upgrades, writes ${HA_SYS002_PERIODIC_FILE}"
    ha_ui_info "and enables ${HA_SYS002_TIMERS[*]}."
}


ha_task_sys002_write_config() {

    if ! ha_backup_file "${HA_SYS002_PERIODIC_FILE}"; then
        ha_task_result "${HA_TASK_ERROR}" "Backup failed. Nothing was changed."
        return 1
    fi

    if ! cat > "${HA_SYS002_PERIODIC_FILE}" <<'EOF'
// Managed by HarderAdmin (SYS-002)
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
    then
        ha_task_result "${HA_TASK_ERROR}" \
            "Unable to write ${HA_SYS002_PERIODIC_FILE}."
        return 1
    fi

    chmod 0644 -- "${HA_SYS002_PERIODIC_FILE}"

    ha_log_change "SYS-002" "Wrote ${HA_SYS002_PERIODIC_FILE}"

    if ha_check_systemd \
        && ! systemctl enable --now "${HA_SYS002_TIMERS[@]}" >/dev/null 2>&1; then
        ha_task_result "${HA_TASK_ERROR}" \
            "Unable to enable ${HA_SYS002_TIMERS[*]}."
        return 1
    fi

    return 0
}


ha_task_sys002_execute() {

    if ! ha_package_installed unattended-upgrades; then

        ha_ui_info "Installing unattended-upgrades..."

        if ! ha_apt_get install -y unattended-upgrades; then
            ha_task_result "${HA_TASK_ERROR}" \
                "Unable to install unattended-upgrades."
            return 0
        fi

        ha_log_change "SYS-002" "Installed package unattended-upgrades"

    fi

    ha_task_sys002_write_config || return 0

    ha_task_result "${HA_TASK_COMPLETED}" \
        "Automatic security updates configured successfully."
}


ha_task_sys002_verify() {

    if ha_task_sys002_evaluate; then
        ha_task_set_status "${HA_TASK_COMPLETED}"
    else
        ha_task_set_status "${HA_TASK_ERROR}"
    fi
}


ha_task_sys002_correction() {

    ha_task_sys002_write_config || return 0

    ha_task_result "${HA_TASK_COMPLETED}" \
        "Automatic security updates configuration rewritten."
}


ha_task_sys002_register
