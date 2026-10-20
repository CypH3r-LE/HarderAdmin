#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/guard.sh
# ==============================================================================
#
# Lockout guard for changes that can cut off remote access (SSH, firewall).
#
#   1. Before the change is activated, a systemd timer is armed that runs
#      "harderadmin.sh --rollback <backup session>" after GUARD_TIMEOUT seconds.
#   2. The change is activated (e.g. sshd reload).
#   3. The admin tests access in a NEW session and confirms with "yes".
#   4. Confirmed  -> timer is stopped, change stays.
#      No answer  -> rollback runs now (if this session still works) or by the
#                    timer (if the connection is lost).
#
# The rollback uses the same code as the menu: restore the backed-up files,
# then run the task's rollback hook with the saved task context.
# ------------------------------------------------------------------------------

readonly HA_GUARD_UNIT="harderadmin-revert"

HA_GUARD_ARMED=false
# shellcheck disable=SC2034 # read by lib/task_runner.sh
HA_GUARD_REVERTED=false


ha_guard_available() {

    ha_check_systemd && ha_command_exists systemd-run
}


ha_guard_timeout() {

    printf "%s" "${GUARD_TIMEOUT:-180}"
}


# Stops a leftover timer from an earlier, interrupted run.
ha_guard_reset() {

    systemctl stop "${HA_GUARD_UNIT}.timer" >/dev/null 2>&1 || true
    systemctl reset-failed "${HA_GUARD_UNIT}.service" >/dev/null 2>&1 || true

    HA_GUARD_ARMED=false
    HA_GUARD_REVERTED=false
}


# ha_guard_arm <task id>
# Requires an active backup session with the files that will be changed.
ha_guard_arm() {

    local id="$1"
    local timeout

    timeout="$(ha_guard_timeout)"

    HA_GUARD_ARMED=false
    HA_GUARD_REVERTED=false

    if [[ -z "${HA_BACKUP_SESSION_DIR}" ]]; then
        ha_log_error "[${id}] Guard: no backup session, cannot arm."
        return 1
    fi

    # The rollback runs in a new process and needs the task context.
    ha_backup_save_context "${id}" || return 1

    if ! ha_guard_available; then
        return 1
    fi

    ha_guard_reset

    if ! systemd-run --quiet \
        --unit="${HA_GUARD_UNIT}" \
        --description="HarderAdmin automatic rollback (${id})" \
        --on-active="${timeout}s" \
        --setenv=SUDO_USER="${SUDO_USER:-}" \
        --setenv=NO_COLOR=1 \
        /bin/bash "${HA_ROOT_DIR}/harderadmin.sh" --rollback "${HA_BACKUP_SESSION_DIR}" \
        >/dev/null 2>&1; then
        ha_log_error "[${id}] Guard: systemd-run failed."
        return 1
    fi

    HA_GUARD_ARMED=true
    ha_log_info "[${id}] Guard armed: automatic rollback in ${timeout}s (${HA_BACKUP_SESSION_DIR})."
}


# Returns 0 if the timer was stopped before it fired.
ha_guard_disarm() {

    local id="$1"

    if [[ "${HA_GUARD_ARMED}" != true ]]; then
        return 0
    fi

    HA_GUARD_ARMED=false

    if ! systemctl is-active --quiet "${HA_GUARD_UNIT}.timer" 2>/dev/null; then
        ha_log_warn "[${id}] Guard: timer already fired, rollback has run."
        HA_GUARD_REVERTED=true
        return 1
    fi

    systemctl stop "${HA_GUARD_UNIT}.timer" >/dev/null 2>&1 || true
    ha_log_info "[${id}] Guard disarmed: change confirmed."
}


# Rolls back now (in this process) and makes sure the timer cannot run it
# a second time.
ha_guard_revert_now() {

    local id="$1"

    if [[ "${HA_GUARD_ARMED}" == true ]]; then
        systemctl stop "${HA_GUARD_UNIT}.timer" >/dev/null 2>&1 || true
        HA_GUARD_ARMED=false
    fi

    ha_log_warn "[${id}] Guard: rolling back."

    ha_task_rollback "${id}"

    HA_GUARD_REVERTED=true
}


# ha_guard_run <task id> <activate function> <test hint>
#
# Arms the guard, calls the activate function and waits for the admin to
# confirm that access still works. Sets the task status:
#   COMPLETED -> change confirmed
#   ERROR     -> change rolled back
ha_guard_run() {

    local id="$1"
    local activate_function="$2"
    local test_hint="$3"
    local timeout
    local answer=""
    local wait_seconds

    timeout="$(ha_guard_timeout)"

    if ha_guard_arm "${id}"; then

        ha_ui_info "Safety net: changes are rolled back automatically in ${timeout} seconds"
        ha_ui_info "unless you confirm them (timer ${HA_GUARD_UNIT}.timer)."

    else

        ha_ui_warning "No automatic rollback available (systemd-run missing or failed)."
        ha_ui_warning "If this connection breaks, you need console access to recover:"
        ha_ui_warning "  sudo bash ${HA_ROOT_DIR}/harderadmin.sh --rollback ${id}"

        if ! ha_ui_confirm "Continue without safety net"; then
            ha_guard_abort "${id}"
            return 0
        fi

    fi

    # --- activate -------------------------------------------------------------

    ha_task_run_function "${activate_function}"

    if [[ "${HA_TASK_STATUS}" != "${HA_TASK_COMPLETED}" ]]; then
        local message="${HA_TASK_MESSAGE}"
        ha_status_fail "${message}"
        ha_guard_revert_now "${id}"
        ha_task_result "${HA_TASK_ERROR}" "${message} Changes were rolled back."
        return 0
    fi

    # --- confirm --------------------------------------------------------------

    echo
    ha_status_warning "Keep THIS session open."
    ha_status_warning "${test_hint}"
    echo

    # Leave a margin so we never answer after the timer already fired.
    wait_seconds=$(( timeout - 15 ))

    if ! IFS= read -r -t "${wait_seconds}" \
        -p "Type 'yes' within ${wait_seconds}s to keep the changes: " answer; then
        echo
        answer=""
    fi

    case "${answer}" in

        [Yy][Ee][Ss]|[Jj][Aa])
            if ha_guard_disarm "${id}"; then
                ha_task_result "${HA_TASK_COMPLETED}" "Change confirmed and kept."
            else
                ha_task_result "${HA_TASK_ERROR}" \
                    "Confirmation came too late; changes were rolled back by the timer."
            fi
            ;;

        *)
            ha_guard_revert_now "${id}"
            ha_task_result "${HA_TASK_ERROR}" "Not confirmed; changes were rolled back."
            ;;

    esac
}


# Abort before activation: restore files, nothing was activated yet.
ha_guard_abort() {

    local id="$1"

    if ha_backup_session_has_files; then
        ha_backup_restore_session || true
    fi

    # shellcheck disable=SC2034 # read by lib/task_runner.sh
    HA_GUARD_REVERTED=true

    ha_log_warn "[${id}] Aborted before activation; files restored."
    ha_task_result "${HA_TASK_ERROR}" "Aborted; configuration files restored."
}
