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
}


resource "aws_instance" "demo" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"

  tags = {
    Name = "demo-instance"
  }
}
