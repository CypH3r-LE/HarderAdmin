#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/checks/system.sh
# ==============================================================================
#

# Supported: Debian, Ubuntu and derivatives (ID_LIKE contains debian).
ha_check_os() {

    local id
    local id_like

    id="$(ha_os_release_get ID)" || return 1
    id_like="$(ha_os_release_get ID_LIKE)" || true

    case " ${id} ${id_like} " in
        *" debian "*|*" ubuntu "*)
            return 0
            ;;
    esac

    return 1
}


ha_get_os_name() {

    local name

    name="$(ha_os_release_get PRETTY_NAME 2>/dev/null)" || true

    printf "%s" "${name:-unknown}"
}


ha_check_kernel() {

    local kernel

    kernel="$(uname -r)"

    [[ -n "${kernel}" ]]
}

ha_check_hostname() {

    local hostname

    hostname="$(hostname)"

    [[ -n "${hostname}" ]]
}


ha_check_architecture() {

    local architecture

    architecture="$(uname -m)"

    [[ -n "${architecture}" ]]
}


# A default route is a reliable offline check. ICMP (ping) is often blocked
# on servers and would report false negatives.
ha_check_network() {

    if ha_command_exists ip; then
        [[ -n "$(ip route show default 2>/dev/null)" \
            || -n "$(ip -6 route show default 2>/dev/null)" ]]
        return
    fi

    [[ -r /proc/net/route ]] \
        && awk 'NR > 1 && $2 == "00000000" { found = 1 } END { exit !found }' \
            /proc/net/route
}


ha_check_apt() {

    ha_command_exists apt-get
}


ha_check_systemd() {

    [[ -d /run/systemd/system ]] && ha_command_exists systemctl
}


ha_system_reboot_required() {

    [[ -f /var/run/reboot-required ]]
}


ha_get_hostname() {

    hostname
}


ha_get_architecture() {

    uname -m
}


ha_get_kernel() {

    uname -r
}
