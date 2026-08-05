#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/task_runner.sh
# ==============================================================================
#

ha_task_execute() {

    local id="$1"
    local execute_function
    local info_function
    local check_function
    local check_status
    local execute_status
    local verify_function
    local verify_status


    check_function="$(ha_task_get_check "${id}")"

    if [[ -n "${check_function}" ]]; then

        if "${check_function}"; then
            check_status=0
        else
            check_status=$?
        fi

    fi


    case "${check_status}" in

        "${HA_TASK_COMPLETED}")
            ha_status_ok "$(ha_task_get_message)"
            ha_pause
            return 0
            ;;

        "${HA_TASK_BLOCKED}")
            ha_status_fail "$(ha_task_get_message)"
            ha_pause
            return 1
            ;;

        "${HA_TASK_ERROR}")
            ha_status_fail "$(ha_task_get_message)"
            ha_pause
            return 1
            ;;

    esac


    info_function="$(ha_task_get_info "${id}")"

    if [[ -n "${info_function}" ]]; then

        "${info_function}"

        echo

    fi


    if ! ha_ui_confirm "Execute task"; then
        return 0
    fi


    execute_function="$(ha_task_get_execute "${id}")"

    if "${execute_function}"; then
    execute_status=0
else
    execute_status=$?
fi


case "${execute_status}" in

    "${HA_TASK_COMPLETED}")
    ha_status_ok "$(ha_task_get_message)"

    verify_function="$(ha_task_get_verify "${id}")"

    if [[ -n "${verify_function}" ]]; then

        if "${verify_function}"; then
            verify_status=0
        else
            verify_status=$?
        fi


        case "${verify_status}" in

            "${HA_TASK_COMPLETED}")
                ha_status_ok "$(ha_task_get_message)"
                ;;

            "${HA_TASK_ERROR}")
                ha_status_fail "$(ha_task_get_message)"
                ;;

        esac

    fi

    ;;

esac


ha_pause
}