#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/ssh.sh
# ==============================================================================
#
# Every SSH task writes its own drop-in file with disjoint options:
#
#   /etc/ssh/sshd_config.d/00-harderadmin-ssh-001.conf   (SSH-001)
#   /etc/ssh/sshd_config.d/00-harderadmin-ssh-002.conf   (SSH-002) ...
#
# One file per task keeps rollbacks independent: rolling back SSH-002 does
# not undo SSH-003 or SSH-004.
#
# sshd uses the FIRST value it reads for most options, and the drop-ins are
# included at the top of sshd_config in lexical order. "00-" therefore wins
# over distribution files such as 50-cloud-init.conf (which sets
# "PasswordAuthentication yes" on many cloud images) and over sshd_config.
# A file named 99-*.conf, as suggested by many guides, would lose against it.
#
# Exceptions: Port, AllowUsers, AllowGroups, DenyUsers and DenyGroups
# accumulate over all files. The SSH tasks check for such conflicts.
#
# The state is always checked with "sshd -T" (effective configuration),
# never by grepping individual files.
# ------------------------------------------------------------------------------

readonly HA_SSHD_BIN="/usr/sbin/sshd"
readonly HA_SSH_MAIN_CONFIG="/etc/ssh/sshd_config"
readonly HA_SSH_DROPIN_DIR="/etc/ssh/sshd_config.d"
readonly HA_SSH_MANAGED_PREFIX="${HA_SSH_DROPIN_DIR}/00-harderadmin-"
readonly HA_SSH_SOCKET_GENERATORS=(
    "/usr/lib/systemd/system-generators/sshd-socket-generator"
    "/lib/systemd/system-generators/sshd-socket-generator"
)

HA_SSH_EFFECTIVE=""
HA_SSH_ERROR=""
HA_SSH_FAILED=()
HA_SSH_UNSUPPORTED=()


# ------------------------------------------------------------------------------
# Effective configuration
# ------------------------------------------------------------------------------

ha_ssh_installed() {

    [[ -x "${HA_SSHD_BIN}" ]]
}


# sshd -t / -T need the privilege separation directory, which only exists
# while sshd runs (it is on tmpfs). Creating it is harmless.
ha_ssh_prepare_runtime() {

    install -d -m 0755 -- /run/sshd 2>/dev/null || true
}


ha_ssh_includes_dropins() {

    [[ -f "${HA_SSH_MAIN_CONFIG}" ]] \
        && grep -Eqi \
            '^[[:space:]]*Include[[:space:]]+(/etc/ssh/)?sshd_config\.d/\*\.conf([[:space:]]|$)' \
            "${HA_SSH_MAIN_CONFIG}"
}


# Validates the configuration. Sets HA_SSH_ERROR on failure.
ha_ssh_test_config() {

    local output

    ha_ssh_prepare_runtime

    if ! output="$("${HA_SSHD_BIN}" -t 2>&1)"; then
        HA_SSH_ERROR="$(head -n 1 <<< "${output}")"
        return 1
    fi

    HA_SSH_ERROR=""
}


# Loads "sshd -T" into HA_SSH_EFFECTIVE.
ha_ssh_load_effective() {

    local output

    ha_ssh_prepare_runtime

    if ! output="$("${HA_SSHD_BIN}" -T 2>/dev/null)"; then
        HA_SSH_EFFECTIVE=""
        ha_ssh_test_config || true
        return 1
    fi

    HA_SSH_EFFECTIVE="${output}"
}


# Prints the first effective value of an option (lowercase name).
ha_ssh_value() {

    awk -v key="${1,,}" '
        $1 == key { sub(/^[^ ]+ ?/, ""); print; exit }
    ' <<< "${HA_SSH_EFFECTIVE}"
}


# Prints all effective values of an option as one space-separated line.
ha_ssh_values() {

    awk -v key="${1,,}" '
        $1 == key { sub(/^[^ ]+ ?/, ""); out = out (out == "" ? "" : " ") $0 }
        END { print out }
    ' <<< "${HA_SSH_EFFECTIVE}"
}


# True if sshd -T knows the option at all (version dependent).
ha_ssh_has_option() {

    awk -v key="${1,,}" '$1 == key { found = 1 } END { exit !found }' \
        <<< "${HA_SSH_EFFECTIVE}"
}


# Common preconditions of all SSH tasks. Sets a status and returns 1 if the
# task cannot continue.
ha_ssh_require() {

    if ! ha_ssh_installed; then
        ha_task_result "${HA_TASK_NOT_APPLICABLE}" \
            "OpenSSH server is not installed."
        return 1
    fi

    if ! ha_ssh_includes_dropins; then
        ha_task_result "${HA_TASK_BLOCKED}" \
            "${HA_SSH_MAIN_CONFIG} does not include sshd_config.d/*.conf."
        return 1
    fi

    if ! ha_ssh_load_effective; then
        ha_task_result "${HA_TASK_ERROR}" \
            "sshd configuration is invalid: ${HA_SSH_ERROR}"
        return 1
    fi

    return 0
}


# ------------------------------------------------------------------------------
# Data-driven settings
#
# A settings function prints lines "<Option>=<accepted values, comma separated>".
# The first value is written; an already active accepted value is kept.
# ------------------------------------------------------------------------------

ha_ssh_is_accepted() {

    [[ ",${2,,}," == *",${1,,},"* ]]
}


# Compares the effective configuration with a settings function.
# Fills HA_SSH_FAILED ("option=current") and HA_SSH_UNSUPPORTED.
ha_ssh_compare_settings() {

    local settings_function="$1"
    local line
    local option
    local accepted
    local current

    HA_SSH_FAILED=()
    HA_SSH_UNSUPPORTED=()

    while IFS= read -r line; do

        [[ -z "${line}" || "${line}" == \#* ]] && continue

        option="${line%%=*}"
        accepted="${line#*=}"

        if ! ha_ssh_has_option "${option}"; then
            HA_SSH_UNSUPPORTED+=("${option}")
            continue
        fi

        current="$(ha_ssh_value "${option}")"

        if ! ha_ssh_is_accepted "${current}" "${accepted}"; then
            HA_SSH_FAILED+=("${option}=${current}")
        fi

    done < <("${settings_function}")
}


# Writes all options of a settings function to the managed file.
ha_ssh_write_settings() {

    local settings_function="$1"
    local line
    local option
    local accepted
    local current
    local value

    while IFS= read -r line; do

        [[ -z "${line}" || "${line}" == \#* ]] && continue

        option="${line%%=*}"
        accepted="${line#*=}"
        value="${accepted%%,*}"

        if ! ha_ssh_has_option "${option}"; then
            continue
        fi

        current="$(ha_ssh_value "${option}")"

        if ha_ssh_is_accepted "${current}" "${accepted}"; then
            value="${current}"
        fi

        ha_ssh_managed_set "${option}" "${value}" || return 1

    done < <("${settings_function}")
}


# ------------------------------------------------------------------------------
# Managed drop-in files (one per task)
# ------------------------------------------------------------------------------

# ha_ssh_managed_file <task id>  ->  .../00-harderadmin-ssh-001.conf
ha_ssh_managed_file() {

    printf "%s%s.conf" "${HA_SSH_MANAGED_PREFIX}" "${1,,}"
}


ha_ssh_is_managed_file() {

    [[ "$1" == "${HA_SSH_MANAGED_PREFIX}"*.conf ]]
}


# ha_ssh_managed_set <Option> <value>   (empty value removes the option)
# Writes to the drop-in of the task currently executing (HA_BACKUP_TASK_ID).
ha_ssh_managed_set() {

    local option="$1"
    local value="$2"
    local file
    local tmp

    if [[ ! "${HA_BACKUP_TASK_ID:-}" =~ ^[A-Z]{2,6}-[0-9]{3}$ ]]; then
        ha_log_error "ha_ssh_managed_set called outside of a task."
        return 1
    fi

    file="$(ha_ssh_managed_file "${HA_BACKUP_TASK_ID}")"

    if [[ ! "${option}" =~ ^[A-Za-z][A-Za-z0-9]*$ || "${value}" == *$'\n'* ]]; then
        ha_log_error "Invalid sshd option: ${option}"
        return 1
    fi

    ha_backup_file "${file}" || return 1

    install -d -m 0755 -- "${HA_SSH_DROPIN_DIR}" || return 1

    tmp="$(mktemp "${file}.XXXXXX")" || return 1

    if ! {
        if [[ -f "${file}" ]]; then
            awk -v option="${option,,}" 'tolower($1) != option' \
                "${file}"
        else
            printf "%s\n" \
                "# ==============================================================================" \
                "# Managed by HarderAdmin (${HA_BACKUP_TASK_ID}). Do not edit: changes are overwritten." \
                "# Sorts before other drop-ins, so its values win over them and sshd_config." \
                "# ==============================================================================" \
                ""
        fi

        if [[ -n "${value}" ]]; then
            printf "%s %s\n" "${option}" "${value}"
        fi
    } > "${tmp}"; then
        rm -f -- "${tmp}"
        return 1
    fi

    if ! chmod 0644 -- "${tmp}" || ! mv -f -- "${tmp}" "${file}"; then
        rm -f -- "${tmp}"
        return 1
    fi

    ha_log_change "${HA_BACKUP_TASK_ID:-SSH}" "sshd: ${option} ${value:-<removed>}"
}


# Files not managed by HarderAdmin that set an option.
ha_ssh_files_setting() {

    local option="$1"
    local file

    for file in "${HA_SSH_MAIN_CONFIG}" "${HA_SSH_DROPIN_DIR}"/*.conf; do

        if [[ ! -f "${file}" ]] || ha_ssh_is_managed_file "${file}"; then
            continue
        fi

        if grep -Eqi "^[[:space:]]*${option}[[:space:]]" "${file}"; then
            printf "%s " "${file}"
        fi

    done
}


# Validates the written configuration; restores the files of the current
# backup session if it is invalid.
ha_ssh_validate_or_restore() {

    if ha_ssh_test_config; then
        return 0
    fi

    ha_backup_restore_session || true

    ha_task_result "${HA_TASK_ERROR}" \
        "New sshd configuration is invalid (${HA_SSH_ERROR}). Files restored, nothing activated."
    return 1
}


# ------------------------------------------------------------------------------
# Service handling
#
# Ubuntu 22.10+ starts sshd through ssh.socket (socket activation). In that
# mode the listening port belongs to the socket unit, which a generator
# (sshd-socket-generator) derives from Port/ListenAddress in sshd_config.
# ------------------------------------------------------------------------------

ha_ssh_service_unit() {

    local unit

    for unit in ssh.service sshd.service; do

        if systemctl cat "${unit}" >/dev/null 2>&1; then
            printf "%s" "${unit}"
            return 0
        fi

    done

    return 1
}


ha_ssh_socket_mode() {

    systemctl is-enabled --quiet ssh.socket 2>/dev/null \
        || systemctl is-active --quiet ssh.socket 2>/dev/null
}


ha_ssh_has_socket_generator() {

    local generator

    for generator in "${HA_SSH_SOCKET_GENERATORS[@]}"; do
        [[ -x "${generator}" ]] && return 0
    done

    return 1
}


# Makes a running sshd read the new configuration (all options except Port).
ha_ssh_reload() {

    local unit

    if ! ha_check_systemd; then

        if [[ -s /run/sshd.pid ]]; then
            kill -HUP "$(cat /run/sshd.pid)" 2>/dev/null
            return
        fi

        return 0
    fi

    unit="$(ha_ssh_service_unit)" || return 1

    if ! systemctl is-active --quiet "${unit}"; then
        # Socket activation without running daemon: the next connection
        # starts sshd with the new configuration.
        return 0
    fi

    if ha_ssh_socket_mode; then
        # The socket keeps listening; existing sessions survive.
        systemctl restart "${unit}"
    else
        systemctl reload "${unit}"
    fi
}


# Decides how a port change will be activated and stores it in the task
# context, BEFORE the guard is armed (the rollback needs it).
#
#   socket-generator  : daemon-reload + restart ssh.socket (Ubuntu default)
#   socket-to-service : disable ssh.socket, run ssh.service (as in the guide;
#                       used when no generator exists)
#   service           : restart ssh.service
#   pid               : no systemd, SIGHUP
ha_ssh_plan_port_activation() {

    local id="$1"
    local unit=""
    local mode

    if ! ha_check_systemd; then
        mode="pid"
    else
        unit="$(ha_ssh_service_unit)" || return 1

        if ha_ssh_socket_mode; then
            if ha_ssh_has_socket_generator; then
                mode="socket-generator"
            else
                mode="socket-to-service"
            fi
        else
            mode="service"
        fi

        ha_task_set_context "${id}" "unit" "${unit}"
        ha_task_set_context "${id}" "unit_enabled" \
            "$(systemctl is-enabled "${unit}" 2>/dev/null || true)"
    fi

    ha_task_set_context "${id}" "activation" "${mode}"
}


# Activates (or, after files were restored, re-activates) the port
# configuration according to the planned mode.
# ha_ssh_activate_port <task id> <apply|revert>
ha_ssh_activate_port() {

    local id="$1"
    local direction="$2"
    local mode
    local unit

    mode="$(ha_task_get_context "${id}" "activation")"
    unit="$(ha_task_get_context "${id}" "unit")"

    case "${mode}" in

        socket-generator)
            systemctl daemon-reload \
                && { systemctl stop "${unit}" || true; } \
                && systemctl restart ssh.socket
            ;;

        socket-to-service)
            if [[ "${direction}" == "apply" ]]; then
                systemctl daemon-reload \
                    && systemctl disable --now ssh.socket \
                    && systemctl enable "${unit}" \
                    && systemctl restart "${unit}"
            else
                systemctl stop "${unit}" || true

                if [[ "$(ha_task_get_context "${id}" "unit_enabled")" != "enabled" ]]; then
                    systemctl disable "${unit}" >/dev/null 2>&1 || true
                fi

                systemctl daemon-reload \
                    && systemctl enable --now ssh.socket
            fi
            ;;

        service)
            systemctl restart "${unit}"
            ;;

        pid)
            [[ -s /run/sshd.pid ]] && kill -HUP "$(cat /run/sshd.pid)"
            ;;

        *)
            ha_ssh_reload
            ;;

    esac
}


# ------------------------------------------------------------------------------
# Lockout prevention
# ------------------------------------------------------------------------------

# True if a user matches an AllowUsers/DenyUsers list (patterns, user@host).
ha_ssh_user_in_list() {

    local user="$1"
    local list="$2"
    local pattern

    for pattern in ${list}; do

        pattern="${pattern%%@*}"

        # shellcheck disable=SC2053 # glob match is intended
        [[ "${user}" == ${pattern} ]] && return 0

    done

    return 1
}


ha_ssh_user_in_groups() {

    local user="$1"
    local list="$2"
    local group
    local pattern

    for group in $(id -nG -- "${user}" 2>/dev/null); do

        for pattern in ${list}; do

            # shellcheck disable=SC2053 # glob match is intended
            [[ "${group}" == ${pattern} ]] && return 0

        done

    done

    return 1
}


# ha_ssh_usable_admins <key|any> [AllowUsers override]
#
# Prints administrators who can still log in via SSH with the effective
# configuration (or with the given AllowUsers list):
#   key : user needs an SSH key (password authentication will be off)
#   any : SSH key, or a password while PasswordAuthentication is on
ha_ssh_usable_admins() {

    local mode="$1"
    local allow_users="${2-__effective__}"
    local deny_users
    local allow_groups
    local deny_groups
    local password_auth
    local user
    local shell

    if [[ "${allow_users}" == "__effective__" ]]; then
        allow_users="$(ha_ssh_values allowusers)"
    fi

    deny_users="$(ha_ssh_values denyusers)"
    allow_groups="$(ha_ssh_values allowgroups)"
    deny_groups="$(ha_ssh_values denygroups)"
    password_auth="$(ha_ssh_value passwordauthentication)"

    while IFS= read -r user; do

        [[ -n "${user}" ]] || continue

        shell="$(getent passwd "${user}" | cut -d: -f7)"

        case "${shell}" in
            */nologin|*/false|"") continue ;;
        esac

        if [[ -n "${deny_users}" ]] && ha_ssh_user_in_list "${user}" "${deny_users}"; then
            continue
        fi

        if [[ -n "${allow_users}" ]] && ! ha_ssh_user_in_list "${user}" "${allow_users}"; then
            continue
        fi

        if [[ -n "${deny_groups}" ]] && ha_ssh_user_in_groups "${user}" "${deny_groups}"; then
            continue
        fi

        if [[ -n "${allow_groups}" ]] && ! ha_ssh_user_in_groups "${user}" "${allow_groups}"; then
            continue
        fi

        if ha_user_has_ssh_key "${user}"; then
            printf "%s\n" "${user}"
        elif [[ "${mode}" == "any" && "${password_auth}" == "yes" ]] \
            && ha_user_has_password "${user}"; then
            printf "%s\n" "${user}"
        fi

    done < <(ha_admin_users)
}


# Prints a "how to test" line for the guard prompt.
ha_ssh_test_hint() {

    local port="${1:-}"
    local user
    local host

    if [[ -z "${port}" ]]; then
        port="$(ha_ssh_value port)"
    fi

    user="$(ha_invoking_user)"
    user="${user:-$(ha_ssh_usable_admins key | head -n 1)}"
    user="${user:-<admin>}"

    # Server address of the current SSH connection, if any.
    host="$(awk '{ print $3 }' <<< "${SSH_CONNECTION:-}")"
    host="${host:-$(hostname -f 2>/dev/null || hostname)}"

    printf "Test in a NEW terminal: ssh -p %s %s@%s" "${port:-22}" "${user}" "${host}"
}


# Warns if the admin is logged in directly as root over SSH.
ha_ssh_warn_root_session() {

    if [[ -n "${SSH_CONNECTION:-}" && -z "$(ha_invoking_user)" ]]; then
        ha_ui_warning "You are logged in as root over SSH. Make sure an administrator"
        ha_ui_warning "account works before you continue."
    fi
}


# ------------------------------------------------------------------------------
# Generic task phases for settings-only SSH tasks (SSH-001, SSH-002)
#
#   lockout mode "any": an admin must be able to log in with key or password
#   lockout mode "key": an admin must have an SSH key
# ------------------------------------------------------------------------------

ha_ssh_preview_failed() {

    local preview="${HA_SSH_FAILED[*]:0:3}"

    if (( ${#HA_SSH_FAILED[@]} > 3 )); then
        preview+=" ..."
    fi

    printf "%s" "${preview}"
}


# ha_ssh_settings_check <settings function> <any|key> <blocked message>
ha_ssh_settings_check() {

    local settings_function="$1"
    local lockout_mode="$2"
    local blocked_message="$3"

    ha_ssh_require || return 0

    ha_ssh_compare_settings "${settings_function}"

    if (( ${#HA_SSH_FAILED[@]} == 0 )); then
        ha_task_result "${HA_TASK_COMPLETED}" "All settings are active."
        return 0
    fi

    if [[ -z "$(ha_ssh_usable_admins "${lockout_mode}")" ]]; then
        ha_task_result "${HA_TASK_BLOCKED}" "${blocked_message}"
        return 0
    fi

    ha_task_result "${HA_TASK_READY}" \
        "${#HA_SSH_FAILED[@]} setting(s) not active: $(ha_ssh_preview_failed)"
}


ha_ssh_activate_reload() {

    if ha_ssh_reload; then
        ha_task_result "${HA_TASK_COMPLETED}" "sshd reloaded."
    else
        ha_task_result "${HA_TASK_ERROR}" "Unable to reload sshd."
    fi
}


# ha_ssh_settings_execute <task id> <settings function> <any|key> <blocked message>
ha_ssh_settings_execute() {

    local id="$1"
    local settings_function="$2"
    local lockout_mode="$3"
    local blocked_message="$4"

    ha_ssh_require || return 0

    if [[ -z "$(ha_ssh_usable_admins "${lockout_mode}")" ]]; then
        ha_task_result "${HA_TASK_BLOCKED}" "${blocked_message}"
        return 0
    fi

    if ! ha_ssh_write_settings "${settings_function}"; then
        ha_backup_restore_session || true
        ha_task_result "${HA_TASK_ERROR}" \
            "Unable to write $(ha_ssh_managed_file "${id}"). Files restored."
        return 0
    fi

    ha_ssh_validate_or_restore || return 0

    ha_guard_run "${id}" ha_ssh_activate_reload "$(ha_ssh_test_hint "")"
}


ha_ssh_settings_verify() {

    local settings_function="$1"

    if ! ha_ssh_load_effective; then
        ha_task_result "${HA_TASK_ERROR}" \
            "sshd configuration is invalid: ${HA_SSH_ERROR}"
        return 0
    fi

    ha_ssh_compare_settings "${settings_function}"

    if (( ${#HA_SSH_FAILED[@]} > 0 )); then
        ha_task_result "${HA_TASK_ERROR}" \
            "Not active: $(ha_ssh_preview_failed)"
        return 0
    fi

    ha_task_result "${HA_TASK_COMPLETED}" "All settings are active."
}


# Rollback hook: files are already restored, make sshd use them.
ha_ssh_rollback_reload() {

    if ha_ssh_reload; then
        ha_task_result "${HA_TASK_COMPLETED}" \
            "sshd reloaded with the previous configuration."
    else
        ha_task_result "${HA_TASK_ERROR}" \
            "Files restored, but sshd could not be reloaded."
    fi
}
