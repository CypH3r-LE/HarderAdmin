#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# common.sh
# ==============================================================================

ha_init() {

    if [[ $EUID -ne 0 ]]; then
        ha_log_error "HarderAdmin must be run as root."
        exit 1
    fi
}

ha_pause() {

    echo
    read -rp "Press ENTER to continue..."
}

ha_draw_header() {

    clear

    printf "%b" "${HA_COLOR_CYAN}"

cat << "EOF"

██╗  ██╗ █████╗ ██████╗ ██████╗ ███████╗██████╗
██║  ██║██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
███████║███████║██████╔╝██║  ██║█████╗  ██████╔╝
██╔══██║██╔══██║██╔══██╗██║  ██║██╔══╝  ██╔══██╗
██║  ██║██║  ██║██║  ██║██████╔╝███████╗██║  ██║
╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝

EOF

    printf "%bHarderAdmin%b\n" \
        "${HA_COLOR_WHITE}" \
        "${HA_COLOR_RESET}"

    printf "%bServer Hardening Suite for Linux%b\n\n" \
        "${HA_COLOR_MAGENTA}" \
        "${HA_COLOR_RESET}"
}