#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# task_runner.sh
# ==============================================================================
#
ha_task_execute() {

    local id="$1"

    if [[ -z "${HA_TASK_EXECUTE[$id]:-}" ]]; then

        ha_status_fail "Task '${id}' is not registered."

        return 1

    fi

    "$(ha_task_get_execute "${id}")"
}