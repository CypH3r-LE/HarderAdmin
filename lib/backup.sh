#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/backup.sh
# ==============================================================================
#
# Backups are grouped in sessions: one session per task execution.
#
#   ${BACKUP_DIR}/<TASK-ID>/<YYYYmmdd-HHMMSS>/
#       manifest        one line per file: "<state>\t<absolute path>"
#                       state "present" = file existed and was copied
#                       state "absent"  = file did not exist (rollback deletes it)
#       files/...       copies with their original path below files/
#
# Tasks call ha_backup_file before changing a file. The task runner restores
# the current session when the user chooses to roll back.
# ------------------------------------------------------------------------------

HA_BACKUP_TASK_ID=""
HA_BACKUP_SESSION_DIR=""


ha_backup_enabled() {

    [[ "${BACKUP_ENABLED:-false}" == "true" ]]
}


# Start a new (lazy) session. The directory is created on the first backup.
ha_backup_begin() {

    HA_BACKUP_TASK_ID="$1"
    HA_BACKUP_SESSION_DIR=""
}


ha_backup_session_create() {

    local session

    session="${BACKUP_DIR}/${HA_BACKUP_TASK_ID}/$(date '+%Y%m%d-%H%M%S')"

    # Two sessions in the same second: append a counter.
    if [[ -e "${session}" ]]; then
        local counter=1
        while [[ -e "${session}-${counter}" ]]; do
            counter=$(( counter + 1 ))
        done
        session="${session}-${counter}"
    fi

    if ! install -d -m 0700 -- "${session}/files"; then
        return 1
    fi

    : > "${session}/manifest"
    chmod 0600 -- "${session}/manifest"

    HA_BACKUP_SESSION_DIR="${session}"
}


ha_backup_session_has_files() {

    [[ -n "${HA_BACKUP_SESSION_DIR}" \
        && -s "${HA_BACKUP_SESSION_DIR}/manifest" ]]
}


# ha_backup_file <absolute path>
# Returns 0 if the file was backed up (or backups are disabled), 1 on error.
ha_backup_file() {

    local path="$1"

    if ! ha_backup_enabled; then
        return 0
    fi

    if [[ -z "${HA_BACKUP_TASK_ID}" ]]; then
        ha_log_error "ha_backup_file called outside of a task session: ${path}"
        return 1
    fi

    if [[ "${path}" != /* || "${path}" == *$'\n'* || "${path}" == *$'\t'* ]]; then
        ha_log_error "Refusing to back up invalid path: ${path}"
        return 1
    fi

    if [[ -z "${HA_BACKUP_SESSION_DIR}" ]]; then
        ha_backup_session_create || return 1
    fi

    # Only the first (original) state of a file matters in a session.
    if grep -qxF \
        -e "present"$'\t'"${path}" \
        -e "absent"$'\t'"${path}" \
        "${HA_BACKUP_SESSION_DIR}/manifest"; then
        return 0
    fi

    if [[ -e "${path}" || -L "${path}" ]]; then

        if ! cp -a --parents -- "${path}" "${HA_BACKUP_SESSION_DIR}/files/"; then
            ha_log_error "Backup failed: ${path}"
            return 1
        fi

        printf "present\t%s\n" "${path}" >> "${HA_BACKUP_SESSION_DIR}/manifest"

    else

        printf "absent\t%s\n" "${path}" >> "${HA_BACKUP_SESSION_DIR}/manifest"

    fi

    ha_log_debug "Backup [${HA_BACKUP_TASK_ID}]: ${path}"
}


# Restores all files of the current session.
ha_backup_restore_session() {

    local session="${1:-${HA_BACKUP_SESSION_DIR}}"
    local state
    local path
    local failed=0

    if [[ -z "${session}" || ! -f "${session}/manifest" ]]; then
        ha_log_warn "No backup session to restore."
        return 1
    fi

    while IFS=$'\t' read -r state path; do

        case "${state}" in

            present)
                if cp -a -- "${session}/files${path}" "${path}"; then
                    ha_log_change "${HA_BACKUP_TASK_ID}" "Restored ${path}"
                else
                    ha_log_error "Restore failed: ${path}"
                    failed=1
                fi
                ;;

            absent)
                if rm -f -- "${path}"; then
                    ha_log_change "${HA_BACKUP_TASK_ID}" "Removed ${path} (did not exist before)"
                else
                    ha_log_error "Unable to remove: ${path}"
                    failed=1
                fi
                ;;

        esac

    done < "${session}/manifest"

    return "${failed}"
}


# ------------------------------------------------------------------------------
# Task context persistence
#
# The context of a task run (e.g. old sysctl values, created user, previous
# SSH service mode) is stored in the session as "<key>\t<value>" lines, so a
# rollback in a new process (timer, --rollback, Backups menu) can use it.
# ------------------------------------------------------------------------------

ha_backup_save_context() {

    local id="$1"
    local context_key
    local key
    local value
    local file

    if [[ -z "${HA_BACKUP_SESSION_DIR}" ]]; then
        return 0
    fi

    file="${HA_BACKUP_SESSION_DIR}/context"

    {
        for context_key in "${!HA_TASK_CONTEXT[@]}"; do

            [[ "${context_key}" == "${id}:"* ]] || continue

            key="${context_key#"${id}:"}"
            value="${HA_TASK_CONTEXT[${context_key}]}"

            if [[ ! "${key}" =~ ^[A-Za-z0-9_.:/-]+$ \
                || "${value}" == *$'\n'* || "${value}" == *$'\t'* ]]; then
                ha_log_warn "[${id}] Context entry not saved: ${key}"
                continue
            fi

            printf "%s\t%s\n" "${key}" "${value}"

        done
    } > "${file}" || return 1

    chmod 0600 -- "${file}"
}


ha_backup_load_context() {

    local id="$1"
    local session="$2"
    local key
    local value

    ha_task_clear_context "${id}"

    [[ -f "${session}/context" ]] || return 0

    while IFS=$'\t' read -r key value; do

        [[ "${key}" =~ ^[A-Za-z0-9_.:/-]+$ ]] || continue

        ha_task_set_context "${id}" "${key}" "${value}"

    done < "${session}/context"
}


# ------------------------------------------------------------------------------
# Session lookup
# ------------------------------------------------------------------------------

# Prints the newest session directory of a task.
ha_backup_latest_session() {

    local id="$1"

    [[ -d "${BACKUP_DIR}/${id}" ]] || return 1

    find "${BACKUP_DIR}/${id}" -mindepth 1 -maxdepth 1 -type d \
        -exec test -f '{}/manifest' ';' -print 2>/dev/null \
        | sort | tail -n 1 | grep . || return 1
}


# Prints all sessions as "<task id>\t<session dir>", newest first.
ha_backup_list_sessions() {

    local dir

    [[ -d "${BACKUP_DIR}" ]] || return 0

    while IFS= read -r dir; do

        printf "%s\t%s\n" "$(basename -- "$(dirname -- "${dir}")")" "${dir}"

    done < <(
        find "${BACKUP_DIR}" -mindepth 2 -maxdepth 2 -type d \
            -exec test -f '{}/manifest' ';' -print 2>/dev/null \
            | awk -F/ '{ print $NF "\t" $0 }' | sort -r | cut -f2-
    )
}


# ha_backup_use_session <session dir>
# Validates that the directory is a session below BACKUP_DIR and makes it the
# current session (HA_BACKUP_SESSION_DIR, HA_BACKUP_TASK_ID).
# Do not call in a command substitution: it sets globals.
ha_backup_use_session() {

    local session="$1"
    local real_session
    local real_base
    local id

    real_session="$(readlink -f -- "${session}" 2>/dev/null)" || return 1
    real_base="$(readlink -f -- "${BACKUP_DIR}" 2>/dev/null)" || return 1

    if [[ "${real_session}" != "${real_base}/"*/* \
        || ! -f "${real_session}/manifest" ]]; then
        ha_log_error "Not a backup session: ${session}"
        return 1
    fi

    id="$(basename -- "$(dirname -- "${real_session}")")"

    if [[ ! "${id}" =~ ^[A-Z]{2,6}-[0-9]{3}$ ]]; then
        ha_log_error "Invalid task ID in backup path: ${session}"
        return 1
    fi

    HA_BACKUP_TASK_ID="${id}"
    HA_BACKUP_SESSION_DIR="${real_session}"
}
