#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/task_registry.sh
# ==============================================================================
#
# Task contract
# -------------
# check       Determine the current state. Must NOT change the system.
#             Sets READY, COMPLETED, BLOCKED, ERROR or NOT_APPLICABLE.
# info        Print details before execution (optional).
# execute     Apply the change. Call ha_backup_file before modifying a file.
# verify      Check the result of execute. Sets COMPLETED or ERROR.
# rollback    Hook that runs AFTER the runner restored the backed-up files
#             (reload services, revert runtime values, remove created users).
#             Optional.
# correction  Repair a failed verification (optional).
#
# Task functions run with "set -e" disabled (they are called in a condition),
# so every command whose failure matters must be checked explicitly.
# Every function except info must set a status via ha_task_set_status.
# ------------------------------------------------------------------------------

declare -ag HA_TASK_IDS=()
declare -Ag HA_TASK_NAME=()
declare -Ag HA_TASK_CATEGORY=()
declare -Ag HA_TASK_DESCRIPTION=()
declare -Ag HA_TASK_INTERACTIVE=()
declare -Ag HA_TASK_REBOOT=()
declare -Ag HA_TASK_DEFAULT=()
declare -Ag HA_TASK_EXECUTE=()
declare -Ag HA_TASK_CHECK=()
declare -Ag HA_TASK_INFO=()
declare -Ag HA_TASK_VERIFY=()
declare -Ag HA_TASK_ROLLBACK=()
declare -Ag HA_TASK_CORRECTION=()

ha_task_register() {

    local id="$1"
    local name="$2"
    local category="$3"
    local description="$4"
    local interactive="$5"
    local reboot="$6"
    local default="$7"
    local check_function="$8"
    local info_function="$9"
    local execute_function="${10}"
    local verify_function="${11}"
    local rollback_function="${12:-}"
    local correction_function="${13:-}"
    local function_name

    if [[ ! "${id}" =~ ^[A-Z]{2,6}-[0-9]{3}$ ]]; then
        printf "ERROR: Invalid task ID: %s\n" "${id}" >&2
        return 1
    fi

    if ha_task_exists "${id}"; then
        printf "ERROR: Duplicate task ID: %s\n" "${id}" >&2
        return 1
    fi

    if [[ -z "${check_function}" || -z "${execute_function}" ]]; then
        printf "ERROR: Task %s needs a check and an execute function.\n" \
            "${id}" >&2
        return 1
    fi

    for function_name in \
        "${check_function}" \
        "${info_function}" \
        "${execute_function}" \
        "${verify_function}" \
        "${rollback_function}" \
        "${correction_function}"
    do

        if [[ -n "${function_name}" ]] \
            && ! declare -F "${function_name}" >/dev/null; then
            printf "ERROR: Task %s: function not defined: %s\n" \
                "${id}" "${function_name}" >&2
            return 1
        fi

    done

    HA_TASK_IDS+=("${id}")

    HA_TASK_NAME["${id}"]="${name}"
    HA_TASK_CATEGORY["${id}"]="${category}"
    HA_TASK_DESCRIPTION["${id}"]="${description}"
    HA_TASK_INTERACTIVE["${id}"]="${interactive}"
    HA_TASK_REBOOT["${id}"]="${reboot}"
    # shellcheck disable=SC2034 # reserved: default selection for batch runs
    HA_TASK_DEFAULT["${id}"]="${default}"

    HA_TASK_CHECK["${id}"]="${check_function}"
    HA_TASK_INFO["${id}"]="${info_function}"
    HA_TASK_EXECUTE["${id}"]="${execute_function}"
    HA_TASK_VERIFY["${id}"]="${verify_function}"
    HA_TASK_ROLLBACK["${id}"]="${rollback_function}"
    HA_TASK_CORRECTION["${id}"]="${correction_function}"
}

#------------------------------------------------------------------------------
#Task State
#------------------------------------------------------------------------------

HA_TASK_MESSAGE=""
HA_TASK_STATUS=""
declare -Ag HA_TASK_CONTEXT=()

ha_task_set_message() {

    HA_TASK_MESSAGE="$1"

}


ha_task_get_message() {

    printf "%s" "${HA_TASK_MESSAGE}"

}

ha_task_set_status() {

    HA_TASK_STATUS="$1"

}


ha_task_get_status() {

    printf "%s" "${HA_TASK_STATUS}"

}

# Convenience: set status and message in one call.
ha_task_result() {

    ha_task_set_status "$1"
    ha_task_set_message "$2"

}

ha_task_status_name() {

    case "${1:-}" in
        "${HA_TASK_READY}")          printf "READY" ;;
        "${HA_TASK_COMPLETED}")      printf "OK" ;;
        "${HA_TASK_BLOCKED}")        printf "BLOCKED" ;;
        "${HA_TASK_ERROR}")          printf "ERROR" ;;
        "${HA_TASK_NOT_APPLICABLE}") printf "N/A" ;;
        *)                           printf "UNKNOWN" ;;
    esac

}

ha_task_set_context() {

    local id="$1"
    local key="$2"
    local value="$3"

    HA_TASK_CONTEXT["${id}:${key}"]="${value}"

}


ha_task_get_context() {

    local id="$1"
    local key="$2"

    printf "%s" "${HA_TASK_CONTEXT["${id}:${key}"]:-}"

}


ha_task_clear_context() {

    local id="$1"
    local key

    for key in "${!HA_TASK_CONTEXT[@]}"; do

        if [[ "${key}" == "${id}:"* ]]; then

            unset 'HA_TASK_CONTEXT[$key]'

        fi

    done

}

# ------------------------------------------------------------------------------
# Task Getter
# ------------------------------------------------------------------------------

ha_task_exists() {

    local id="${1:-}"

    [[ "${id}" =~ ^[A-Z]{2,6}-[0-9]{3}$ && -v "HA_TASK_NAME[${id}]" ]]

}


ha_task_get_name() {

    printf "%s" "${HA_TASK_NAME[${1}]:-}"

}


ha_task_get_category() {

    printf "%s" "${HA_TASK_CATEGORY[${1}]:-}"

}


ha_task_get_description() {

    printf "%s" "${HA_TASK_DESCRIPTION[${1}]:-}"

}


ha_task_get_interactive() {

    printf "%s" "${HA_TASK_INTERACTIVE[${1}]:-false}"

}


ha_task_get_reboot() {

    printf "%s" "${HA_TASK_REBOOT[${1}]:-}"

}


ha_task_get_execute() {

    printf "%s" "${HA_TASK_EXECUTE[${1}]:-}"

}


ha_task_get_check() {

    printf "%s" "${HA_TASK_CHECK[${1}]:-}"

}


ha_task_get_info() {

    printf "%s" "${HA_TASK_INFO[${1}]:-}"

}


ha_task_get_verify() {

    printf "%s" "${HA_TASK_VERIFY[${1}]:-}"

}


ha_task_get_rollback() {

    printf "%s" "${HA_TASK_ROLLBACK[${1}]:-}"

}

ha_task_get_correction() {

    printf "%s" "${HA_TASK_CORRECTION[${1}]:-}"

}


ha_task_get_by_category() {

    local category="$1"
    local id

    for id in "${HA_TASK_IDS[@]+"${HA_TASK_IDS[@]}"}"; do

        if [[ "${HA_TASK_CATEGORY[${id}]}" == "${category}" ]]; then

            printf "%s\n" "${id}"

        fi

    done | sort -V
}


ha_task_get_all() {

    (( ${#HA_TASK_IDS[@]} > 0 )) || return 0

    printf "%s\n" "${HA_TASK_IDS[@]}" | sort -V
}
