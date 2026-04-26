terraform {
  backend "s3" {
    # IMPORTANT: Replace "your-roll-number" with the same suffix you use in main.tf
    bucket = "assignment3-tfstate-13b3b0cc"
    key            = "assignment3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "assignment3-tf-lock"
    encrypt        = true
  }
}
