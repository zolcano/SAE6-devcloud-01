#!/usr/bin/env bash

set -euo pipefail

# Script de génération d'inventaire Ansible et de déploiement du playbook.
# À exécuter depuis la racine du dépôt.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${REPO_ROOT}/infra/terraform"
ANSIBLE_DIR="${REPO_ROOT}/infra/ansible"

# Clé privée de la machine hôte à utiliser pour SSH vers les VMs
# Modifie ce chemin si ta clé est ailleurs
SSH_KEY_PATH="${SSH_KEY_PATH:-/home/user/.ssh/id_ed25519}"

if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "Erreur : clé privée SSH introuvable à l'emplacement '$SSH_KEY_PATH'."
  echo "Définis SSH_KEY_PATH ou place ta clé à cet endroit."
  exit 1
fi

cd "${TERRAFORM_DIR}"

if [ ! -f "terraform.tfstate" ]; then
  echo "Erreur : aucun état Terraform trouvé dans ${TERRAFORM_DIR}."
  echo "Exécute d'abord 'terraform init' puis 'terraform apply' dans ce répertoire."
  exit 1
fi

# 1) Récupération des outputs Terraform en JSON
# code_ipv4 = ["IP_CODE"]
CODE_IP=$(terraform output -json code_ipv4 | jq -r '.[0]')

# infra_ipv4 = [["IP_INFRA1"], ["IP_INFRA2"], ["IP_INFRA3"]] ou similaire
# -> on prend le premier élément de chaque sous-liste
mapfile -t INFRA_IPS < <(terraform output -json infra_ipv4 | jq -r '.[][0]')

cd "${ANSIBLE_DIR}"

# 2) Génération du fichier hosts.ini (dans infra/ansible)
cat > hosts.ini <<EOF
[gitlab]
code ansible_host=${CODE_IP} ansible_user=admin ansible_ssh_private_key_file=${SSH_KEY_PATH}

[swarm_manager]
infra1 ansible_host=${INFRA_IPS[0]} ansible_user=admin ansible_ssh_private_key_file=${SSH_KEY_PATH}

[swarm_workers]
infra2 ansible_host=${INFRA_IPS[1]} ansible_user=admin ansible_ssh_private_key_file=${SSH_KEY_PATH}
infra3 ansible_host=${INFRA_IPS[2]} ansible_user=admin ansible_ssh_private_key_file=${SSH_KEY_PATH}
EOF

echo "Fichier hosts.ini généré dans ${ANSIBLE_DIR} (utilisateur 'admin' + clé privée ${SSH_KEY_PATH})."

# 3) Lancement du playbook Ansible avec la clé privée de la machine hôte
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini site.yml

