#!/bin/bash
# build.sh - Build the leap16-base KIWI image
#
# Requirements:
#   - Must run as root (loop devices require root)
#   - Linux host (or VM) with podman installed
#   - x86_64 architecture
#   - Sufficient disk space (~10GB) in $OUTPUT_DIR
#
# Usage:
#   sudo ./build.sh [output-dir]

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: this script must be run as root (sudo ./build.sh)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-${SCRIPT_DIR}/_output}"
KIWI_IMAGE="registry.suse.com/bci/kiwi:10"

mkdir -p "${OUTPUT_DIR}"

echo "==> Building leap16-base image"
echo "    Description : ${SCRIPT_DIR}"
echo "    Output      : ${OUTPUT_DIR}"
echo ""

# Build loop device args
LOOP_DEVICES="--device /dev/loop-control"
for i in $(seq 0 7); do
    LOOP_DEVICES="${LOOP_DEVICES} --device /dev/loop${i}"
done

podman run \
    --rm \
    --privileged \
    --security-opt unmask=/sys/dev/block \
    ${LOOP_DEVICES} \
    -v "${SCRIPT_DIR}:/image:Z" \
    -v "${OUTPUT_DIR}:/output:Z" \
    "${KIWI_IMAGE}" \
    kiwi-ng --debug \
        --type oem \
        system build \
        --description /image \
        --target-dir /output

echo ""
echo "==> Build complete. Output in: ${OUTPUT_DIR}"
echo "    Look for: ${OUTPUT_DIR}/leap16-base.x86_64-1.0.0.qcow2"
