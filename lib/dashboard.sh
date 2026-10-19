#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/dashboard.sh
# ==============================================================================
#

ha_dashboard_show_status() {

    ha_ui_section "System Status"


    if ha_check_root; then
        ha_status_ok "Root privileges"
    else
        ha_status_fail "Running without root privileges"
    fi


    if ha_check_os; then
        ha_status_ok "Supported system: $(ha_get_os_name)"
    else
        ha_status_fail "Unsupported operating system: $(ha_get_os_name)"
    fi


    if ha_check_kernel; then
        ha_status_ok "Kernel $(ha_get_kernel) ($(ha_get_architecture))"
    else
        ha_status_warning "Kernel information unavailable"
    fi

    if ha_check_hostname; then
        ha_status_ok "Hostname: $(ha_get_hostname)"
    else
        ha_status_warning "Hostname unavailable"
    fi


    if ha_check_network; then
        ha_status_ok "Default route available"
    else
        ha_status_warning "No default route (offline?)"
    fi


    if ha_check_apt; then
        ha_status_ok "APT package manager available"
    else
        ha_status_fail "APT unavailable"
    fi


    if ha_check_systemd; then
        ha_status_ok "systemd available"
    else
        ha_status_warning "systemd not running (container?)"
    fi


    if ha_check_config; then
        ha_status_ok "Configuration loaded"
    else
        ha_status_warning "Configuration missing, defaults in use"
    fi


    if ha_check_logging; then
        ha_status_ok "Logging to ${HA_LOG_FILE}"
    else
        ha_status_warning "Logging to file unavailable"
    fi


    if ha_check_backup; then
        ha_status_ok "Backups enabled: ${BACKUP_DIR}"
    else
        ha_status_warning "Backups disabled - rollback is not possible"
    fi


    if ha_system_reboot_required; then
        ha_status_warning "System reboot pending"
    fi
}


ha_dashboard_start() {

    ha_draw_header

    ha_dashboard_show_status

    echo

    ha_menu_main
}
