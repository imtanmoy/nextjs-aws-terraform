terraform {
  backend "s3" {
    bucket         = "terraform-backend-store-stage"
    encrypt        = true
    key            = "terraform.tfstate"
    region         = "ap-southeast-1"
#    dynamodb_table = "terraform-state-lock-dynamo-stage"
  }
}

#resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
#  name           = "terraform-state-lock-dynamo-${var.env}"
#  billing_mode   = "PAY_PER_REQUEST"
#  hash_key       = "LockID"
#  read_capacity  = 20
#  write_capacity = 20
#  attribute {
#    name = "LockID"
#    type = "S"
#  }
#  tags = {
#    Name = "DynamoDB Terraform State Lock Table"
#  }
#}