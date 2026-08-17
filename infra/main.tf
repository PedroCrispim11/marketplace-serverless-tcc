terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      Projeto     = "Marketplace-B2B-TCC"
      Ambiente    = "MVP"
      Gerenciado  = "Terraform"
    }
  }
}