terraform {
  backend "s3" {
    bucket         = "serverless-practice-tf-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "serverless-practice-tf"
  }
}

