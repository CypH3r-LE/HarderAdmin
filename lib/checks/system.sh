#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/checks/system.sh
# ==============================================================================
#


ha_check_os() {

    if [[ -f /etc/os-release ]]; then

        # shellcheck disable=SC1091
        source /etc/os-release

        if [[ "${ID}" == "ubuntu" ]]; then
            return 0
        fi

    fi

    return 1
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


ha_check_network() {

    ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1
}


ha_check_apt() {

    [[ -x "/usr/bin/apt" ]]
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