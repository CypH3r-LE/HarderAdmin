#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# ui.sh
# ==============================================================================
#

ha_ui_info() {
    printf "%b%s%b %s\n" \
        "${HA_COLOR_BLUE}" \
        "${HA_ICON_INFO}" \
        "${HA_COLOR_RESET}" \
        "$1"
}

ha_ui_success() {
    printf "%b%s%b %s\n" \
        "${HA_COLOR_GREEN}" \
        "${HA_ICON_OK}" \
        "${HA_COLOR_RESET}" \
        "$1"
}

ha_ui_warning() {
    printf "%b%s%b %s\n" \
        "${HA_COLOR_YELLOW}" \
        "${HA_ICON_WARN}" \
        "${HA_COLOR_RESET}" \
        "$1"
}

ha_ui_error() {
    printf "%b%s%b %s\n" \
        "${HA_COLOR_RED}" \
        "${HA_ICON_FAIL}" \
        "${HA_COLOR_RESET}" \
        "$1"
}

ha_ui_confirm() {

    local prompt="$1"
    local answer

    while true; do

        read -rp "${prompt} [y/N]: " answer

        case "${answer}" in

            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;

            ""|[Nn]|[Nn][Oo])
                return 1
                ;;

            *)
                ha_status_fail "Please answer yes or no."
                ;;
        esac

    done
}

ha_ui_task_header() {

    local id="$1"
    local name="$2"

    ha_ui_section "Task"

    printf "%s - %s\n\n" "${id}" "${name}"
}

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