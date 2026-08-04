#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# loader.sh
# ==============================================================================
#

HA_LIB_DIR="${HA_ROOT_DIR}/lib"
HA_MODULE_DIR="${HA_ROOT_DIR}/modules"
HA_TASK_DIR="${HA_ROOT_DIR}/tasks"

readonly HA_LIB_DIR
readonly HA_MODULE_DIR
readonly HA_TASK_DIR


ha_load_library() {

    local library="$1"
    echo "DEBUG loading: ${library}"
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
        "task_registry.sh"
        task_runner.sh
        "checks.sh"
        "dashboard.sh"
        "menu.sh"
    )

    local library

    for library in "${libraries[@]}"; do
        ha_load_library "${library}"
    done
}

ha_load_checks() {

    local checks_dir="${HA_LIB_DIR}/checks"

    if [[ ! -d "${checks_dir}" ]]; then
        return 0
    fi


    local check_file

    for check_file in "${checks_dir}"/*.sh; do

        if [[ -f "${check_file}" ]]; then

            # shellcheck disable=SC1090
            source "${check_file}"

        fi

    done
}

ha_load_modules() {

    local module_dir="${HA_MODULE_DIR}"

    if [[ ! -d "${module_dir}" ]]; then
        return 0
    fi


    local module

    for module in "${module_dir}"/*.sh; do

        if [[ -f "${module}" ]]; then

            # shellcheck disable=SC1090
            source "${module}"

        fi

    done
}

ha_load_tasks() {

    if [[ ! -d "${HA_TASK_DIR}" ]]; then
        return 0
    fi

    local task

    while IFS= read -r -d '' task; do

        # shellcheck disable=SC1090
        source "${task}"

    done < <(find "${HA_TASK_DIR}" -type f -name "*.sh" -print0)

}