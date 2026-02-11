#!/usr/bin/env bash

set -euo pipefail

# Variables (à adapter si besoin)
VMID="${VMID:-8001}"
VMNAME="${VMNAME:-debian13-cloudinit}"
STORAGE="${STORAGE:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"
IMAGE_PATH="/root/debian-13-genericcloud-amd64.qcow2"
IMAGE_URL="https://cdimage.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"

echo "=== Téléchargement de l'image cloud-init Debian 13 (amd64) ==="
if [ ! -f "${IMAGE_PATH}" ]; then
  wget "${IMAGE_URL}" -O "${IMAGE_PATH}"
else
  echo "Image déjà présente à ${IMAGE_PATH}, téléchargement ignoré."
fi

echo "=== Création de la VM ${VMID} / ${VMNAME} ==="
qm create "${VMID}" \
  --name "${VMNAME}" \
  --net0 "virtio,bridge=${BRIDGE}" \
  --scsihw virtio-scsi-pci \
  --machine q35

echo "=== Import du disque cloud-init dans le stockage ${STORAGE} ==="
qm set "${VMID}" \
  --scsi0 "${STORAGE}:0,discard=on,ssd=1,format=qcow2,import-from=${IMAGE_PATH}"

echo "=== Redimensionnement du disque à 30G ==="
qm disk resize "${VMID}" scsi0 30G

echo "=== Configuration du boot sur scsi0 ==="
qm set "${VMID}" --boot order=scsi0

echo "=== Configuration CPU / RAM ==="
qm set "${VMID}" --cpu host --cores 4 --memory 8192

echo "=== Configuration BIOS OVMF + efidisk ==="
qm set "${VMID}" --bios ovmf \
  --efidisk0 "${STORAGE}:0,format=raw,efitype=4m,pre-enrolled-keys=1"

echo "=== Ajout du disque Cloud-Init ==="
qm set "${VMID}" --ide2 "${STORAGE}:cloudinit"

echo "=== Configuration de la console série ==="
qm set "${VMID}" --serial0 socket --vga serial0

echo "=== Configuration de l'agent ==="
qm set "${VMID}" --agent enabled=1

echo "=== VM Template Debian 13 cloud-init créé : VMID=${VMID}, nom=${VMNAME} ==="
echo "installez qemu-guest-agent sur la VM puis convertisse en template"

