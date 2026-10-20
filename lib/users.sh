#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/users.sh
# ==============================================================================
#
# Helpers for administrative users and their SSH keys.
# Used by SYS-003 and the SSH tasks (lockout prevention).
# ------------------------------------------------------------------------------

readonly HA_ADMIN_GROUPS=("sudo" "wheel" "admin")


# Prints the admin group of this distribution (sudo on Debian/Ubuntu).
ha_admin_group() {

    local group

    for group in "${HA_ADMIN_GROUPS[@]}"; do

        if getent group "${group}" >/dev/null 2>&1; then
            printf "%s" "${group}"
            return 0
        fi

    done

    return 1
}


# Prints all non-root members (supplementary and primary) of a group.
ha_group_members() {

    local group="$1"
    local entry
    local gid
    local members

    entry="$(getent group "${group}" 2>/dev/null)" || return 0

    gid="$(cut -d: -f3 <<< "${entry}")"
    members="$(cut -d: -f4 <<< "${entry}")"

    {
        tr ',' '\n' <<< "${members}"
        getent passwd | awk -F: -v gid="${gid}" '$4 == gid { print $1 }'
    } | grep -vx -e '' -e 'root' | sort -u || true
}


# Prints all non-root administrators, one per line.
ha_admin_users() {

    local group

    group="$(ha_admin_group)" || return 0

    ha_group_members "${group}"
}


ha_user_home() {

    getent passwd "$1" | cut -d: -f6
}


# True if the user has at least one public key in ~/.ssh/authorized_keys.
ha_user_has_ssh_key() {

    local home

    home="$(ha_user_home "$1")"

    [[ -n "${home}" && -f "${home}/.ssh/authorized_keys" ]] \
        && grep -Eq '^[[:space:]]*[^#[:space:]]' "${home}/.ssh/authorized_keys"
}


# True if the account can log in with a password (not locked, not empty).
ha_user_has_password() {

    local state

    state="$(passwd -S -- "$1" 2>/dev/null | awk '{ print $2 }')" || return 1

    [[ "${state}" == "P" ]]
}


# Prints all administrators that have an SSH key, one per line.
ha_admin_users_with_key() {

    local user

    while IFS= read -r user; do

        [[ -n "${user}" ]] || continue

        if ha_user_has_ssh_key "${user}"; then
            printf "%s\n" "${user}"
        fi

    done < <(ha_admin_users)
}


# The admin who started HarderAdmin via sudo (empty if logged in as root).
ha_invoking_user() {

    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        printf "%s" "${SUDO_USER}"
    fi
}
