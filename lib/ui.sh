#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/ui.sh
# ==============================================================================
#

# ------------------------------------------------------------------------------
# Messages (aliases for lib/status.sh, kept for readability in tasks)
# ------------------------------------------------------------------------------

ha_ui_info() {
    ha_status_info "$1"
}

ha_ui_success() {
    ha_status_ok "$1"
}

ha_ui_warning() {
    ha_status_warning "$1"
}

ha_ui_error() {
    ha_status_fail "$1"
}


# ------------------------------------------------------------------------------
# Input
#
# All reads tolerate EOF (closed stdin, Ctrl+D) instead of aborting the
# program through "set -e".
# ------------------------------------------------------------------------------

# ha_ui_read <variable> <prompt>
# Returns 1 on EOF.
ha_ui_read() {

    local -n _ha_ui_read_target="$1"
    local prompt="$2"

    _ha_ui_read_target=""

    if ! IFS= read -r -p "${prompt}" _ha_ui_read_target; then
        echo
        return 1
    fi

    return 0
}


# Reads a menu choice. Exits HarderAdmin cleanly on EOF.
ha_ui_read_choice() {

    local -n _ha_ui_choice_target="$1"

    if ! ha_ui_read _ha_ui_choice_target "Select: "; then
        ha_log_info "Input closed (EOF). HarderAdmin terminated."
        exit 0
    fi
}


ha_ui_confirm() {

    local prompt="$1"
    local answer

    while true; do

        if ! ha_ui_read answer "${prompt} [y/N]: "; then
            return 1
        fi

        case "${answer}" in

            [Yy]|[Yy][Ee][Ss]|[Jj]|[Jj][Aa])
                return 0
                ;;

            ""|[Nn]|[Nn][Oo]|[Nn][Ee][Ii][Nn])
                return 1
                ;;

            *)
                ha_status_fail "Please answer yes or no."
                ;;
        esac

    done
}


# ------------------------------------------------------------------------------
# Layout
# ------------------------------------------------------------------------------

ha_ui_task_header() {

    local id="$1"
    local name="$2"

    ha_ui_section "Task"

    printf "%s - %s\n\n" "${id}" "${name}"
}

# shellcheck disable=SC2120
ha_ui_line() {

    local width="${1:-60}"

    printf "%*s\n" "${width}" "" | tr " " "-"
}


ha_ui_title() {

    local title="$1"

    echo
    printf "%b%s%b\n" \
        "${HA_COLOR_CYAN}" \
        "${title}" \
        "${HA_COLOR_RESET}"

    ha_ui_line
}

ha_ui_menu_item() {

    local number="$1"
    local text="$2"

    printf "%b[%s]%b %s\n" \
        "${HA_COLOR_CYAN}" \
        "${number}" \
        "${HA_COLOR_RESET}" \
        "${text}"
}


ha_ui_section() {

    local title="$1"

    echo
    printf "%b%s%b\n" \
        "${HA_COLOR_WHITE}" \
        "${title}" \
        "${HA_COLOR_RESET}"

    ha_ui_line
}
