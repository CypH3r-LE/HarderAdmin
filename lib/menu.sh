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

        ha_ui_section "Main Menu"

        ha_ui_menu_item 1 "System Hardening"
        ha_ui_menu_item 2 "SSH Security"
        ha_ui_menu_item 3 "Firewall"
        ha_ui_menu_item 4 "Fail2Ban"
        ha_ui_menu_item 5 "Backups"
        ha_ui_menu_item 6 "Reports"

        echo

        ha_ui_menu_item 0 "Exit"

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