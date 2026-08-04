#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# modules/system_hardening.sh
# ==============================================================================
#


ha_module_system_hardening_menu() {

    local choice

    while true; do

        clear

        ha_draw_header

        ha_ui_section "System Hardening"


        ha_ui_menu_item 1 "System updates"
        ha_ui_menu_item 2 "Automatic security updates"
        ha_ui_menu_item 3 "Remove unused packages"
        ha_ui_menu_item 4 "Kernel hardening"
        ha_ui_menu_item 5 "Review services"

        echo

        ha_ui_menu_item 0 "Back"

        echo

        read -rp "Select: " choice


        case "${choice}" in

            1)
                ha_task_execute "SYS-001"
                ;;

            2)
                ha_ui_info "Automatic updates module not implemented yet."
                ha_pause
                ;;

            3)
                ha_ui_info "Package cleanup module not implemented yet."
                ha_pause
                ;;

            4)
                ha_ui_info "Kernel hardening module not implemented yet."
                ha_pause
                ;;

            5)
                ha_ui_info "Service review module not implemented yet."
                ha_pause
                ;;

            0)
                return 0
                ;;

            *)
                ha_status_fail "Invalid selection."
                ha_pause
                ;;

        esac

    done
}