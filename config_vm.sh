#!/usr/bin/env bash
set -euo pipefail

# Clé privée de la machine hôte à utiliser pour SSH vers les VMs
# Modifie ce chemin si ta clé est ailleurs
SSH_KEY_PATH="${SSH_KEY_PATH:-/home/user/.ssh/id_ed25519}"

if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "Erreur : clé privée SSH introuvable à l'emplacement '$SSH_KEY_PATH'."
  echo "Définis SSH_KEY_PATH ou place ta clé à cet endroit."
  exit 1
fi

# 1) Récupération des outputs Terraform en JSON
# code_ipv4 = ["IP_CODE"]
CODE_IP=$(terraform output -json code_ipv4 | jq -r '.[0]')

# infra_ipv4 = [["IP_INFRA1"], ["IP_INFRA2"], ["IP_INFRA3"]] ou similaire
# -> on prend le premier élément de chaque sous-liste
mapfile -t INFRA_IPS < <(terraform output -json infra_ipv4 | jq -r '.[][0]')

# 2) Génération du fichier hosts.ini
cat > hosts.ini <<EOF
[gitlab]
code ansible_host=${CODE_IP} ansible_user=admin ansible_ssh_private_key_file=${SSH_KEY_PATH}

[swarm_manager]
infra1 ansible_host=${INFRA_IPS[0]} ansible_user=admin ansible_ssh_private_key_file=${SSH_KEY_PATH}

[swarm_workers]
infra2 ansible_host=${INFRA_IPS[1]} ansible_user=admin ansible_ssh_private_key_file=${SSH_KEY_PATH}
infra3 ansible_host=${INFRA_IPS[2]} ansible_user=admin ansible_ssh_private_key_file=${SSH_KEY_PATH}
EOF

echo "Fichier hosts.ini généré (utilisateur 'admin' + clé privée ${SSH_KEY_PATH})."

# 3) Lancement du playbook Ansible avec la clé privée de la machine hôte
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini site.yml