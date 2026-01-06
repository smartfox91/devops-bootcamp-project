output "ansible_inventory_file" {
  description = "Path to generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "ansible_ssh_key_file" {
  description = "Path to generated private ssh key for Ansible"
  value       = local_file.private_key_pem.filename
}
