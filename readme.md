sur la machine proxmox :
- executer le script debian13-cloudinit-template.sh

sur le pannel proxmox :
- démarrer le futur template (id 8001)
- installer et activer le paquet qemu-guest-agent
- démarrer puis convertir la VM en template

sur n'importe quel support ayant accès au proxmox :
- installer terraform
- configurer un fichier terraform.tfvars avec les variables pm_api_token_id, pm_api_token_secret et vm_root_password
- déployer le main.tf (création de 4 VMs : sae6-code, sae6-infra1, sae6-infra2, sae6-infra3)
- récupérer les IP avec `terraform output code_ipv4` et `terraform output infra_ipv4`
- utiliser ces IP dans un inventaire Ansible pour :
  - installer GitLab + registry + CI/CD sur sae6-code
  - installer un orchestrateur Docker Swarm sur sae6-infra1
  - joindre sae6-infra2 et sae6-infra3 au cluster et déployer l'application