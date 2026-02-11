terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.57.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://10.242.178.215:8006/api2/json"
  insecure = true

  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"
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

locals {
  vm_count       = 4
  vm_name_prefix = "debian13"

  # À adapter à ton infra Proxmox :
  vm_node     = "sae"               # nom du nœud Proxmox
  vm_template = 8001                # VMID du template Debian 13 cloud-init
  vm_storage  = "local-lvm"         # datastore pour le disque
  vm_bridge   = "vmbr0"             # bridge réseau
  vm_vlan     = 0                   # VLAN si besoin (0 = aucun)
}

resource "proxmox_virtual_environment_vm" "debian13" {
  count = local.vm_count

  name = "${local.vm_name_prefix}-${count.index + 1}"
  node_name = local.vm_node

  clone {
    vm_id = local.vm_template
    full  = true
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = local.vm_storage
    interface    = "scsi0"
    size         = 30
  }

  network_device {
    bridge  = local.vm_bridge
    model   = "virtio"
    # vlan_id = local.vm_vlan  # décommente si tu utilises un VLAN spécifique
  }

  initialization {
    datastore_id = local.vm_storage

    user_account {
      username = "root"
      password = var.vm_root_password
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

