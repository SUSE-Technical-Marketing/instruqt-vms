#!/bin/bash
# harvester-build-pipeline.sh
#
# Automates the full image build pipeline:
#   1. Serve the base qcow2 locally and have Harvester download it
#   2. Create a VM with cloud-init user-data (k3s/Helm installs)
#   3. Wait for VM to power off (cloud-init seals and shuts down)
#   4. Export the root PVC disk
#   5. Convert to raw + tar.gz for GCP import
#
# Requirements:
#   - kubectl configured against your Harvester cluster
#   - python3 available locally (for the HTTP server)
#   - qemu-img installed locally
#
# Usage:
#   ./harvester-build-pipeline.sh \
#     --image ./leap16-base.x86_64-1.0.0.qcow2 \
#     --userdata ./cloud-init-build.yaml \
#     --output ./gcp-image.tar.gz \
#     --namespace default \
#     --name leap16-k3s

set -euo pipefail

#======================================
# Parse arguments
#--------------------------------------
IMAGE_FILE=""
USERDATA_FILE=""
OUTPUT_FILE="./gcp-image.tar.gz"
NAMESPACE="default"
VM_NAME="leap16-build"
SERVE_PORT=18080
SERVE_IP=""

usage() {
    echo "Usage: $0 --image <qcow2> --userdata <yaml> [--output <tar.gz>] [--namespace <ns>] [--name <vm-name>] [--serve-ip <ip>] [--serve-port <port>]"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --image)      IMAGE_FILE="$2";   shift 2 ;;
        --userdata)   USERDATA_FILE="$2"; shift 2 ;;
        --output)     OUTPUT_FILE="$2";  shift 2 ;;
        --namespace)  NAMESPACE="$2";    shift 2 ;;
        --name)       VM_NAME="$2";      shift 2 ;;
        --serve-ip)   SERVE_IP="$2";     shift 2 ;;
        --serve-port) SERVE_PORT="$2";   shift 2 ;;
        *)            usage ;;
    esac
done

[[ -z "$IMAGE_FILE" ]]    && { echo "Error: --image required";    usage; }
[[ -z "$USERDATA_FILE" ]] && { echo "Error: --userdata required"; usage; }
[[ ! -f "$IMAGE_FILE" ]]  && { echo "Error: image file not found: $IMAGE_FILE"; exit 1; }
[[ ! -f "$USERDATA_FILE" ]] && { echo "Error: userdata file not found: $USERDATA_FILE"; exit 1; }

IMAGE_NAME="${VM_NAME}-base-image"
HTTP_PID=""
trap '[[ -n "$HTTP_PID" ]] && kill "$HTTP_PID" 2>/dev/null || true' EXIT
PVC_NAME="${VM_NAME}-disk"
DISK_RAW="$(dirname "$OUTPUT_FILE")/disk.raw"

#======================================
# Helper: wait for a kubectl condition
#--------------------------------------
wait_for() {
    local description="$1"
    local check_cmd="$2"
    local expected="$3"
    local timeout="${4:-600}"
    local interval=10
    local elapsed=0

    echo "==> Waiting for: $description (timeout: ${timeout}s)"
    while true; do
        local result
        result=$(eval "$check_cmd" 2>/dev/null || echo "")
        if [[ "$result" == "$expected" ]]; then
            echo "    Done: $description"
            return 0
        fi
        if [[ $elapsed -ge $timeout ]]; then
            echo "ERROR: Timeout waiting for: $description (last value: $result)"
            exit 1
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        echo "    Still waiting... ${elapsed}s elapsed (current: $result)"
    done
}

#======================================
# Step 1: Serve qcow2 locally, Harvester downloads it
# More reliable than the upload API for large files.
#--------------------------------------
echo ""
echo "========================================"
echo "Step 1: Importing base image into Harvester"
echo "========================================"

SERVE_DIR="$(cd "$(dirname "$IMAGE_FILE")" && pwd)"
SERVE_FILE="$(basename "$IMAGE_FILE")"

# Auto-detect serve IP if not provided
if [[ -z "$SERVE_IP" ]]; then
    SERVE_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}')
fi

IMAGE_URL="http://${SERVE_IP}:${SERVE_PORT}/${SERVE_FILE}"
echo "    Serving image at: ${IMAGE_URL}"
echo "    Make sure Harvester can reach this address."

python3 -m http.server "${SERVE_PORT}" --directory "${SERVE_DIR}" &
HTTP_PID=$!
sleep 2

kubectl apply -f - << YAML
apiVersion: harvesterhci.io/v1beta1
kind: VirtualMachineImage
metadata:
  name: ${IMAGE_NAME}
  namespace: ${NAMESPACE}
  annotations:
    harvesterhci.io/storageClassName: longhorn-single
spec:
  displayName: "${VM_NAME} base image"
  sourceType: download
  url: "${IMAGE_URL}"
YAML

wait_for "image import complete" \
    "kubectl get virtualmachineimage ${IMAGE_NAME} -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type==\"Imported\")].status}'" \
    "True" 600

kill "${HTTP_PID}" 2>/dev/null || true
echo "    Image ready: ${IMAGE_NAME}"

#======================================
# Step 2: Create the VM with cloud-init user-data
#--------------------------------------
echo ""
echo "========================================"
echo "Step 2: Creating VM: ${VM_NAME}"
echo "========================================"

# Store user-data in a Secret.
# Harvester requires both 'userdata' and 'networkdata' keys in the secret,
# and both secretRef and networkDataSecretRef must reference it.
USERDATA_B64=$(base64 -w0 < "$USERDATA_FILE")
kubectl apply -f - << YAML
apiVersion: v1
kind: Secret
metadata:
  name: ${VM_NAME}-userdata
  namespace: ${NAMESPACE}
  labels:
    harvesterhci.io/cloud-init-template: harvester
type: Opaque
data:
  userdata: ${USERDATA_B64}
  networkdata: ""
YAML

# Get the storage class Harvester created for this image
IMAGE_SC=$(kubectl get virtualmachineimage "${IMAGE_NAME}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.storageClassName}')
echo "    Image storage class: ${IMAGE_SC}"

# Create the PVC directly with the imageId annotation on the PVC itself.
# This is the correct Harvester pattern - no dataVolumeTemplates.
kubectl apply -f - << YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${PVC_NAME}
  namespace: ${NAMESPACE}
  annotations:
    harvesterhci.io/imageId: ${NAMESPACE}/${IMAGE_NAME}
  labels:
    harvesterhci.io/creator: harvester
    harvesterhci.io/vmName: ${VM_NAME}
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  volumeMode: Block
  storageClassName: ${IMAGE_SC}
YAML

# Create the VM referencing the PVC directly
kubectl apply -f - << YAML
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: ${VM_NAME}
  namespace: ${NAMESPACE}
  labels:
    harvesterhci.io/creator: harvester
spec:
  runStrategy: Once
  template:
    metadata:
      labels:
        harvesterhci.io/vmName: ${VM_NAME}
    spec:
      domain:
        cpu:
          cores: 4
          sockets: 1
          threads: 1
        machine:
          type: q35
        devices:
          disks:
            - name: disk0
              disk:
                bus: virtio
              bootOrder: 1
            - name: cloudinit
              disk:
                bus: virtio
          interfaces:
            - name: default
              masquerade: {}
        resources:
          limits:
            memory: 8Gi
      networks:
        - name: default
          pod: {}
      volumes:
        - name: disk0
          persistentVolumeClaim:
            claimName: ${PVC_NAME}
        - name: cloudinit
          cloudInitNoCloud:
            secretRef:
              name: ${VM_NAME}-userdata
            networkDataSecretRef:
              name: ${VM_NAME}-userdata
YAML

wait_for "VM running" \
    "kubectl get vmi ${VM_NAME} -n ${NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null || echo 'pending'" \
    "Running" 300

echo "    VM is running: ${VM_NAME}"

#======================================
# Step 3: Wait for VM to power off
# cloud-init user-data must end with: cloud-init clean && systemctl poweroff
#--------------------------------------
echo ""
echo "========================================"
echo "Step 3: Waiting for cloud-init to complete and VM to power off"
echo "        (this may take 10-30 minutes)"
echo "========================================"

wait_for "VM stopped (cloud-init complete)" \
    "kubectl get vmi ${VM_NAME} -n ${NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null || echo 'pending'" \
    "Succeeded" 3600

echo "    VM has powered off."

#======================================
# Step 4: Export the root PVC via a temporary pod
# Avoids the VirtualMachineExport feature gate requirement.
#--------------------------------------
echo ""
echo "========================================"
echo "Step 4: Exporting root disk PVC"
echo "========================================"

EXPORT_POD="${VM_NAME}-export"

kubectl apply -f - << YAML
apiVersion: v1
kind: Pod
metadata:
  name: ${EXPORT_POD}
  namespace: ${NAMESPACE}
spec:
  restartPolicy: Never
  containers:
    - name: export
      image: busybox
      command: ["sleep", "3600"]
      volumeDevices:
        - name: disk
          devicePath: /dev/disk
  volumes:
    - name: disk
      persistentVolumeClaim:
        claimName: ${PVC_NAME}
YAML

wait_for "export pod ready" \
    "kubectl get pod ${EXPORT_POD} -n ${NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null || echo 'pending'" \
    "Running" 120

echo "    Streaming disk image from pod..."
DISK_DOWNLOAD="$(dirname "$DISK_RAW")/disk-download.raw"
kubectl exec -n "${NAMESPACE}" "${EXPORT_POD}" -- \
    dd if=/dev/disk of=/dev/stdout bs=4M 2>/dev/null > "${DISK_DOWNLOAD}"

kubectl delete pod "${EXPORT_POD}" -n "${NAMESPACE}" --wait=false

echo "    Minimizing (removing zero blocks)..."
DISK_QCOW="$(dirname "$DISK_RAW")/disk-tmp.qcow2"
qemu-img convert -f raw -O qcow2 -c "${DISK_DOWNLOAD}" "${DISK_QCOW}"
qemu-img convert -f qcow2 -O raw "${DISK_QCOW}" "${DISK_RAW}"
rm -f "${DISK_DOWNLOAD}" "${DISK_QCOW}"
echo "    Minimized size: $(du -sh "$DISK_RAW" | cut -f1)"

#======================================
# Step 5: Package for GCP
#--------------------------------------
echo ""
echo "========================================"
echo "Step 5: Packaging for GCP"
echo "========================================"

# GCP requires oldgnu tar format.
# On macOS use gtar (brew install gnu-tar), on Linux plain tar works.
if command -v gtar &>/dev/null; then
    gtar --format=oldgnu -Sczf "${OUTPUT_FILE}" -C "$(dirname "$DISK_RAW")" disk.raw
else
    tar --format=oldgnu -Sczf "${OUTPUT_FILE}" -C "$(dirname "$DISK_RAW")" disk.raw
fi
rm -f "${DISK_RAW}"
echo "    GCP image: ${OUTPUT_FILE} ($(du -sh "$OUTPUT_FILE" | cut -f1))"

#======================================
# Cleanup hint
#--------------------------------------
echo ""
echo "========================================"
echo "Cleanup (run when done):"
echo "========================================"
echo "    kubectl delete vm ${VM_NAME} -n ${NAMESPACE}"
echo "    kubectl delete vmi ${VM_NAME} -n ${NAMESPACE}"
echo "    kubectl delete secret ${VM_NAME}-userdata -n ${NAMESPACE}"
echo "    kubectl delete pod ${VM_NAME}-export -n ${NAMESPACE}"
echo "    kubectl delete pvc ${PVC_NAME} -n ${NAMESPACE}"
echo "    kubectl delete virtualmachineimage ${IMAGE_NAME} -n ${NAMESPACE}"
echo ""
echo "========================================"
echo "Next step: Import to GCP"
echo "========================================"
echo "    gsutil cp ${OUTPUT_FILE} gs://YOUR_BUCKET/"
echo "    gcloud compute images create leap16-k3s \\"
echo "        --source-uri gs://YOUR_BUCKET/$(basename "$OUTPUT_FILE") \\"
echo "        --guest-os-features VIRTIO_SCSI_MULTIQUEUE,UEFI_COMPATIBLE,SEV_CAPABLE"
echo ""
echo "Done."
