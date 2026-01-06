terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.25.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.6.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }

    
  }
  backend "s3" {
    bucket         = "devops-bootcamp-terraform-mohdadlijaaffar" # Replace 'yourname'
    key            = "devops-bootcamp-project/terraform.tfstate"
    region         = "ap-southeast-1" #
    encrypt        = true
  
  }
}

provider "aws" {
  region  = "ap-southeast-1"
  profile = "default"
}
