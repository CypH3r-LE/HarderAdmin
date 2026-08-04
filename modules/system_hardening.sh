#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# modules/system_hardening.sh
# ==============================================================================
#


ha_module_system_hardening_menu() {

    local choice
    local task_ids=()
    local task_id
    local index

    while true; do

        clear

        ha_draw_header

        ha_ui_section "System Hardening"


        task_ids=()

        while IFS= read -r task_id; do

            task_ids+=("${task_id}")

        done < <(ha_task_get_by_category "System")


        index=1

        for task_id in "${task_ids[@]}"; do

            ha_ui_menu_item \
                "${index}" \
                "${task_id} - $(ha_task_get_name "${task_id}")"

            ((index++))

        done

        echo

        ha_ui_menu_item 0 "Back"

        echo

        read -rp "Select: " choice


        if [[ "${choice}" == "0" ]]; then

            return 0

        fi


        if [[ "${choice}" =~ ^[0-9]+$ ]] \
            && (( choice >= 1 && choice <= ${#task_ids[@]} )); then

            ha_task_execute "${task_ids[$((choice-1))]}"

        else

            ha_status_fail "Invalid selection."

            ha_pause

        fi

    done
}