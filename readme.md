## Architecture du projet

- **infra/terraform** : provisioning des VMs Debian 13 sur Proxmox
  - `main.tf` : définition des 4 VMs (`sae6-code`, `sae6-infra1`, `sae6-infra2`, `sae6-infra3`)
  - `terraform.tfvars` : variables sensibles (token Proxmox, mot de passe root, clé SSH) – **ne pas committer**
- **infra/ansible** : configuration des VMs (Docker, GitLab, Swarm, déploiement applicatif)
  - `site.yml` : playbook Ansible principal
  - `hosts.ini` : inventaire généré automatiquement par script
- **scripts** : scripts shell d’infrastructure
  - `proxmox_create_debian13_template.sh` : création du template Debian 13 cloud-init sur Proxmox
  - `ansible_configure_and_deploy.sh` : génère l’inventaire Ansible à partir des outputs Terraform puis lance le playbook
- **Dockerfile** : image Docker pour l’application (dossier `App` non modifié)

Le dossier `app` n’est pas modifié par cette infrastructure et contient le code applicatif.

---

## Prérequis

- Un nœud **Proxmox VE** accessible (avec API)
- Accès shell au nœud Proxmox (pour créer le template)
- Sur la machine d’orchestration (celle qui a cloné ce dépôt) :
  - `terraform`
  - `ansible` + `ansible-playbook`
  - une **clé SSH** privée permettant de se connecter en `admin` sur les VMs

La clé publique correspondante doit être renseignée dans `infra/terraform/terraform.tfvars`.

---

## 1. Création du template Debian 13 sur Proxmox

Sur le **nœud Proxmox** :

1. Cloner ou copier le script `scripts/proxmox_create_debian13_template.sh` sur le nœud.
2. L’exécuter (en root ou avec les droits nécessaires) :

   ```bash
   ./proxmox_create_debian13_template.sh
   ```

   Variables possibles à surcharger avant exécution :
   - `VMID` (par défaut `8001`)
   - `VMNAME` (par défaut `debian13-cloudinit`)
   - `STORAGE`, `BRIDGE`, `IMAGE_PATH`, `IMAGE_URL`

3. Dans l’interface Proxmox :
   - démarrer la VM créée,
   - installer et activer le paquet `qemu-guest-agent`,
   - arrêter la VM puis la **convertir en template**.

Assure-toi que l’ID du template (`VMID`) correspond à la valeur utilisée dans `infra/terraform/main.tf` (`vm_template` dans les `locals`).

---

## 2. Provisioning des VMs avec Terraform

Sur une machine ayant accès à l’API Proxmox et à ce dépôt :

1. Aller dans le répertoire Terraform :

   ```bash
   cd infra/terraform
   ```

2. Créer/éditer le fichier `terraform.tfvars` avec les valeurs adaptées :

   ```hcl
   pm_api_host         = "10.242.178.215"
   pm_api_token_id     = "root@pam!terraform"
   pm_api_token_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   vm_root_password    = "motdepasse-root"
   admin_ssh_public_key = "ssh-ed25519 AAAA... ton_utilisateur@machine"
   ```

3. Initialiser et appliquer la configuration :

   ```bash
   terraform init
   terraform apply
   ```

   Cela crée les 4 VMs :
   - `sae6-code` (GitLab + registry + CI/CD)
   - `sae6-infra1` (manager Docker Swarm)
   - `sae6-infra2` (worker)
   - `sae6-infra3` (worker)

4. Terraform expose les adresses IP via les outputs :

   ```bash
   terraform output code_ipv4
   terraform output infra_ipv4
   ```

   (Ces outputs seront utilisés automatiquement par le script Ansible ci-dessous.)

---

## 3. Configuration avec Ansible (Docker, GitLab, Swarm, app)

Depuis la **racine du dépôt** (machine d’orchestration) :

1. Vérifier que ta clé privée SSH permet d’accéder aux VMs en utilisateur `admin`.  
   Par défaut, le script utilise :

   ```bash
   SSH_KEY_PATH=/home/user/.ssh/id_ed25519
   ```

   Tu peux surcharger cette variable :

   ```bash
   export SSH_KEY_PATH=/chemin/vers/ta/cle_privee
   ```

2. Lancer le script de génération d’inventaire + déploiement Ansible :

   ```bash
   ./scripts/ansible_configure_and_deploy.sh
   ```

   Ce script :
   - se place dans `infra/terraform` et lit les outputs `code_ipv4` et `infra_ipv4`,
   - génère `infra/ansible/hosts.ini` avec les bonnes IP et la bonne clé SSH,
   - se place dans `infra/ansible` puis exécute :

     ```bash
     ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini site.yml
     ```

3. Le playbook `infra/ansible/site.yml` réalise les étapes suivantes :
   - Installation de Docker sur tous les nœuds (`gitlab`, `swarm_manager`, `swarm_workers`),
   - Déploiement de GitLab CE + registry sur la VM `sae6-code`,
   - Initialisation d’un cluster Docker Swarm sur `sae6-infra1` (manager),
   - Join des workers `sae6-infra2` et `sae6-infra3` au Swarm,
   - Déploiement d’une stack `sae6-app` (à adapter avec l’image de ta registry GitLab).

---

## 4. Adaptations possibles

- **Registry / image applicative**  
  Dans `infra/ansible/site.yml`, adapte :
  - l’URL externe de GitLab (`gitlab_external_url`),
  - l’URL de la registry,
  - l’image de la stack applicative :

  ```yaml
  image: "registry.gitlab.example.com/namespace/projet:latest"
  ```

- **Ressources des VMs**  
  Dans `infra/terraform/main.tf`, adapte :
  - le nœud Proxmox (`vm_node`),
  - le stockage (`vm_storage`),
  - le bridge réseau (`vm_bridge`),
  - la RAM/CPU si besoin.

---

## 5. Script principal (à venir)

La structure actuelle est pensée pour permettre la création d’un **script principal unique** qui enchaînera :

1. Création du template (via `proxmox_create_debian13_template.sh` ou API),
2. Provisioning Terraform (`infra/terraform`),
3. Déploiement Ansible (`infra/ansible` via `ansible_configure_and_deploy.sh`).

Ce script global pourra être ajouté ultérieurement sans modifier la structure mise en place ici.
