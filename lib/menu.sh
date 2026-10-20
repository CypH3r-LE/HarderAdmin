#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/menu.sh
# ==============================================================================
#
# The menu is generated from the task registry: a task appears in the menu of
# the category it registers with. New modules only need task files.
#
#   "<Category>:<Menu title>"
# ------------------------------------------------------------------------------

readonly HA_MENU_CATEGORIES=(
    "System:System Hardening"
    "SSH:SSH Security"
    "Firewall:Firewall"
    "Fail2Ban:Fail2Ban"
)


ha_menu_main() {

    local choice
    local entry
    local index
    local count="${#HA_MENU_CATEGORIES[@]}"

    while true; do

        ha_ui_section "Main Menu"

        index=1

        for entry in "${HA_MENU_CATEGORIES[@]}"; do

            ha_ui_menu_item "${index}" "$(ha_menu_category_label "${entry}")"
            index=$(( index + 1 ))

        done

        ha_ui_menu_item "$(( count + 1 ))" "Backups / Rollback"
        ha_ui_menu_item "$(( count + 2 ))" "Reports (audit all tasks)"

        echo

        ha_ui_menu_item 0 "Exit"

        echo

        ha_ui_read_choice choice

        if [[ "${choice}" == "0" ]]; then
            ha_log_info "HarderAdmin terminated."
            exit 0
        fi

        if [[ ! "${choice}" =~ ^[0-9]{1,3}$ ]]; then
            ha_status_fail "Invalid selection."
            ha_pause
            continue
        fi

        choice=$(( 10#${choice} ))

        if (( choice >= 1 && choice <= count )); then

            entry="${HA_MENU_CATEGORIES[$(( choice - 1 ))]}"
            ha_menu_category "${entry%%:*}" "${entry#*:}"

        elif (( choice == count + 1 )); then

            ha_menu_backups

        elif (( choice == count + 2 )); then

            ha_task_audit_report || true
            ha_pause

        else

            ha_status_fail "Invalid selection."
            ha_pause

        fi

    done
}


# "SSH Security (4 tasks)" or "Firewall (planned)"
ha_menu_category_label() {

    local entry="$1"
    local count

    count="$(ha_task_get_by_category "${entry%%:*}" | grep -c . || true)"

    if (( count == 0 )); then
        printf "%s (planned)" "${entry#*:}"
    else
        printf "%s (%d tasks)" "${entry#*:}" "${count}"
    fi
}


ha_menu_category() {

    local category="$1"
    local title="$2"
    local choice
    local task_ids=()
    local task_id
    local index

    while true; do

        ha_draw_header

        ha_ui_section "${title}"

        task_ids=()

        while IFS= read -r task_id; do

            if [[ -n "${task_id}" ]]; then
                task_ids+=("${task_id}")
            fi

        done < <(ha_task_get_by_category "${category}")

        if (( ${#task_ids[@]} == 0 )); then
            ha_ui_info "No tasks available yet."
        fi

        index=1

        for task_id in "${task_ids[@]+"${task_ids[@]}"}"; do

            ha_ui_menu_item \
                "${index}" \
                "${task_id} - $(ha_task_get_name "${task_id}")"

            index=$(( index + 1 ))

        done

        echo

        ha_ui_menu_item 0 "Back"

        echo

        ha_ui_read_choice choice

        if [[ "${choice}" == "0" ]]; then
            return 0
        fi

        # 10# forces base 10: "08" would otherwise be an invalid octal number.
        if [[ "${choice}" =~ ^[0-9]{1,3}$ ]] \
            && (( 10#${choice} >= 1 && 10#${choice} <= ${#task_ids[@]} )); then

            ha_task_execute "${task_ids[$(( 10#${choice} - 1 ))]}" || true

        else

            ha_status_fail "Invalid selection."
            ha_pause

        fi

    done
}


# Lists the backup sessions (newest first) and rolls back a selected one.
ha_menu_backups() {

    local choice
    local sessions=()
    local line
    local id
    local session
    local index
    local state
    local max=20

    while true; do

        ha_draw_header

        ha_ui_section "Backups / Rollback"

        if ! ha_backup_enabled; then
            ha_ui_warning "Backups are disabled (BACKUP_ENABLED)."
        fi

        ha_ui_info "Backup directory: ${BACKUP_DIR}"
        ha_ui_info "Rolling back restores the files as they were BEFORE that task run."
        echo

        sessions=()

        while IFS= read -r line; do

            if [[ -n "${line}" ]]; then
                sessions+=("${line}")
            fi

            if (( ${#sessions[@]} >= max )); then
                break
            fi

        done < <(ha_backup_list_sessions)

        if (( ${#sessions[@]} == 0 )); then
            ha_ui_info "No backups yet."
        fi

        index=1

        for line in "${sessions[@]+"${sessions[@]}"}"; do

            id="${line%%$'\t'*}"
            session="${line#*$'\t'}"
            state=""

            if [[ -f "${session}/rolled_back" ]]; then
                state=" (rolled back $(head -n 1 "${session}/rolled_back"))"
            fi

            ha_ui_menu_item "${index}" \
                "${id} - $(basename -- "${session}") - $(grep -c . "${session}/manifest") file(s)${state}"

            index=$(( index + 1 ))

        done

        echo
        ha_ui_menu_item 0 "Back"
        echo

        ha_ui_read_choice choice

        if [[ "${choice}" == "0" ]]; then
            return 0
        fi

        if [[ "${choice}" =~ ^[0-9]{1,3}$ ]] \
            && (( 10#${choice} >= 1 && 10#${choice} <= ${#sessions[@]} )); then

            line="${sessions[$(( 10#${choice} - 1 ))]}"
            session="${line#*$'\t'}"

            echo
            ha_ui_info "Files in this backup:"
            cut -f2 "${session}/manifest" | sed 's/^/    /'
            echo

            if ha_ui_confirm "Roll back ${line%%$'\t'*} to this state"; then
                ha_task_rollback_target "${session}" || true
            fi

            ha_pause

        else

            ha_status_fail "Invalid selection."
            ha_pause

        fi

    done
}
