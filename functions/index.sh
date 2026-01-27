#!/bin/bash
# File to be sourced to have all shell functions available in the bash terminal

info() {
  echo '[INFO] ' "$@"
}

SCRIPT_FOLDER=$(dirname "${BASH_SOURCE[0]}")
for file in ${SCRIPT_FOLDER}/*/*.sh; do
  . $file
done

info "All functions sourced from ${SCRIPT_FOLDER}"