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

  assume_role_with_web_identity {
    # Hard-coded IAM Role ARN for GitHub Actions OIDC
    role_arn = "arn:aws:iam::038462758764:role/github-actions-role" 
    # Path where GitHub Actions writes the OIDC token
    web_identity_token_file = "/home/runner/work/_temp/oidc-token" 
  }
}

resource "aws_instance" "demo" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"

  tags = {
    Name = "demo-instance"
  }
}
