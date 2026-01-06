locals {
  instances = {
    web = {
      name                         = "web-server"
      subnet                       = aws_subnet.public.id
      sg                           = [aws_security_group.devops_public_sg.id]
      private_ip                   = "10.0.0.5"
      associate_public_ip_address  = true
      create_eip                   = true
    }

    ansible = {
      name                         = "ansible-controller"
      subnet                       = aws_subnet.private.id
      sg                           = [aws_security_group.devops_private_sg.id]
      private_ip                   = "10.0.0.135"
      associate_public_ip_address  = false
      create_eip                   = false
    }

    monitoring = {
      name                         = "monitoring-server"
      subnet                       = aws_subnet.private.id
      sg                           = [aws_security_group.devops_private_sg.id]
      private_ip                   = "10.0.0.136"
      associate_public_ip_address  = false
      create_eip                   = false
    }
  }
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.1.5"

  for_each = local.instances

  ami           = "ami-00d8fc944fb171e29"
  name          = each.value.name
  instance_type = "t3.micro"

  subnet_id                   = each.value.subnet
  vpc_security_group_ids      = each.value.sg
  private_ip                  = each.value.private_ip
  associate_public_ip_address = each.value.associate_public_ip_address
  create_eip                  = each.value.create_eip

  key_name = aws_key_pair.ansible.key_name

  tags = {
    Name = each.value.name
    Role = each.key
  }
}

output "instances" {
  value = {
    for k, v in module.ec2_instance : k => {
      id         = v.id
      private_ip = v.private_ip
      public_ip  = v.public_ip
    }
  }
}

output "web_eip" {
  value       = try(module.ec2_instance["web"].public_ip, "")
  description = "Elastic IP assigned to the web server (empty if not created)"
}

