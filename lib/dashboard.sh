#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# dashboard.sh
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
        ha_status_ok "Ubuntu system detected"
    else
        ha_status_fail "Unsupported operating system"
    fi


    if ha_check_kernel; then
        ha_status_ok "Kernel available"
    else
        ha_status_warning "Kernel information unavailable"
    fi

    if ha_check_hostname; then
        ha_status_ok "Hostname available"
    else
        ha_status_warning "Hostname unavailable"
    fi


    if ha_check_architecture; then
        ha_status_ok "Architecture detected"
    else
        ha_status_warning "Architecture unavailable"
    fi


    if ha_check_network; then
        ha_status_ok "Network reachable"
    else
        ha_status_fail "Network unavailable"
    fi


    if ha_check_apt; then
        ha_status_ok "APT package manager available"
    else
        ha_status_fail "APT unavailable"
    fi


    if ha_check_config; then
        ha_status_ok "Configuration loaded"
    else
        ha_status_fail "Configuration missing"
    fi


    if ha_check_logging; then
        ha_status_ok "Logging active"
    else
        ha_status_warning "No log file created yet"
    fi
}


ha_dashboard_start() {

    clear

    ha_draw_header
    
    echo

    ha_dashboard_show_status

    echo

    ha_menu_main
}