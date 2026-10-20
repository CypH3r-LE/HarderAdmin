#!/usr/bin/env bash
#
# ==============================================================================
# HarderAdmin
# lib/cli.sh
# ==============================================================================
#

HA_VERSION="$(head -n 1 "${HA_ROOT_DIR}/VERSION" 2>/dev/null || true)"
HA_VERSION="${HA_VERSION:-dev}"
readonly HA_VERSION

# shellcheck disable=SC2034 # used in harderadmin.sh
HA_CLI_MODE="interactive"
# shellcheck disable=SC2034 # used in harderadmin.sh
HA_CLI_ARGUMENT=""


ha_cli_usage() {

    cat <<EOF
HarderAdmin ${HA_VERSION} - Server Hardening Suite for Linux

Usage: harderadmin [OPTION]

Without options the interactive menu starts.

Options:
  -a, --audit     Run all task checks (read-only) and print a report.
                  Exit code: 0 = compliant, 1 = findings, 2 = errors
  -r, --rollback TASK-ID
                  Roll back the last run of a task (restore its backups),
                  e.g. after a lockout from the console:
                  harderadmin --rollback SSH-002
  -h, --help      Show this help.
  -V, --version   Show the version.

Environment:
  NO_COLOR=1      Disable colored output.
EOF
}


ha_cli_parse() {

    while (( $# > 0 )); do

        case "$1" in

            -a|--audit)
                # shellcheck disable=SC2034
                HA_CLI_MODE="audit"
                ;;

            -r|--rollback)
                if [[ -z "${2:-}" ]]; then
                    printf "Option %s needs a task ID.\n" "$1" >&2
                    exit 64
                fi
                # shellcheck disable=SC2034
                HA_CLI_MODE="rollback"
                # shellcheck disable=SC2034
                HA_CLI_ARGUMENT="$2"
                shift
                ;;

            -h|--help)
                ha_cli_usage
                exit 0
                ;;

            -V|--version)
                printf "HarderAdmin %s\n" "${HA_VERSION}"
                exit 0
                ;;

            *)
                printf "Unknown option: %s\n\n" "$1" >&2
                ha_cli_usage >&2
                exit 64
                ;;

        esac

        shift

    done
}
