#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/task_runner.sh
# ==============================================================================
#
# Interactive flow of a task:
#
#   check ─┬─ COMPLETED ──► ask "execute again?"
#          ├─ BLOCKED / ERROR / NOT_APPLICABLE ──► show message, stop
#          └─ READY
#   info ──► confirm ──► execute ──► verify ─┬─ COMPLETED ──► done
#                           │                 └─ ERROR ──► correction ──► verify
#                           └─ ERROR ──────────────────────► offer rollback
#
# ha_task_execute always returns 0 so a failed task never terminates the menu.
# ------------------------------------------------------------------------------

# Runs a task function and guarantees a defined status afterwards.
# The function is called in a condition, so "set -e" cannot abort the program
# from inside a task.
ha_task_run_function() {

    local function_name="$1"
    local exit_code=0

    HA_TASK_STATUS=""
    HA_TASK_MESSAGE=""

    if [[ -z "${function_name}" ]]; then
        ha_task_result "${HA_TASK_COMPLETED}" ""
        return 0
    fi

    if ! declare -F "${function_name}" >/dev/null; then
        ha_task_result "${HA_TASK_ERROR}" \
            "Task function not found: ${function_name}"
        return 0
    fi

    "${function_name}" || exit_code=$?

    if [[ -z "${HA_TASK_STATUS}" ]]; then

        if (( exit_code != 0 )); then
            ha_task_result "${HA_TASK_ERROR}" \
                "${function_name} failed (exit code ${exit_code})."
        else
            ha_task_result "${HA_TASK_ERROR}" \
                "${function_name} did not report a status."
        fi

    fi

    return 0
}


# Prints the current status message with the matching icon.
ha_task_report_status() {

    local message

    message="$(ha_task_get_message)"

    case "${HA_TASK_STATUS}" in

        "${HA_TASK_COMPLETED}")
            ha_status_ok "${message}"
            ;;

        "${HA_TASK_READY}")
            ha_status_info "${message}"
            ;;

        "${HA_TASK_NOT_APPLICABLE}")
            ha_status_warning "Not applicable: ${message}"
            ;;

        *)
            ha_status_fail "${message}"
            ;;

    esac
}


ha_task_log_status() {

    local id="$1"
    local phase="$2"

    ha_log_info "[${id}] ${phase}: $(ha_task_status_name "${HA_TASK_STATUS}") - ${HA_TASK_MESSAGE}"
}


# Runs a phase (check, execute, ...) of a task, reports and logs the result.
ha_task_run_phase() {

    local id="$1"
    local phase="$2"
    local function_name

    case "${phase}" in
        check)      function_name="$(ha_task_get_check "${id}")" ;;
        info)       function_name="$(ha_task_get_info "${id}")" ;;
        execute)    function_name="$(ha_task_get_execute "${id}")" ;;
        verify)     function_name="$(ha_task_get_verify "${id}")" ;;
        correction) function_name="$(ha_task_get_correction "${id}")" ;;
        rollback)   function_name="$(ha_task_get_rollback "${id}")" ;;
        *)
            ha_task_result "${HA_TASK_ERROR}" "Unknown task phase: ${phase}"
            return 0
            ;;
    esac

    ha_task_run_function "${function_name}"

    ha_task_log_status "${id}" "${phase}"
}


ha_task_execute() {

    local id="$1"
    local execute_confirmed=false
    local info_function

    if ! ha_task_exists "${id}"; then
        ha_status_fail "Unknown task: ${id}"
        ha_pause
        return 0
    fi

    ha_task_clear_context "${id}"

    ha_ui_task_header "${id}" "$(ha_task_get_name "${id}")"
    ha_status_info "$(ha_task_get_description "${id}")"
    echo

    # --- check ----------------------------------------------------------------

    ha_task_run_phase "${id}" check

    case "${HA_TASK_STATUS}" in

        "${HA_TASK_READY}")
            ;;

        "${HA_TASK_COMPLETED}")
            ha_task_report_status

            if ! ha_ui_confirm "Execute task again"; then
                return 0
            fi

            execute_confirmed=true
            ;;

        *)
            ha_task_report_status
            ha_pause
            return 0
            ;;

    esac

    # --- info -----------------------------------------------------------------

    # Called directly (not via ha_task_run_function) so the info function can
    # still read the message of the check.
    info_function="$(ha_task_get_info "${id}")"

    if [[ -n "${info_function}" ]]; then

        "${info_function}" || true
        echo

    fi

    if [[ "${execute_confirmed}" != true ]] \
        && ! ha_ui_confirm "Execute task"; then
        return 0
    fi

    # --- execute --------------------------------------------------------------

    ha_backup_begin "${id}"

    ha_log_info "[${id}] Execution started."

    ha_task_run_phase "${id}" execute
    ha_task_report_status

    if [[ "${HA_TASK_STATUS}" != "${HA_TASK_COMPLETED}" ]]; then
        ha_task_offer_rollback "${id}"
        ha_pause
        return 0
    fi

    # --- verify / correction --------------------------------------------------

    if [[ -n "$(ha_task_get_verify "${id}")" ]]; then

        ha_task_run_phase "${id}" verify
        ha_task_report_status

        if [[ "${HA_TASK_STATUS}" != "${HA_TASK_COMPLETED}" ]]; then

            if [[ -n "$(ha_task_get_correction "${id}")" ]] \
                && ha_ui_confirm "Apply correction"; then

                ha_task_run_phase "${id}" correction
                ha_task_report_status

                if [[ "${HA_TASK_STATUS}" == "${HA_TASK_COMPLETED}" ]]; then
                    ha_task_run_phase "${id}" verify
                    ha_task_report_status
                fi

            fi

            if [[ "${HA_TASK_STATUS}" != "${HA_TASK_COMPLETED}" ]]; then
                ha_task_offer_rollback "${id}"
            fi

        fi

    fi

    ha_task_reboot_hint "${id}"

    ha_pause
}


# Restores the files of the current backup session and runs the task's
# rollback hook. Only offered if there is something to roll back.
ha_task_offer_rollback() {

    local id="$1"
    local rollback_function

    rollback_function="$(ha_task_get_rollback "${id}")"

    if ! ha_backup_session_has_files && [[ -z "${rollback_function}" ]]; then
        return 0
    fi

    echo

    if ! ha_ui_confirm "Roll back changes of ${id}"; then
        ha_log_warn "[${id}] Rollback declined by user."
        return 0
    fi

    ha_task_rollback "${id}"
}


ha_task_rollback() {

    local id="$1"
    local restore_ok=true

    if ha_backup_session_has_files; then

        if ha_backup_restore_session; then
            ha_status_ok "Backed-up files restored."
        else
            restore_ok=false
            ha_status_fail "Some files could not be restored. See log."
        fi

    fi

    ha_task_run_phase "${id}" rollback
    ha_task_report_status

    if [[ "${restore_ok}" != true ]]; then
        ha_task_set_status "${HA_TASK_ERROR}"
    fi
}


ha_task_run_correction() {

    ha_task_run_phase "$1" correction
}


ha_task_reboot_hint() {

    local id="$1"

    if [[ "$(ha_task_get_reboot "${id}")" == "false" ]]; then
        return 0
    fi

    if ha_system_reboot_required; then
        echo
        ha_status_warning "A system reboot is required to complete the changes."
    fi
}


# ------------------------------------------------------------------------------
# Audit: run every check (read-only) and print a report.
#
# Exit codes: 0 = all compliant, 1 = findings (READY), 2 = errors/blocked
# ------------------------------------------------------------------------------

ha_task_audit_report() {

    local id
    local status_name
    local color
    local result=0
    local count_ok=0
    local count_ready=0
    local count_error=0
    local count_na=0

    ha_ui_section "HarderAdmin Audit - $(hostname) - $(date '+%Y-%m-%d %H:%M')"

    while IFS= read -r id; do

        [[ -n "${id}" ]] || continue

        ha_task_clear_context "${id}"
        ha_task_run_phase "${id}" check

        status_name="$(ha_task_status_name "${HA_TASK_STATUS}")"

        case "${HA_TASK_STATUS}" in
            "${HA_TASK_COMPLETED}")
                color="${HA_COLOR_GREEN}"
                count_ok=$(( count_ok + 1 ))
                ;;
            "${HA_TASK_READY}")
                color="${HA_COLOR_YELLOW}"
                count_ready=$(( count_ready + 1 ))
                (( result >= 1 )) || result=1
                ;;
            "${HA_TASK_NOT_APPLICABLE}")
                color="${HA_COLOR_BLUE}"
                count_na=$(( count_na + 1 ))
                ;;
            *)
                color="${HA_COLOR_RED}"
                count_error=$(( count_error + 1 ))
                result=2
                ;;
        esac

        printf "%-8s %b%-8s%b %-30s %s\n" \
            "${id}" \
            "${color}" "${status_name}" "${HA_COLOR_RESET}" \
            "$(ha_task_get_name "${id}")" \
            "${HA_TASK_MESSAGE}"

    done < <(ha_task_get_all)

    ha_ui_line
    printf "OK: %d   Findings: %d   Errors/Blocked: %d   N/A: %d\n" \
        "${count_ok}" "${count_ready}" "${count_error}" "${count_na}"

    if ha_system_reboot_required; then
        ha_status_warning "A system reboot is pending."
    fi

    ha_log_info "Audit finished: ok=${count_ok} findings=${count_ready} errors=${count_error} na=${count_na}"

    return "${result}"
}
