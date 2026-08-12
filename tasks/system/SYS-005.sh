#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# Task: SYS-005
# ==============================================================================


ha_task_sys005_register() {

    ha_task_register \
    "SYS-005" \
    "Configure AppArmor" \
    "System" \
    "Configure and verify AppArmor for security-relevant services." \
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


ha_task_sys005_check() {

    local complain_count
    local unconfined_count
    local profile


    if ! command -v aa-status >/dev/null 2>&1; then

        ha_task_set_message "AppArmor utilities are not installed."
        ha_task_set_status "${HA_TASK_READY}"

        return 0

    fi


    if ! systemctl is-active --quiet apparmor; then

        ha_task_set_message "AppArmor is not active."
        ha_task_set_status "${HA_TASK_READY}"

        return 0

    fi


    if [[ ! -d /sys/module/apparmor ]]; then

        ha_task_set_message "AppArmor kernel module is not loaded."
        ha_task_set_status "${HA_TASK_READY}"

        return 0

    fi


    for profile in \
        /etc/apparmor.d/usr.sbin.chronyd \
        /etc/apparmor.d/usr.sbin.rsyslogd
    do

        if [[ ! -f "${profile}" ]]; then

            ha_task_set_message \
                "Required AppArmor profile is missing: ${profile}."

            ha_task_set_status "${HA_TASK_READY}"

            return 0

        fi

    done


    complain_count="$(
        aa-status 2>/dev/null \
            | awk '/profiles are in complain mode\./ {print $1; exit}'
    )"

    unconfined_count="$(
        aa-status 2>/dev/null \
            | awk '/profiles are in unconfined mode\./ {print $1; exit}'
    )"


    if [[ -z "${complain_count}" ]]; then
        complain_count=0
    fi

    if [[ -z "${unconfined_count}" ]]; then
        unconfined_count=0
    fi


    if [[ "${complain_count}" -gt 0 ]]; then

        ha_task_set_message \
            "AppArmor is active; ${complain_count} profile(s) are in complain mode."

        ha_task_set_status "${HA_TASK_COMPLETED}"

        return 0

    fi


    if [[ "${unconfined_count}" -gt 0 ]]; then

        ha_task_set_message \
            "AppArmor is active; ${unconfined_count} non-enforcing profile(s) are present."

        ha_task_set_status "${HA_TASK_COMPLETED}"

        return 0

    fi


    ha_task_set_message "AppArmor is correctly configured."
    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}


ha_task_sys005_info() {

    ha_ui_info "$(ha_task_get_message)"

}


ha_task_sys005_execute() {

    local profile


    if ! command -v aa-status >/dev/null 2>&1; then

        ha_ui_info "Installing AppArmor..."

        if ! apt-get update >/dev/null \
            || ! apt-get install -y apparmor apparmor-utils >/dev/null; then

            ha_task_set_message \
                "Unable to install AppArmor."

            ha_task_set_status "${HA_TASK_ERROR}"

            return 0

        fi

    fi


    if ! systemctl enable apparmor >/dev/null 2>&1; then

        ha_task_set_message \
            "Unable to enable AppArmor service."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! systemctl start apparmor >/dev/null 2>&1; then

        ha_task_set_message \
            "Unable to start AppArmor service."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    for profile in \
        /etc/apparmor.d/usr.sbin.chronyd \
        /etc/apparmor.d/usr.sbin.rsyslogd
    do

        if [[ -f "${profile}" ]]; then

            if ! apparmor_parser -r "${profile}" >/dev/null 2>&1; then

                ha_task_set_message \
                    "Unable to enforce AppArmor profile: ${profile}."

                ha_task_set_status "${HA_TASK_ERROR}"

                return 0

            fi

        fi

    done


    if ! systemctl reload apparmor >/dev/null 2>&1; then

        ha_task_set_message \
            "Unable to reload AppArmor profiles."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    ha_task_set_message \
        "AppArmor enabled and security-relevant profiles enforced."

    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}


ha_task_sys005_verify() {

    local profile


    if [[ ! -d /sys/module/apparmor ]]; then

        ha_task_set_message \
            "AppArmor kernel module is not loaded."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! systemctl is-active --quiet apparmor; then

        ha_task_set_message \
            "AppArmor service is not active."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! systemctl is-enabled --quiet apparmor; then

        ha_task_set_message \
            "AppArmor service is not enabled."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    for profile in \
        /etc/apparmor.d/usr.sbin.chronyd \
        /etc/apparmor.d/usr.sbin.rsyslogd
    do

        if [[ ! -f "${profile}" ]]; then

            ha_task_set_message \
                "Required AppArmor profile is missing: ${profile}."

            ha_task_set_status "${HA_TASK_ERROR}"

            return 0

        fi

    done


    if ! aa-status 2>/dev/null \
        | grep -q 'usr.sbin.chronyd'; then

        ha_task_set_message \
            "chronyd AppArmor profile is not loaded."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! aa-status 2>/dev/null \
        | grep -q 'usr.sbin.rsyslogd'; then

        ha_task_set_message \
            "rsyslogd AppArmor profile is not loaded."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! aa-status 2>/dev/null \
        | sed -n '/profiles are in enforce mode\./,/profiles are in complain mode\./p' \
        | grep -q 'usr.sbin.chronyd'; then

        ha_task_set_message \
            "chronyd AppArmor profile is not enforced."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! aa-status 2>/dev/null \
        | sed -n '/profiles are in enforce mode\./,/profiles are in complain mode\./p' \
        | grep -qE '(^|[[:space:]])rsyslogd($|[[:space:]])'; then

        ha_task_set_message \
            "rsyslogd AppArmor profile is not enforced."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    ha_task_set_message \
        "AppArmor is correctly configured for security-relevant services."

    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}


ha_task_sys005_correction() {

    local profile
    local force_complain_dir="/etc/apparmor.d/force-complain"


    ha_task_set_message \
        "Correcting AppArmor configuration."


    if ! systemctl enable apparmor >/dev/null 2>&1; then

        ha_task_set_message \
            "Unable to enable AppArmor service."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    if ! systemctl start apparmor >/dev/null 2>&1; then

        ha_task_set_message \
            "Unable to start AppArmor service."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    # Remove explicit force-complain overrides for security-relevant profiles.
    for profile in \
        usr.sbin.chronyd \
        usr.sbin.rsyslogd
    do

        if [[ -f "${force_complain_dir}/${profile}" ]]; then

            if ! rm -f "${force_complain_dir}/${profile}"; then

                ha_task_set_message \
                    "Unable to remove force-complain override: ${profile}."

                ha_task_set_status "${HA_TASK_ERROR}"

                return 0

            fi

        fi

    done


    # Reload the affected profiles.
    for profile in \
        /etc/apparmor.d/usr.sbin.chronyd \
        /etc/apparmor.d/usr.sbin.rsyslogd
    do

        if [[ -f "${profile}" ]]; then

            if ! apparmor_parser -r "${profile}" >/dev/null 2>&1; then

                ha_task_set_message \
                    "Unable to reload AppArmor profile: ${profile}."

                ha_task_set_status "${HA_TASK_ERROR}"

                return 0

            fi

        fi

    done


    if ! systemctl reload apparmor >/dev/null 2>&1; then

        ha_task_set_message \
            "Unable to reload AppArmor profiles."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    # Verify the actual active state.
    ha_task_sys005_verify

    if [[ "${HA_TASK_STATUS}" != "${HA_TASK_COMPLETED}" ]]; then

        ha_task_set_message \
            "AppArmor correction failed verification."

        ha_task_set_status "${HA_TASK_ERROR}"

        return 0

    fi


    ha_task_set_message \
        "AppArmor configuration corrected."

    ha_task_set_status "${HA_TASK_COMPLETED}"

    return 0
}


ha_task_sys005_rollback() {

    return 0
}


ha_task_sys005_register