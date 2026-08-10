#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/task_registry.sh
# ==============================================================================
#

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
    local rollback_function="${12}"
    local correction_function="${13:-}"

    HA_TASK_IDS+=("${id}")

    HA_TASK_NAME["${id}"]="${name}"
    HA_TASK_CATEGORY["${id}"]="${category}"
    HA_TASK_DESCRIPTION["${id}"]="${description}"
    # shellcheck disable=SC2034
    HA_TASK_INTERACTIVE["${id}"]="${interactive}"

    # shellcheck disable=SC2034
    HA_TASK_REBOOT["${id}"]="${reboot}"

    # shellcheck disable=SC2034
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

ha_task_get_name() {

    local id="$1"

    printf "%s" "${HA_TASK_NAME[$id]}"

}


ha_task_get_category() {

    local id="$1"

    printf "%s" "${HA_TASK_CATEGORY[$id]}"

}


ha_task_get_description() {

    local id="$1"

    printf "%s" "${HA_TASK_DESCRIPTION[$id]}"

}


ha_task_get_execute() {

    local id="$1"

    printf "%s" "${HA_TASK_EXECUTE[$id]}"

}


ha_task_get_check() {

    local id="$1"

    printf "%s" "${HA_TASK_CHECK[$id]}"

}


ha_task_get_info() {

    local id="$1"

    printf "%s" "${HA_TASK_INFO[$id]}"

}


ha_task_get_verify() {

    local id="$1"

    printf "%s" "${HA_TASK_VERIFY[$id]}"

}


ha_task_get_rollback() {

    local id="$1"

    printf "%s" "${HA_TASK_ROLLBACK[$id]}"

}

ha_task_get_correction() {

    local id="$1"

    printf "%s" "${HA_TASK_CORRECTION[$id]}"

}


ha_task_get_by_category() {

    local category="$1"
    local id

    for id in "${HA_TASK_IDS[@]}"; do

        if [[ "${HA_TASK_CATEGORY[$id]}" == "${category}" ]]; then

            printf "%s\n" "${id}"

        fi

    done | sort -V
}