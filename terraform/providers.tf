terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-terraform-state-bucket-6af024b2"
    key            = "nestjs-terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# resource "aws_s3_bucket" "app_bucket" {
#   bucket = "${var.container_name}-app-bucket-${random_id.suffix.hex}"
# }

# resource "random_id" "suffix" {
#   byte_length = 4
# }

# output "app_bucket_name" {
#   value = aws_s3_bucket.app_bucket.bucket
# }