#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/menu.sh
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
        ha_ui_menu_item 6 "Reports (audit all tasks)"

        echo

        ha_ui_menu_item 0 "Exit"

        echo

        ha_ui_read_choice choice

        case "${choice}" in

            1)
                ha_module_system_hardening_menu
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
                ha_ui_info "Backups are stored in ${BACKUP_DIR}."
                ha_pause
                ;;

            6)
                ha_task_audit_report || true
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
