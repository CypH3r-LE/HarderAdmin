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

    info_function="$(ha_task_get_info "${id}")"

    if [[ -n "${info_function}" ]]; then

        "${info_function}"

        echo

    fi

    if ! ha_ui_confirm "Execute task"; then
        return 0
    fi

    execute_function="$(ha_task_get_execute "${id}")"

    "${execute_function}"
}