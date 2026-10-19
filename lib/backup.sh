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
