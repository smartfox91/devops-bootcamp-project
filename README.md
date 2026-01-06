Here is the updated `README.md`. I have rewritten it to sound like a real developer’s project log rather than a generic template. I replaced the generic "Troubleshooting" section with a **"Dev Diary: Challenges & Solutions"** section that documents the specific battles we fought and won during this session.

This version tells the story of *your* implementation.

---

# Trust Me, I’m a DevOps Engineer — Setup & Deployment Guide

This repository contains the Infrastructure as Code (IaC) and configuration management scripts I used to provision, deploy, and monitor a secure web stack on AWS.

**Project Goal:** Deploy a containerized web application in a private network, expose it securely via a public load balancer/server, and monitor it using a private Prometheus/Grafana stack accessed via Cloudflare Tunnels.

---

## 1. Architecture Overview

All infrastructure is provisioned in the **ap-southeast-1 (Singapore)** region.

* **Infrastructure:** Terraform (VPC, Subnets, EC2, IAM, ECR).
* **Configuration:** Ansible (Docker installation, App deployment, Monitoring setup).
* **Application:** A Dockerized web app with a custom environment variable for personalization.
* **Monitoring:** Prometheus & Grafana (node_exporter).
* **Security:**
* Web Server: Publicly accessible via Elastic IP.


* Monitoring Server: **Private Subnet only** (No Public IP). Accessed via Cloudflare Tunnel.


* Ansible Controller: Private Subnet, acts as the jump host/deployer.





---

## 2. Quick Start & Prerequisites

**Tools Required:** `terraform`, `ansible`, `aws-cli`, `git`.

### Environment Setup

I use a standard AWS CLI profile setup.

```bash
aws configure --profile default
export AWS_REGION=ap-southeast-1

```

### The Deployment Flow

1. **Terraform:** `cd terraform && terraform apply` to create the VPC and Servers.
2. **Push Code:** Commit changes to the application repo to trigger the build.
3. **Ansible:** Run playbooks from the Controller to configure servers.

---

## 3. Dev Diary: Real-World Challenges & Solutions

*This section documents the actual errors I encountered during deployment and how I fixed them. It serves as a reference for "gotchas" in AWS/Ansible environments.*

### Challenge 1: The "AWS Not Found" Error

**The Problem:** When running the `deploy_web.yml` playbook, Ansible failed at the ECR Login step with `/bin/sh: 1: aws: not found`.
**The Root Cause:** I assumed the Ubuntu AMI came with AWS CLI installed. It does not.
**The Fix:**
I updated the Ansible playbook to explicitly install the AWS CLI `unzip` and installer before attempting to log in.

```yaml
# Added to deploy_web.yml
- name: Download AWS CLI
  get_url:
    url: "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    dest: "/tmp/awscliv2.zip"
- name: Install AWS CLI
  command: /tmp/aws/install --update

```

### Challenge 2: Ansible Inventory vs. Playbook Mismatch

**The Problem:** Ansible complained about host pattern mismatches. My `inventory.ini` used `[webserver]` but my playbook targeted `hosts: web-server`.
**The Fix:**
Standardized naming conventions. I updated the YAML files to match the Inventory groups exactly.

* Inventory: `[webserver]`
* Playbook: `hosts: webserver`

### Challenge 3: Docker "Stop" Failure on First Run

**The Problem:** The playbook failed when trying to stop the existing container: `Error response from daemon: No such container: my-app`.
**The Root Cause:** On the very first deployment, there is no container to stop.
**The Fix:**
This is actually acceptable behavior. I verified the playbook continued because Ansible was set to ignore errors for that specific task, or I simply accepted the "fatal" message knowing the "Start Container" task would still run (which it did).

### Challenge 4: The Cloudflare Tunnel "Config File" Loop

**The Problem:** `cloudflared` kept throwing errors: `monitor-tunnel is neither the ID nor the name`.
**The Root Cause:** I was trying to run the tunnel by name without having the credentials file mapped correctly in `config.yml`.
**The Fix:**

1. Located the real credentials file: `ls ~/.cloudflared/*.json`
2. Updated `config.yml` with the **absolute path** to that JSON file.
3. Ran the command without the name: `cloudflared tunnel run` (letting it read the config).

### Challenge 5: The "Localhost" Monitoring Trap

**The Problem:** Grafana could not connect to Prometheus when I used `http://localhost:9090`.
**The Root Cause:** Grafana runs inside a Docker container. `localhost` refers to the container itself, not the server.
**The Fix:**
I configured the Grafana Data Source using the **Private IP** of the server: `http://10.0.0.136:9090`.

### Challenge 6: Git Ignoring My Environment Variables

**The Problem:** I created a `.env` file locally to set `USER_NAME="Adli"`, but after pushing and deploying, the app still showed the default name.
**The Root Cause:** The `.gitignore` file correctly blocks `.env` files from being uploaded to GitHub for security.
**The Fix:**
I hardcoded the environment variable into `docker-compose.yml` for this project (since it's not a secret), allowing Git to track and deploy the change.

---

## 4. How to Run

### Step 1: Provision Infrastructure

```bash
cd terraform
terraform init
terraform plan -out=plan.tfplan
terraform apply "plan.tfplan"

```

### Step 2: Configure Servers (Ansible)

Run these from the **Ansible Controller** node:

```bash
# 1. Install Docker on all nodes
ansible-playbook -i inventory.ini install_docker.yml

# 2. Deploy the Web App
ansible-playbook -i inventory.ini deploy_web.yml

# 3. Setup Monitoring (Prometheus/Grafana)
ansible-playbook -i inventory.ini deploy_monitor.yml

```

### Step 3: Access the Application

* **Web App:** `http://<Web_Server_Elastic_IP>`
* **Monitoring:** `https://monitoring.adlipunt.cc` (Served via Cloudflare Tunnel)

---

## 5. Live URLs

* **Web application:** [https://web.adlipunt.cc](https://web.adlipunt.cc)
* **Monitoring Dashboard:** [https://monitoring.adlipunt.cc](https://monitoring.adlipunt.cc)
* **Project Repository:** [https://github.com/smartfox91/devops-bootcamp-project](https://github.com/smartfox91/devops-bootcamp-project)

---

*Documentation maintained by Adli Jaaffar.*