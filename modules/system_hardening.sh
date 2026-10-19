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

        ha_draw_header

        ha_ui_section "System Hardening"


        task_ids=()

        while IFS= read -r task_id; do

            if [[ -n "${task_id}" ]]; then
                task_ids+=("${task_id}")
            fi

        done < <(ha_task_get_by_category "System")


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
