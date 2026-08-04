#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# loader.sh
# ==============================================================================
#

HA_LIB_DIR="${HA_ROOT_DIR}/lib"
HA_MODULE_DIR="${HA_ROOT_DIR}/modules"

readonly HA_LIB_DIR
readonly HA_MODULE_DIR


ha_load_library() {

    local library="$1"

    if [[ ! -f "${HA_LIB_DIR}/${library}" ]]; then
        printf "%s\n" "Missing library: ${library}" >&2
        exit 1
    fi

    # shellcheck disable=SC1090
    source "${HA_LIB_DIR}/${library}"
}


ha_load_libraries() {

    local libraries=(
        "colors.sh"
        "logger.sh"
        "ui.sh"
        "common.sh"
        "config.sh"
        "status.sh"
    )

    local library

    for library in "${libraries[@]}"; do
        ha_load_library "${library}"
    done
}


ha_load_modules() {

    if [[ ! -d "${HA_MODULE_DIR}" ]]; then
        return 0
    fi

    # Module loader placeholder
    # Will be implemented in a later sprint.

    return 0
}