provider "aws" {
  region = "us-east-1"
  assume_role_with_web_identity {
    role_arn                = var.aws_role_arn
    web_identity_token_file = var.aws_web_identity_token_file
  }
}

resource "aws_instance" "web" {
  ami           = "ami-0c94855ba95c71c99"  # example Ubuntu AMI
  instance_type = "t2.micro"
  tags = {
    Name = "demo-instance"
  }
}
