resource "aws_security_group" "devops_public_sg" {
  name        = "devops-public-sg"
  description = "Public security group: HTTP from anywhere, SSH from VPC only"
  vpc_id      = aws_vpc.devops.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from inside VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.devops.cidr_block]
  }

  ingress {
    description = "Allow from Monitoring Server IP"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.136/32"] 
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-public-sg"
  }
}

resource "aws_security_group" "devops_private_sg" {
  name        = "devops-private-sg"
  description = "Private security group: SSH from VPC only"
  vpc_id      = aws_vpc.devops.id

  ingress {
    description = "SSH from inside VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.devops.cidr_block]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-private-sg"
  }
}
