#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SYS-005
# ==============================================================================
#
# Enables AppArmor and enforces the profiles listed in HA_SYS005_PROFILES.
#
#   "<profile file in /etc/apparmor.d>:<binary the profile confines>"
#
# A profile is only applicable if its binary is installed (chrony, for example,
# is not installed by default on Ubuntu 22.04/24.04 LTS).
#
# The loaded state is read from the kernel
# (/sys/kernel/security/apparmor/profiles, lines "<name> (<mode>)") instead of
# parsing the human-readable aa-status output.
# ------------------------------------------------------------------------------

readonly HA_SYS005_PROFILE_DIR="/etc/apparmor.d"
readonly HA_SYS005_KERNEL_PROFILES="/sys/kernel/security/apparmor/profiles"

readonly HA_SYS005_PROFILES=(
    "usr.sbin.chronyd:/usr/sbin/chronyd"
    "usr.sbin.rsyslogd:/usr/sbin/rsyslogd"
)


ha_task_sys005_register() {

    ha_task_register \
    "SYS-005" \
    "Configure AppArmor" \
    "System" \
    "Enable AppArmor and enforce profiles for security-relevant services." \
    "false" \
    "possible" \
    "true" \
    "ha_task_sys005_check" \
    "ha_task_sys005_info" \
    "ha_task_sys005_execute" \
    "ha_task_sys005_verify" \
    "ha_task_sys005_rollback" \
    "ha_task_sys005_correction"
}


ha_task_sys005_kernel_enabled() {

    [[ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" == "Y" \
        && -r "${HA_SYS005_KERNEL_PROFILES}" ]]
}


# Prints "<profile file>" for every profile whose binary is installed.
ha_task_sys005_applicable_profiles() {

    local entry

    for entry in "${HA_SYS005_PROFILES[@]}"; do

        if [[ -x "${entry#*:}" ]]; then
            printf "%s\n" "${entry%%:*}"
        fi

    done
}


# Prints the name the kernel uses for a profile file: either the name after
# the "profile" keyword or the attachment path ("/usr/sbin/chronyd {").
ha_task_sys005_profile_name() {

    local file="${HA_SYS005_PROFILE_DIR}/$1"
    local name

    name="$(sed -nE \
        -e 's/^[[:space:]]*profile[[:space:]]+([^[:space:]{]+).*/\1/p' \
        -e 's/^[[:space:]]*(\/[^[:space:]{]+)[[:space:]]*(flags=\([^)]*\))?[[:space:]]*\{.*/\1/p' \
        "${file}" 2>/dev/null | head -n 1)" || true

    [[ -n "${name}" ]] || return 1

    printf "%s" "${name}"
}


# Prints the mode of a loaded profile (enforce, complain, ...) or nothing.
ha_task_sys005_profile_mode() {

    local name="$1"
    local profiles

    profiles="$(cat "${HA_SYS005_KERNEL_PROFILES}" 2>/dev/null)" || return 0

    awk -v name="${name}" '
        {
            mode = $NF
            sub(/ \([^)]*\)$/, "")
            if ($0 == name) { gsub(/[()]/, "", mode); print mode; exit }
        }' <<< "${profiles}"
}


# Returns 0 if compliant, otherwise 1. Sets a message.
ha_task_sys005_evaluate() {

    local profile
    local name
    local mode
    local count=0
    local complain

    if ! ha_check_systemd || ! systemctl is-enabled --quiet apparmor 2>/dev/null; then
        ha_task_set_message "AppArmor service is not enabled."
        return 1
    fi

    if ! ha_command_exists aa-enforce; then
        ha_task_set_message "AppArmor utilities (apparmor-utils) are not installed."
        return 1
    fi

    while IFS= read -r profile; do

        [[ -n "${profile}" ]] || continue

        count=$(( count + 1 ))

        if [[ ! -f "${HA_SYS005_PROFILE_DIR}/${profile}" ]]; then
            ha_task_set_message "AppArmor profile is missing: ${profile}"
            return 1
        fi

        if [[ -e "${HA_SYS005_PROFILE_DIR}/disable/${profile}" ]]; then
            ha_task_set_message "AppArmor profile is disabled: ${profile}"
            return 1
        fi

        if ! name="$(ha_task_sys005_profile_name "${profile}")"; then
            ha_task_set_message "Unable to read profile name: ${profile}"
            return 1
        fi

        mode="$(ha_task_sys005_profile_mode "${name}")"

        if [[ "${mode}" != "enforce" && "${mode}" != "kill" ]]; then
            ha_task_set_message \
                "Profile ${name} is not enforced (mode: ${mode:-not loaded})."
            return 1
        fi

    done < <(ha_task_sys005_applicable_profiles)

    complain="$(grep -c '(complain)$' "${HA_SYS005_KERNEL_PROFILES}" 2>/dev/null)" \
        || complain=0

    ha_task_set_message \
        "AppArmor is active; ${count} managed profile(s) enforced; ${complain} profile(s) system-wide in complain mode."
    return 0
}


ha_task_sys005_check() {

    if ! ha_task_sys005_kernel_enabled; then
        ha_task_result "${HA_TASK_BLOCKED}" \
            "AppArmor is not enabled in the kernel (boot parameter apparmor=1 or another LSM active)."
        return 0
    fi

    if ha_task_sys005_evaluate; then
        ha_task_set_status "${HA_TASK_COMPLETED}"
    else
        ha_task_set_status "${HA_TASK_READY}"
    fi
}


ha_task_sys005_info() {

    local profiles

    profiles="$(ha_task_sys005_applicable_profiles | tr '\n' ' ')"

    ha_ui_info "$(ha_task_get_message)"
    ha_ui_info "Profiles to enforce on this system: ${profiles:-none (services not installed)}"
    ha_ui_warning "An enforced profile can block a service whose configuration"
    ha_ui_warning "uses unusual paths. Check the service after the task."
}


ha_task_sys005_apply() {

    local profile

    if ! ha_command_exists aa-enforce || ! ha_command_exists apparmor_parser; then

        ha_ui_info "Installing AppArmor..."

        if ! ha_apt_get install -y apparmor apparmor-utils; then
            ha_task_result "${HA_TASK_ERROR}" "Unable to install AppArmor."
            return 1
        fi

        ha_log_change "SYS-005" "Installed packages apparmor apparmor-utils"

    fi

    if ! systemctl enable --now apparmor >/dev/null 2>&1; then
        ha_task_result "${HA_TASK_ERROR}" "Unable to enable AppArmor service."
        return 1
    fi

    while IFS= read -r profile; do

        [[ -n "${profile}" ]] || continue

        if [[ ! -f "${HA_SYS005_PROFILE_DIR}/${profile}" ]]; then
            ha_task_result "${HA_TASK_ERROR}" \
                "AppArmor profile is missing: ${profile} (package apparmor-profiles?)"
            return 1
        fi

        # aa-enforce edits the profile flags and removes disable/force-complain
        # links, so all three are backed up.
        if ! ha_backup_file "${HA_SYS005_PROFILE_DIR}/${profile}" \
            || ! ha_backup_file "${HA_SYS005_PROFILE_DIR}/disable/${profile}" \
            || ! ha_backup_file "${HA_SYS005_PROFILE_DIR}/force-complain/${profile}"; then
            ha_task_result "${HA_TASK_ERROR}" "Backup failed for ${profile}."
            return 1
        fi

        if ! aa-enforce "${HA_SYS005_PROFILE_DIR}/${profile}" >/dev/null 2>&1; then
            ha_task_result "${HA_TASK_ERROR}" "Unable to enforce profile: ${profile}"
            return 1
        fi

        ha_log_change "SYS-005" "Enforced AppArmor profile ${profile}"

    done < <(ha_task_sys005_applicable_profiles)

    return 0
}


ha_task_sys005_execute() {

    if ! ha_task_sys005_kernel_enabled; then
        ha_task_result "${HA_TASK_BLOCKED}" \
            "AppArmor is not enabled in the kernel."
        return 0
    fi

    ha_task_sys005_apply || return 0

    ha_task_result "${HA_TASK_COMPLETED}" \
        "AppArmor enabled and profiles enforced."
}


ha_task_sys005_verify() {

    if ha_task_sys005_evaluate; then
        ha_task_set_status "${HA_TASK_COMPLETED}"
    else
        ha_task_set_status "${HA_TASK_ERROR}"
    fi
}


ha_task_sys005_correction() {

    ha_task_sys005_apply || return 0

    ha_task_result "${HA_TASK_COMPLETED}" "AppArmor profiles enforced again."
}


# Runs after the runner restored the profile files: load them in their
# previous state again.
ha_task_sys005_rollback() {

    local profile
    local file
    local failed=()

    while IFS= read -r profile; do

        [[ -n "${profile}" ]] || continue

        file="${HA_SYS005_PROFILE_DIR}/${profile}"

        if [[ -e "${HA_SYS005_PROFILE_DIR}/disable/${profile}" ]]; then
            apparmor_parser -R "${file}" >/dev/null 2>&1 || true
        elif [[ -e "${HA_SYS005_PROFILE_DIR}/force-complain/${profile}" ]]; then
            apparmor_parser -C -r "${file}" >/dev/null 2>&1 || failed+=("${profile}")
        elif [[ -f "${file}" ]]; then
            apparmor_parser -r "${file}" >/dev/null 2>&1 || failed+=("${profile}")
        fi

    done < <(ha_task_sys005_applicable_profiles)

    ha_log_change "SYS-005" "Rollback: profiles reloaded."

    if (( ${#failed[@]} > 0 )); then
        ha_task_result "${HA_TASK_ERROR}" "Unable to reload: ${failed[*]}"
        return 0
    fi

    ha_task_result "${HA_TASK_COMPLETED}" "Previous AppArmor state restored."
}


ha_task_sys005_register
