#!/usr/bin/env bash

set -euo pipefail
#########################
#COMMAND LINE INTERFACE
#########################

readonly JONGO_BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."
source "${JONGO_BASE_DIR}/bin/lib/common/mvn-tools.sh"
source "${JONGO_BASE_DIR}/bin/lib/common/git-tools.sh"
source "${JONGO_BASE_DIR}/bin/lib/common/gpg-tools.sh"
source "${JONGO_BASE_DIR}/bin/lib/common/logger.sh"
source "${JONGO_BASE_DIR}/bin/lib/release/tasks.sh"

function __main() {

    local dry_run=true
    local dirty=false
    local debug=false
    local task=()

    while [[ $# -gt 0 ]]
    do
    key="$1"
    case $key in
        -b|--branch)
            local -r target_branch="$2"
            shift
            shift
        ;;
        #Optional
        -t|--tag)
            local -r tag="$2"
            shift
            shift
        ;;
        -g|--gpg-file)
            log_info "Importing gpg file ${2} into keyring..."
            local -r gpg_key_id=$(import_gpg "${2}")
            shift
            shift
        ;;
        -s|--settings-file)
            append_maven_options "--settings ${2}"
            shift
            shift
        ;;
        -s|--settings-security)
            append_maven_options "-Dsettings.security=${2}"
            shift
            shift
        ;;
        --dirty)
            readonly dirty=true
            shift
        ;;
        --debug)
            set -x
            readonly debug=true
            shift
        ;;
        -d|--dry-run)
            readonly dry_run="$2"
            shift
            shift
        ;;
        *)
        task+=("$1")
        shift
        ;;
    esac
    done
    set -- "${task[@]}"

    local repo_dir=$(clone_repository "https://github.com/bguerout/jongo.git")
    [[ "${dry_run}" = true ]] &&  append_maven_options "-P test" &&  update_origin_with_fake_remote "${repo_dir}" && log_warn "Script is running in dry mode"
    [[ "${debug}" = false ]] &&  append_maven_options "--quiet"
    [[ "${dirty}" = false ]] && trap clean_resources EXIT || log_warn "Dirty mode activated."

    pushd "${repo_dir}" > /dev/null

        log_info "***************************************************************************************"
        log_info "* Running task ${task} with parameters:"
        log_info "*   Dry mode:       '${dry_run}'"
        log_info "*   Maven options:  '$(get_maven_options)'"
        log_info "*   Target branch:  '${target_branch}'"
        log_info "*   GPG key branch: '${gpg_key_id:-none}'"
        log_info "*   Repository:     '${repo_dir}'"
        log_info "***************************************************************************************"

        case "${task}" in
            RELEASE_EARLY)
                create_early_release "${target_branch}"
            ;;
            RELEASE)
                create_release "${target_branch}"
            ;;
            RELEASE_HOTFIX)
                create_hotfix_release "${target_branch}"
            ;;
            DEPLOY)
                deploy "${tag}" "${gpg_key_id}"
            ;;
            TEST)
                test_app "${target_branch}"
            ;;
            TEST_RELEASE_FLOW)
                source "${JONGO_BASE_DIR}/bin/lib/test/test-tasks.sh"
                run_test_suite "${target_branch}"
            ;;
            *)
             log_error "Unknown task ${task}"
             exit 1;
            ;;
        esac
    popd > /dev/null
}

__main "$@"