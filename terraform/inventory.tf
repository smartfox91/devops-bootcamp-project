resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tftpl", {
    instances       = values(module.ec2_instance)
    ssh_private_key = local_file.private_key_pem.filename
  })
  filename = "../ansible/inventory.ini"
}
