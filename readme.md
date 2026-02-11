sur la machine proxmox :
- executer le script debian13-cloudinit-template.sh

sur le pannel proxmox :
- démarrer le futur template (id 8001)
- installer et activer le paquet qemu-guest-agent
- démarrer puis convertir la VM en template

sur n'importe quel support ayant accès au proxmox :
- installer terraform
- configurer un fichier terraform.tfvars avec les variables pm_api_token_id, pm_api_token_secret et vm_root_password
- déployer le main.tf