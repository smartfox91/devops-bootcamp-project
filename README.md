Trust Me, I’m a DevOps Engineer — Setup & Deployment Guide

This repository provisions, configures and deploys a small web + monitoring stack on AWS using Terraform and Ansible. This guide walks you through prerequisites, infra bootstrap, how to build & push the container image to ECR, CI/CD examples, and how to deploy and monitor the stack.

**Prerequisites**
- **AWS account** with permissions to create S3, ECR, IAM, VPC, EC2.
- **Local tools**: `terraform` (>=1.0), `aws` CLI, `docker`, `ansible`, `git`.
- **AWS CLI profile** configured (examples use `default`).

**Quick environment setup**
```bash
aws configure --profile default
export AWS_REGION=ap-southeast-1
export AWS_PROFILE=default
```

**Where code lives**
- Terraform: [terraform/](terraform/)
- Ansible: [ansible/](ansible/)
- Prometheus config and templates: inside `ansible/` and repo root templates.

**1) Terraform backend (S3)**
- The backend stores state in S3. This project does not use a DynamoDB table for state locking.

- Create the S3 bucket (one-time):
```bash
aws s3api create-bucket \
  --bucket devops-bootcamp-terraform-mohdadlijaaffar \
  --region ${AWS_REGION} --create-bucket-configuration LocationConstraint=${AWS_REGION} \
  --profile ${AWS_PROFILE}
```

**2) Initialize and apply Terraform (safe steps)**
```bash
cd terraform
terraform init
terraform plan -out=plan.tfplan
terraform apply "plan.tfplan"
```
Notes:
- Using `-out` and then `terraform apply` with the saved plan guarantees `apply` will perform those exact actions. Running `terraform apply` without `-out` recomputes the plan and may differ.

**3) Build, tag and push Docker image to ECR**
```bash
# Log in to ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin <account-id>.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build and tag
docker build -t my-devops-app:latest .
docker tag my-devops-app:latest <account-id>.dkr.ecr.${AWS_REGION}.amazonaws.com/devops-bootcamp/final-project-yourname:latest

# Push
docker push <account-id>.dkr.ecr.${AWS_REGION}.amazonaws.com/devops-bootcamp/final-project-yourname:latest
```

**4) CI/CD (GitHub Actions) — short example**
- Use actions to build and push images. Either use OIDC role assumption or a GitHub secret with scoped credentials.

Minimal example `.github/workflows/ci.yml` snippet:
```yaml
name: Build and Push to ECR
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsECRPush
          aws-region: ap-southeast-1
      - run: |
          aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_ACCOUNT}
          docker build -t ${{ env.ECR_URI }}:latest .
          docker push ${{ env.ECR_URI }}:latest
```

**5) Deploy with Ansible**
- Terraform writes an inventory file to `../ansible/inventory.ini` using the template in the `terraform` module (see [terraform/inventory.tf](terraform/inventory.tf#L1-L40)). Ensure that file exists before running playbooks.

Common playbook commands:
```bash
ansible-playbook -i ansible/inventory.ini ansible/setup_docker.yml
ansible-playbook -i ansible/inventory.ini ansible/deploy_web.yml
ansible-playbook -i ansible/inventory.ini ansible/setup_monitoring.yml
```

**6) Monitoring & secure access**
- Prometheus & Grafana run on the monitoring server. Use a Cloudflare Tunnel (`cloudflared`) to expose Grafana without opening ports publicly.

**7) Troubleshooting quick reference**
- If you see lock-related errors, check your backend configuration; this project uses an S3-only backend.
- `local_file.private_key_pem` missing: find or create the resource used to write the private key file. Search:
```bash
grep -R "private_key_pem" -n . || true
```
- `inventory.tftpl` missing: ensure `terraform` module contains the template referenced by `templatefile()`.

**8) Clean up (destroy resources)**
```bash
cd terraform
terraform destroy
```

**9) Next steps I can help with**
- Create the S3 backend automatically.
- Add a ready GitHub Actions workflow and push it to the repo.
- Validate and fix references in `terraform/inventory.tf` and `terraform/output.tf` and run `terraform plan`.

Tell me which of these you'd like me to do next and I will run it for you.

1. Infrastructure Provisioning (Terraform)  
  
All infrastructure is provisioned using Terraform in the `ap-southeast-1` (Singapore) region. The Terraform code is stored in the `terraform/` directory of the repository.1.1. Terraform Backend Configuration  
  
The Terraform state is stored securely in an Amazon S3 bucket.  
  
**File:** `terraform/backend.tf`

```
# This block must be configured and then run 'terraform init'
terraform {
  backend "s3" {
    bucket         = "devops-bootcamp-terraform-yourname" # Replace 'yourname' with your name/identifier
    key            = "devops-bootcamp-project/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
  }
}
```

1.2. Provider and Version Configuration  
  
Sets up the required AWS provider and minimum Terraform version.  
  
**File:** `terraform/versions.tf`

```
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1" # Project Requirement
}
```

1.3. Core Infrastructure (VPC, Subnets, Gateways, ECR)  
  
The main configuration file provisions all network resources, the Elastic Container Registry (ECR), and the necessary IAM roles for AWS Systems Manager (SSM).  
  
**File:** `terraform/main.tf` (Partial - Contains the main resource logic)

- **VPC & Subnets:** Creates `devops-vpc` (`10.0.0.0/24`), public subnet (`10.0.0.0/25`), and private subnet (`10.0.0.128/25`).
- **Gateways & Routing:** Provisions an Internet Gateway (`devops-igw`) for the public subnet and a **NAT Gateway** (`devops-ngw`) for internet access from the private subnet.
- **ECR:** Creates the `devops-bootcamp/final-project-yourname` repository.

1.4. Security Groups  
  
Two distinct security groups are created to enforce network policy.

```
# 1. Web Server Security Group (devops-public-sg)
resource "aws_security_group" "web_sg" {
  name   = "devops-public-sg"
  # ... VPC configuration ...

  # Port 80: Allow from any IP (HTTP)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Node Exporter (Allow from Monitoring Server IP)
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.136/32"] 
  }

  # Port 22: Allow from VPC subnet only (10.0.0.0/24)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.devops_vpc.cidr_block] 
  }
  # ... Egress rule ...
}

# 2. Ansible/Monitoring Server Security Group (devops-private-sg)
resource "aws_security_group" "private_sg" {
  name   = "devops-private-sg"
  # ... VPC configuration ...

  # Port 22: Allow from VPC subnet only (10.0.0.0/24)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.devops_vpc.cidr_block]
  }
  # ... Egress rule ...
}
```

1.5. EC2 Instances  
  
Three `t3.micro` instances running Ubuntu 24.04 are provisioned. Crucially, all instances have an IAM role attached to enable **SSM access**.

|Server Name|Subnet|Private IP|Public IP Access|Security Group|
|---|---|---|---|---|
|Web Server|Public|`10.0.0.5`|Elastic IP (EIP)|`devops-public-sg`|
|Ansible Controller|Private|`10.0.0.135`|**None**|`devops-private-sg`|
|Monitoring Server|Private|`10.0.0.136`|**None**|`devops-private-sg`|

-----2. Configuration Management (Ansible)  
  
All server configurations are managed using Ansible, executed from the Ansible Controller (`10.0.0.135`). The Ansible playbooks are stored in the `ansible/` directory.2.1. Ansible Inventory  
  
The inventory uses the **private IP addresses** to ensure all communication stays within the VPC (using SSH via the Controller).  
  
**File:** `ansible/inventory.ini`

```
[webservers]
web_server ansible_host=10.0.0.5

[monitoringservers]
monitoring_server ansible_host=10.0.0.136
```

2.2. Install Docker Engine  
  
This playbook targets both the Web and Monitoring Servers to install Docker, which is required for containerized deployment of the application, Prometheus, and Grafana.  
  
**File:** `ansible/setup_docker.yml`

```
---
- name: Install Docker Engine on Web and Monitoring Servers
  hosts: webservers, monitoringservers
  become: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
    
    # ... Tasks to add Docker GPG key, repository, and install Docker packages ...
    - name: Install Docker Engine
      ansible.builtin.apt:
        name: 
          - docker-ce
          - docker-ce-cli
          - containerd.io
          - docker-compose-plugin
        state: present

    - name: Add 'ubuntu' user to docker group
      user:
        name: ubuntu
        groups: docker
        append: yes 
```

2.3. Deploy Web Application  
  
The Web Server deployment is handled by this playbook, which pulls the image from ECR and runs it as a container exposed on Port 80.  
  
**File:** `ansible/deploy_web.yml`

```
---
- name: Deploy my-devops-project Web Application
  hosts: webservers
  become: yes
  tasks:
    # NOTE: ECR login must be configured securely on the Ansible Controller first.

    - name: Deploy my-devops-project container
      community.docker.docker_container:
        name: my-devops-app
        image: "{{ ecr_repo_uri }}:latest" # Replace with your ECR image URI
        state: started
        ports:
          - "80:80" # Ensure application is accessible via HTTP (port 80)
        restart_policy: always
```

2.4. Setup Monitoring Stack (Prometheus & Grafana)  
  
This playbook installs and configures Prometheus and Grafana on the Monitoring Server and deploys the Node Exporter metric collector on the Web Server.  
  
**File:** `ansible/setup_monitoring.yml`

```
---
- name: Setup Prometheus and Grafana Monitoring Stack
  hosts: monitoringservers
  become: yes
  tasks:
    # 1. Deploy Node Exporter on Web Server (to collect metrics: CPU, RAM, DISK)
    - name: Deploy Node Exporter on Web Server
      command: docker run -d --name node_exporter -p 9100:9100 prom/node-exporter
      delegate_to: 10.0.0.5 # Execute command on the Web Server
      run_once: true

    # 2. Deploy Prometheus
    - name: Copy Prometheus configuration file (prometheus.yml)
      copy:
        content: |
          global:
            scrape_interval: 15s
          scrape_configs:
            # Target the Web Server's Node Exporter
            - job_name: 'web_server_metrics'
              static_configs:
                - targets: ['10.0.0.5:9100'] # Web Server Private IP:Node Exporter Port
        dest: /etc/prometheus/prometheus.yml
        # ... other Prometheus setup tasks ...

    - name: Deploy Prometheus container
      community.docker.docker_container:
        name: prometheus
        image: prom/prometheus:latest
        state: started
        ports:
          - "9090:9090" # For internal access
        # ... volumes and restart policy ...

    # 3. Deploy Grafana
    - name: Deploy Grafana container
      community.docker.docker_container:
        name: grafana
        image: grafana/grafana:latest
        state: started
        ports:
          - "3000:3000" # Default Grafana port
        restart_policy: always
        # NOTE: Post-deployment, the Grafana data source and dashboards must be configured.
```

-----3. Domain and Cloudflare Configuration

- **Web Application:** DNS is configured to point `web.yourdomain.com` to the Web Server's Elastic IP.
- **Monitoring (Grafana):** Access is secured via a **Cloudflare Tunnel** (ensuring the Monitoring Server is **not** publicly exposed), routing `monitoring.yourdomain.com` to the Grafana instance.

-----4. Mandatory Documentation Content  
  
The final documentation published via GitHub Pages **must** include the final, working URLs:

- **Web application URL:** 'https://web.adlipunt.cc'
- **Monitoring URL:** 'https://monitoring.adlipunt.cc'
- **GitHub repository URL:** 'https://github.com/smartfox91/devops-bootcamp-project'
- **GitHub Page URL:** 'https://smartfox91.github.io/devops-bootcamp-project/'
