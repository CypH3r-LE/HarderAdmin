#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# menu.sh
# ==============================================================================
#

ha_menu_main() {

    local choice

    while true; do

        clear

        ha_draw_header

        echo

        printf "%bMain Menu%b\n\n" \
            "${HA_COLOR_WHITE}" \
            "${HA_COLOR_RESET}"

        echo "[1] System Hardening"
        echo "[2] SSH Security"
        echo "[3] Firewall"
        echo "[4] Fail2Ban"
        echo "[5] Backups"
        echo "[6] Reports"
        echo
        echo "[0] Exit"
        echo

        read -rp "Select: " choice

        case "${choice}" in

            1)
                ha_ui_info "System Hardening module not available yet."
                ha_pause
                ;;

            2)
                ha_ui_info "SSH module not available yet."
                ha_pause
                ;;

            3)
                ha_ui_info "Firewall module not available yet."
                ha_pause
                ;;

            4)
                ha_ui_info "Fail2Ban module not available yet."
                ha_pause
                ;;

            5)
                ha_ui_info "Backup module not available yet."
                ha_pause
                ;;

            6)
                ha_ui_info "Reports module not available yet."
                ha_pause
                ;;

            0)
                ha_log_info "HarderAdmin terminated."
                exit 0
                ;;

            *)
                ha_status_fail "Invalid selection."
                ha_pause
                ;;

        esac

    done
}