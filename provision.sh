#!/bin/sh
# Script to download a specific version of the scripts from GitHub

# Usage:
#   curl ... | ENV_VAR=... sh -
#       or
#   ENV_VAR=... ./setup.sh
#
# Examples:
#   Downloading scripts from a "main" branch in a temp local folder "temp":
#     curl -sfL https://raw.githubusercontent.com/SUSE-Technical-Marketing/instruqt-vms/main/provision.sh | REG_CODE="SCC_REG_CODE" MACHINE="rancher" sh -
#   Downloading scripts from a specific revision "d8b7564fbf91473074e86b598ae06c7e4e522b9f" in the default local folder:
#     curl -sfL https://raw.githubusercontent.com/SUSE-Technical-Marketing/instruqt-vms/feature/init-solution/scripts/setup.sh | GIT_REVISION=d8b7564fbf91473074e86b598ae06c7e4e522b9f sh -
#   Testing locally the setup script:
#     GIT_REVISION=refs/heads/feature/init-solution ./instruqt-vms/scripts/setup.sh -o temp
#
# Environment variables:
#   - GIT_REVISION
#     Git revision (refs/heads/<branch-name>, refs/tags/vX.Y.Z for a tag, xxxxxxxxxxxxxxxx for a commit hashcode)
#   - OUTPUT_FOLDER
#     Output folder, where the scripts folder will be created with script directory tree inside, overriden if -o is used

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
    if [ -d ${OUTPUT_FOLDER}/scripts ]; then
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

provision() {
    info 'Provisioning script starting'

    MACHINE=${MACHINE:-''}
    if [ -z "$MACHINE" ]; then
        fatal 'MACHINE is not set, please provide a valid machine type (e.g., rancher, observability, rke2)'
    fi

    cd "${OUTPUT_FOLDER}/vms/${MACHINE}" || fatal "Failed to change directory to ${OUTPUT_FOLDER}/vms/${MACHINE}"
    ./setup.sh || fatal "Failed to execute setup.sh in ${OUTPUT_FOLDER}/vms/${MACHINE}"
}

register() {
  info "Registering SUSE Linux"
  [ -r /etc/os-release ] && . /etc/os-release
  if [ "$ID_LIKE" != "suse" ]; then
    info 'No need to register, not a SUSE system'
    continue
  elif [ "$ID" == "sles" ]; then
    info 'SUSE Linux Enterprise Server detected'
    registercloudguest --force-new || fatal 'Failed to register SUSE Linux Enterprise Server'
  elif [ -z "$REG_CODE" ]; then
    fatal 'REG_CODE is not set, please provide a valid registration code'
  elif [ "$ID_LIKE" == "suse" ] && ( [ "$VARIANT_ID" == "sle-micro" ] || [ "$ID" == "sle-micro" ]); then
    info 'SUSE MicroOS detected'
    transactional-update register -r "$REG_CODE" -e "$INSTRUQT_SCC_EMAIL" || fatal 'Failed to register SUSE MicroOS'
  fi
}

{
  setup_env "$@"
  download
  cleanup
  register
  provision
  info 'Provisioning script completed successfully'
}
