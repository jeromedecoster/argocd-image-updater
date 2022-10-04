terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.31.0"
    }

    github = {
      source  = "integrations/github"
      version = "5.2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# https://registry.terraform.io/providers/integrations/github/latest/docs
provider "github" {
  owner = var.github_owner
  token = var.github_token
}