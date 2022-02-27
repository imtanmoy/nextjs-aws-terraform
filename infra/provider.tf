terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 0.14.9"
}

provider "aws" {
  region     = var.region
  access_key = "AKIAW57ND72LQJVOHLMJ"
  secret_key = "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"
}
