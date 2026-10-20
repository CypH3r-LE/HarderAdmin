#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/common.sh
# ==============================================================================

ha_init() {

    if [[ ${EUID} -ne 0 ]]; then
        ha_ui_error "HarderAdmin must be run as root." >&2
        exit 1
    fi

    if ! ha_config_load; then
        ha_ui_error "Unable to load configuration: ${HA_CONFIG_FILE}" >&2
        exit 1
    fi

    ha_logger_init "${LOG_DIR}" "${LOG_LEVEL}"

    ha_log_debug "Configuration loaded."
}


ha_pause() {

    local _ha_pause_answer

    echo
    ha_ui_read _ha_pause_answer "Press ENTER to continue..." || true
}


# clear fails without a usable TERM (cron, "ssh host cmd", containers).
ha_clear() {

    if [[ -t 1 ]]; then
        clear 2>/dev/null || printf "\033[H\033[2J"
    fi
}


ha_command_exists() {

    command -v "$1" >/dev/null 2>&1
}


# True if a TCP port is in LISTEN state (IPv4 or IPv6).
ha_port_listening() {

    local port="$1"
    local hex

    if ha_command_exists ss; then
        [[ -n "$(ss -H -tln "sport = :${port}" 2>/dev/null)" ]]
        return
    fi

    local files=()
    local file

    printf -v hex "%04X" "${port}"

    # /proc/net/tcp6 is missing when IPv6 is disabled.
    for file in /proc/net/tcp /proc/net/tcp6; do
        [[ -r "${file}" ]] && files+=("${file}")
    done

    (( ${#files[@]} > 0 )) || return 1

    awk -v port=":${hex}" '
        FNR > 1 && $4 == "0A" && substr($2, length($2) - 4) == port { found = 1 }
        END { exit !found }
    ' "${files[@]}"
}


# ha_wait_for <seconds> <command...>: retries a command once per second.
ha_wait_for() {

    local seconds="$1"
    shift

    while (( seconds-- > 0 )); do
        "$@" && return 0
        sleep 1
    done

    "$@"
}


ha_ufw_active() {

    ha_command_exists ufw \
        && LC_ALL=C ufw status 2>/dev/null | grep -q '^Status: active'
}


# apt-get without prompts: keeps existing config files on conflicts and waits
# for a running apt/unattended-upgrades instead of failing on the lock.
ha_apt_get() {

    DEBIAN_FRONTEND=noninteractive apt-get \
        -o DPkg::Lock::Timeout=300 \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold \
        "$@"
}


ha_package_installed() {

    [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" \
        == "install ok installed" ]]
}


# Reads one field of /etc/os-release without polluting the global scope.
ha_os_release_get() {

    local key="$1"

    [[ -r /etc/os-release ]] || return 1

    (
        # shellcheck disable=SC1091
        source /etc/os-release
        printf "%s" "${!key:-}"
    )
}


ha_draw_header() {

    ha_clear

    printf "%b" "${HA_COLOR_CYAN}"

cat << "EOF"

__/\\\________/\\\_____/\\\\\\\\\_______/\\\\\\\\\______/\\\\\\\\\\\\_____/\\\\\\\\\\\\\\\____/\\\\\\\\\_____        
 _\/\\\_______\/\\\___/\\\\\\\\\\\\\___/\\\///////\\\___\/\\\////////\\\__\/\\\///////////___/\\\///////\\\___       
  _\/\\\_______\/\\\__/\\\/////////\\\_\/\\\_____\/\\\___\/\\\______\//\\\_\/\\\_____________\/\\\_____\/\\\___      
   _\/\\\\\\\\\\\\\\\_\/\\\_______\/\\\_\/\\\\\\\\\\\/____\/\\\_______\/\\\_\/\\\\\\\\\\\_____\/\\\\\\\\\\\/____     
    _\/\\\/////////\\\_\/\\\\\\\\\\\\\\\_\/\\\//////\\\____\/\\\_______\/\\\_\/\\\///////______\/\\\//////\\\____    
     _\/\\\_______\/\\\_\/\\\/////////\\\_\/\\\____\//\\\___\/\\\_______\/\\\_\/\\\_____________\/\\\____\//\\\___   
      _\/\\\_______\/\\\_\/\\\_______\/\\\_\/\\\_____\//\\\__\/\\\_______/\\\__\/\\\_____________\/\\\_____\//\\\__  
       _\/\\\_______\/\\\_\/\\\_______\/\\\_\/\\\______\//\\\_\/\\\\\\\\\\\\/___\/\\\\\\\\\\\\\\\_\/\\\______\//\\\_ 
        _\///________\///__\///________\///__\///________\///__\////////////_____\///////////////__\///________\///__

EOF

    printf "%bHarderAdmin %s%b\n" \
        "${HA_COLOR_WHITE}" \
        "${HA_VERSION}" \
        "${HA_COLOR_RESET}"

    printf "%bServer Hardening Suite for Linux%b\n\n" \
        "${HA_COLOR_MAGENTA}" \
        "${HA_COLOR_RESET}"
}
