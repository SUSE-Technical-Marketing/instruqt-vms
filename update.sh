#!/bin/sh
# Script to download a specific version of the scripts from GitHub

# Usage:
#   curl ... | ENV_VAR=... sh -
#       or
#   ENV_VAR=... ./setup.sh
#
# Examples:
#   Downloading scripts from a "main" branch in a temp local folder "temp":
#     curl -sfL https://raw.githubusercontent.com/SUSE-Technical-Marketing/instruqt-vms/main/update.sh | sh -
#

info() {
  echo '[INFO] ' "$@"
}

warn() {
  echo '[WARN] ' "$@" >&2
}

fatal() {
  echo '[ERROR] ' "$@" >&2
  exit 1
}

setup_env() {
  info 'Setup variables'
  case "$1" in
      ("-o")
          OUTPUT_FOLDER=$2
          shift
          shift
      ;;
      (*)
          OUTPUT_FOLDER=${OUTPUT_FOLDER:-'instruqt-vms'}
      ;;
  esac

  GIT_REVISION=${GIT_REVISION:-'refs/heads/main'}
  GIT_REPO_NAME='instruqt-vms'
  GIT_FOLDER=$(echo "$GIT_REVISION" | sed 's/\//-/g' | sed 's/refs-//' | sed 's/heads-//')
}

download() {
    info 'Download scripts'
    curl -fSsL -o ${GIT_REPO_NAME}.tar.gz https://github.com/SUSE-Technical-Marketing/${GIT_REPO_NAME}/archive/${GIT_REVISION}.tar.gz
    if [ $? -ne 0 ]; then
        fatal "Failed to download ${GIT_REPO_NAME} from ${GIT_REVISION}"
    fi
    tar -xzf ${GIT_REPO_NAME}.tar.gz
    mkdir -p ${OUTPUT_FOLDER}
    if [ -d ${OUTPUT_FOLDER}/functions ]; then
        warn "Output folder ${OUTPUT_FOLDER}/functions already exists, removing it"
        rm -rf ${OUTPUT_FOLDER}/functions
        rm -rf ${OUTPUT_FOLDER}/vms
        rm -rf ${OUTPUT_FOLDER}/env
    fi
    mv ${GIT_REPO_NAME}-${GIT_FOLDER}/functions ${OUTPUT_FOLDER}
    mv ${GIT_REPO_NAME}-${GIT_FOLDER}/vms ${OUTPUT_FOLDER}
    mv ${GIT_REPO_NAME}-${GIT_FOLDER}/env ${OUTPUT_FOLDER}
}

cleanup() {
  info 'Clean-up'
  rm -f ${GIT_REPO_NAME}.tar.gz
  rm -rf ${GIT_REPO_NAME}-${GIT_FOLDER}
}

{
  setup_env "$@"
  download
  cleanup
  info 'Update script completed successfully'
}
