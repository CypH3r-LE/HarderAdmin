#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/loader.sh
# ==============================================================================
#

HA_LIB_DIR="${HA_ROOT_DIR}/lib"
HA_MODULE_DIR="${HA_ROOT_DIR}/modules"
HA_TASK_DIR="${HA_ROOT_DIR}/tasks"

readonly HA_LIB_DIR
readonly HA_MODULE_DIR
readonly HA_TASK_DIR


# ------------------------------------------------------------------------------
# Source a file after checking that it can be trusted.
# ------------------------------------------------------------------------------

ha_load_file() {

    local file="$1"

    if [[ ! -f "${file}" ]]; then
        printf "ERROR: Missing file: %s\n" "${file}" >&2
        exit 1
    fi

    if ! ha_trust_check_file "${file}"; then
        exit 1
    fi

    # shellcheck disable=SC1090
    source "${file}"
}


ha_load_library() {

    ha_load_file "${HA_LIB_DIR}/$1"
}


ha_load_libraries() {

    local libraries=(
        "colors.sh"
        "logger.sh"
        "status.sh"
        "ui.sh"
        "common.sh"
        "config.sh"
        "backup.sh"
        "task_registry.sh"
        "task_runner.sh"
        "checks.sh"
        "dashboard.sh"
        "menu.sh"
        "cli.sh"
    )

    local library

    for library in "${libraries[@]}"; do
        ha_load_library "${library}"
    done
}


# ------------------------------------------------------------------------------
# Source all *.sh files of a directory tree in a stable, sorted order.
# ------------------------------------------------------------------------------

ha_load_directory() {

    local directory="$1"
    local file

    if [[ ! -d "${directory}" ]]; then
        return 0
    fi

    ha_trust_check_path "${directory}" || exit 1

    while IFS= read -r -d '' file; do

        ha_load_file "${file}"

    done < <(find "${directory}" -type f -name "*.sh" -print0 | sort -z)
}


ha_load_checks() {

    ha_load_directory "${HA_LIB_DIR}/checks"
}


ha_load_modules() {

    ha_load_directory "${HA_MODULE_DIR}"
}


ha_load_tasks() {

    ha_load_directory "${HA_TASK_DIR}"
}
