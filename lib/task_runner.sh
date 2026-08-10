#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/task_runner.sh
# ==============================================================================
#

ha_task_run_function() {

    local function_name="$1"

    HA_TASK_STATUS=""

    "${function_name}"

}

ha_task_execute() {

    local id="$1"
    local execute_function
    local info_function
    local check_function
    local verify_function
    local correction_function
    local execute_confirmed=false

    check_function="$(ha_task_get_check "${id}")"
    
if [[ -n "${check_function}" ]]; then

    ha_task_run_function "${check_function}"

fi


    case "${HA_TASK_STATUS}" in

        "${HA_TASK_COMPLETED}")
            ha_status_ok "$(ha_task_get_message)"

            if ! ha_ui_confirm "Execute task again"; then
                ha_pause
                return 0
            fi

            execute_confirmed=true
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

        ha_task_run_function "${info_function}"

        echo

    fi


    if [[ "${execute_confirmed}" != true ]]; then

        if ! ha_ui_confirm "Execute task"; then
            return 0
        fi

    fi


execute_function="$(ha_task_get_execute "${id}")"

ha_task_run_function "${execute_function}"

case "${HA_TASK_STATUS}" in

    "${HA_TASK_COMPLETED}")
        ha_status_ok "$(ha_task_get_message)"
        ;;

    "${HA_TASK_ERROR}")
        ha_status_fail "$(ha_task_get_message)"
        ha_pause
        return 0
        ;;

esac


verify_function="$(ha_task_get_verify "${id}")"

if [[ -n "${verify_function}" ]]; then

    ha_task_run_function "${verify_function}"

    case "${HA_TASK_STATUS}" in

        "${HA_TASK_COMPLETED}")
            ha_status_ok "$(ha_task_get_message)"
            ;;

        "${HA_TASK_ERROR}")
            ha_status_fail "$(ha_task_get_message)"

            correction_function="$(ha_task_get_correction "${id}")"

            if [[ -n "${correction_function}" ]] \
                && ha_ui_confirm "Apply correction"; then

                ha_task_run_correction "${id}"

                case "${HA_TASK_STATUS}" in

                    "${HA_TASK_COMPLETED}")
                        ha_status_ok "$(ha_task_get_message)"

                        verify_function="$(ha_task_get_verify "${id}")"

                        if [[ -n "${verify_function}" ]]; then

                            ha_task_run_function "${verify_function}"

                            case "${HA_TASK_STATUS}" in

                                "${HA_TASK_COMPLETED}")
                                    ha_status_ok "$(ha_task_get_message)"
                                    ;;

                                "${HA_TASK_ERROR}")
                                    ha_status_fail "$(ha_task_get_message)"
                                    ;;

                            esac

                        fi
                        ;;

                    "${HA_TASK_ERROR}")
                        ha_status_fail "$(ha_task_get_message)"
                        ;;

                esac

            fi
            ;;

    esac

fi

    ha_pause
}

ha_task_run_correction() {

    local id="$1"
    local correction_function

    correction_function="$(ha_task_get_correction "${id}")"

    if [[ -z "${correction_function}" ]]; then

        ha_task_set_status "${HA_TASK_COMPLETED}"
        ha_task_set_message "No correction available."

        return 0

    fi

    ha_task_run_function "${correction_function}"

}