terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.57.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://${var.pm_api_host}:8006/api2/json"
  insecure = true

  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"
}

variable "pm_api_host" {
  description = "Nom d'hôte ou IP du serveur Proxmox (sans schéma, ex: 10.242.178.215)"
  type        = string
}

variable "pm_api_token_id" {
  description = "ID du token Proxmox (ex: terraform@pve!tf)"
  type        = string
}

variable "pm_api_token_secret" {
  description = "Secret du token Proxmox"
  type        = string
  sensitive   = true
}

variable "vm_root_password" {
  description = "Mot de passe root des VMs"
  type        = string
  sensitive   = true
}

variable "admin_ssh_public_key" {
  description = "Clé publique SSH pour l'utilisateur admin"
  type        = string
}

locals {
  vm_count       = 4
  vm_name_prefix = "sae6"

 
  vm_node     = "sae"              
  vm_template = 8001               
  vm_storage  = "local-lvm"        
  vm_bridge   = "vmbr0"            
  vm_vlan     = 0                  

  # VMIDs Proxmox souhaités pour les 4 VMs
  vm_ids = [200, 201, 202, 203]
  vm_roles = ["code", "infra1", "infra2", "infra3"]
}

resource "proxmox_virtual_environment_vm" "debian13" {
  count = local.vm_count

  # Exemple de noms : sae6-code, sae6-infra1, sae6-infra2, sae6-infra3
  name      = "${local.vm_name_prefix}-${local.vm_roles[count.index]}"
  node_name = local.vm_node

  vm_id = local.vm_ids[count.index]

  clone {
    vm_id = local.vm_template
    full  = true
  }

  cpu {
    cores = 4
  }

  memory {
    # 16 Go pour la VM "code" (GitLab), 8 Go pour les autres
    dedicated = count.index == 0 ? 16384 : 8192
  }

  disk {
    datastore_id = local.vm_storage
    interface    = "scsi0"
    size         = 30
  }

  network_device {
    bridge = local.vm_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = local.vm_storage

    user_account {
      username = "admin"
      password = var.vm_root_password
      keys     = [var.admin_ssh_public_key]
    }

    # Configuration réseau: DHCP pour IPv4 et IPv6
    ip_config {
      ipv4 {
        address = "dhcp"
      }

      ipv6 {
        address = "dhcp"
      }
    }
  }
}

# Outputs pour Ansible
# VMIDs Proxmox des VMs Debian 13
output "debian13_vm_ids" {
  description = "VMIDs Proxmox des VMs Debian 13"
  value       = proxmox_virtual_environment_vm.debian13[*].vm_id
}

# VM GitLab / gestion de code (rôle "code")
output "code_ipv4" {
  description = "Adresse IPv4 de la VM de gestion de code (GitLab)"
  value       = proxmox_virtual_environment_vm.debian13[0].ipv4_addresses[1]
}

# VMs d'infrastructure (rôles infra1, infra2, infra3)
output "infra_ipv4" {
  description = "Adresses IPv4 des VMs d'infrastructure"
  value = [
    proxmox_virtual_environment_vm.debian13[1].ipv4_addresses[1],
    proxmox_virtual_environment_vm.debian13[2].ipv4_addresses[1],
    proxmox_virtual_environment_vm.debian13[3].ipv4_addresses[1],
  ]
}

