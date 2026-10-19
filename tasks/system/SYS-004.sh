#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SYS-004
# ==============================================================================
#
# All settings are defined once in HA_SYS004_SETTINGS:
#
#   "<sysctl key>=<accepted values, comma separated>"
#
# The first value is the one that is set. If the running value is already one
# of the accepted values, it is kept (e.g. Ubuntu ships perf_event_paranoid=4,
# which is stricter than 3 and must not be lowered).
#
# Keys that do not exist on this kernel (IPv6 disabled, no Yama LSM, ...) are
# skipped and reported, instead of making "sysctl" fail.
#
# The config file name sorts after 99-sysctl.conf, so a distribution default
# cannot silently override it at boot.
# ------------------------------------------------------------------------------

readonly HA_SYS004_CONFIG_FILE="/etc/sysctl.d/99-zz-harderadmin.conf"

# File written by HarderAdmin versions before 0.1.0, migrated on execute.
readonly HA_SYS004_LEGACY_FILE="/etc/sysctl.d/99-hardening.conf"

# Working variables filled by the callbacks below.
HA_SYS004_FAILED=()
HA_SYS004_UNSUPPORTED=()
HA_SYS004_CONTENT=""

ha_task_sys004_settings() {

    local rp_filter="${SYSCTL_RP_FILTER:-1}"

    cat <<EOF
# IPv4: spoofing, source routing and redirects
net.ipv4.conf.all.rp_filter=${rp_filter}
net.ipv4.conf.default.rp_filter=${rp_filter}
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.default.log_martians=1
# IPv4: ICMP and TCP
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_rfc1337=1
# IPv6: source routing and redirects
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
# Kernel
kernel.randomize_va_space=2
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.yama.ptrace_scope=1,2,3
kernel.perf_event_paranoid=3,4
kernel.unprivileged_bpf_disabled=2,1
net.core.bpf_jit_harden=2
kernel.sysrq=0
dev.tty.ldisc_autoload=0
# Filesystem and processes
fs.protected_hardlinks=1
fs.protected_symlinks=1
fs.protected_fifos=2
fs.protected_regular=2
fs.suid_dumpable=0
EOF
}


ha_task_sys004_register() {

    ha_task_register \
    "SYS-004" \
    "Kernel hardening" \
    "System" \
    "Apply kernel and network security hardening using sysctl." \
    "false" \
    "false" \
    "true" \
    "ha_task_sys004_check" \
    "ha_task_sys004_info" \
    "ha_task_sys004_execute" \
    "ha_task_sys004_verify" \
    "ha_task_sys004_rollback" \
    "ha_task_sys004_correction"
}


# Iterates over all settings. Calls "<callback> <key> <accepted> <current>".
# <current> is empty if the key does not exist on this kernel.
ha_task_sys004_each() {

    local callback="$1"
    local line
    local key
    local accepted
    local current

    while IFS= read -r line; do

        [[ -z "${line}" || "${line}" == \#* ]] && continue

        key="${line%%=*}"
        accepted="${line#*=}"
        current="$(sysctl -n "${key}" 2>/dev/null)" || current=""

        "${callback}" "${key}" "${accepted}" "${current}"

    done < <(ha_task_sys004_settings)
}


ha_task_sys004_is_accepted() {

    local value="$1"
    local accepted="$2"

    [[ ",${accepted}," == *",${value},"* ]]
}


# --- evaluation ---------------------------------------------------------------

ha_task_sys004_collect() {

    local key="$1"
    local accepted="$2"
    local current="$3"

    if [[ -z "${current}" ]]; then
        HA_SYS004_UNSUPPORTED+=("${key}")
    elif ! ha_task_sys004_is_accepted "${current}" "${accepted}"; then
        HA_SYS004_FAILED+=("${key}=${current}")
    fi
}


# Returns 0 if all runtime values are compliant. Sets a message.
ha_task_sys004_evaluate() {

    HA_SYS004_FAILED=()
    HA_SYS004_UNSUPPORTED=()

    ha_task_sys004_each ha_task_sys004_collect

    if (( ${#HA_SYS004_FAILED[@]} > 0 )); then

        local preview="${HA_SYS004_FAILED[*]:0:3}"

        if (( ${#HA_SYS004_FAILED[@]} > 3 )); then
            preview+=" ..."
        fi

        ha_task_set_message \
            "${#HA_SYS004_FAILED[@]} setting(s) not compliant: ${preview}"
        return 1
    fi

    if [[ ! -f "${HA_SYS004_CONFIG_FILE}" ]]; then
        ha_task_set_message \
            "Runtime values are compliant, but not persistent (${HA_SYS004_CONFIG_FILE} missing)."
        return 1
    fi

    local message="Kernel hardening is active and persistent."

    if (( ${#HA_SYS004_UNSUPPORTED[@]} > 0 )); then
        message+=" Not supported by this kernel: ${HA_SYS004_UNSUPPORTED[*]}"
    fi

    ha_task_set_message "${message}"
    return 0
}


ha_task_sys004_check() {

    if ! ha_command_exists sysctl; then
        ha_task_result "${HA_TASK_NOT_APPLICABLE}" "sysctl is not available."
        return 0
    fi

    if ha_task_sys004_evaluate; then
        ha_task_set_status "${HA_TASK_COMPLETED}"
    else
        ha_task_set_status "${HA_TASK_READY}"
    fi
}


ha_task_sys004_info() {

    ha_ui_info "$(ha_task_get_message)"
    ha_ui_info "Writes ${HA_SYS004_CONFIG_FILE} and applies it immediately."

    if [[ "${SYSCTL_RP_FILTER:-1}" == "1" ]]; then
        ha_ui_warning "Strict reverse path filtering (rp_filter=1) can break hosts"
        ha_ui_warning "with several interfaces or asymmetric routing."
        ha_ui_warning "Set SYSCTL_RP_FILTER=\"2\" in the configuration for such hosts."
    fi
}


# --- apply --------------------------------------------------------------------

# Writes one config line and remembers the old runtime value for rollback.
ha_task_sys004_render() {

    local key="$1"
    local accepted="$2"
    local current="$3"
    local value="${accepted%%,*}"

    if [[ -z "${current}" ]]; then
        HA_SYS004_CONTENT+="# ${key}: not supported by this kernel"$'\n'
        return 0
    fi

    if ha_task_sys004_is_accepted "${current}" "${accepted}"; then
        value="${current}"
    fi

    ha_task_set_context "SYS-004" "runtime:${key}" "${current}"

    HA_SYS004_CONTENT+="${key} = ${value}"$'\n'
}


ha_task_sys004_apply() {

    if ! ha_backup_file "${HA_SYS004_CONFIG_FILE}"; then
        ha_task_result "${HA_TASK_ERROR}" "Backup failed. Nothing was changed."
        return 1
    fi

    HA_SYS004_CONTENT=""
    ha_task_sys004_each ha_task_sys004_render

    if ! {
        printf "%s\n" \
            "# ==============================================================================" \
            "# Managed by HarderAdmin (SYS-004) - Kernel and network hardening" \
            "# Changes are overwritten when the task runs again." \
            "# ==============================================================================" \
            ""
        printf "%s" "${HA_SYS004_CONTENT}"
    } > "${HA_SYS004_CONFIG_FILE}"; then
        ha_task_result "${HA_TASK_ERROR}" \
            "Unable to write ${HA_SYS004_CONFIG_FILE}."
        return 1
    fi

    chmod 0644 -- "${HA_SYS004_CONFIG_FILE}"
    ha_log_change "SYS-004" "Wrote ${HA_SYS004_CONFIG_FILE}"

    # Migrate the file of older HarderAdmin versions.
    if [[ -f "${HA_SYS004_LEGACY_FILE}" ]] \
        && grep -q "HarderAdmin" "${HA_SYS004_LEGACY_FILE}"; then

        if ha_backup_file "${HA_SYS004_LEGACY_FILE}" \
            && rm -f -- "${HA_SYS004_LEGACY_FILE}"; then
            ha_log_change "SYS-004" "Removed legacy ${HA_SYS004_LEGACY_FILE}"
        fi

    fi

    # Apply only our file; "sysctl --system" fails as soon as any file of
    # any package contains a key this kernel does not know.
    if ! sysctl -q -p "${HA_SYS004_CONFIG_FILE}" >/dev/null; then
        ha_task_result "${HA_TASK_ERROR}" \
            "Unable to apply ${HA_SYS004_CONFIG_FILE}."
        return 1
    fi

    return 0
}


ha_task_sys004_execute() {

    ha_task_sys004_apply || return 0

    ha_task_result "${HA_TASK_COMPLETED}" \
        "Kernel hardening configured successfully."
}


ha_task_sys004_verify() {

    if ha_task_sys004_evaluate; then
        ha_task_set_status "${HA_TASK_COMPLETED}"
    else
        ha_task_set_status "${HA_TASK_ERROR}"
    fi
}


ha_task_sys004_correction() {

    ha_task_sys004_apply || return 0

    ha_task_result "${HA_TASK_COMPLETED}" \
        "Kernel hardening configuration rewritten and applied."
}


# Runs after the runner restored the files: restore the old runtime values,
# because removing the file alone does not change the running kernel.
ha_task_sys004_rollback() {

    local context_key
    local key
    local failed=()

    for context_key in "${!HA_TASK_CONTEXT[@]}"; do

        [[ "${context_key}" == "SYS-004:runtime:"* ]] || continue

        key="${context_key#SYS-004:runtime:}"

        if ! sysctl -q -w "${key}=${HA_TASK_CONTEXT[${context_key}]}" \
            >/dev/null 2>&1; then
            failed+=("${key}")
        fi

    done

    ha_log_change "SYS-004" "Rollback: runtime values restored."

    if (( ${#failed[@]} > 0 )); then
        ha_task_result "${HA_TASK_ERROR}" \
            "Could not restore: ${failed[*]} (reboot to reset)."
        return 0
    fi

    ha_task_result "${HA_TASK_COMPLETED}" "Previous kernel values restored."
}


ha_task_sys004_register
