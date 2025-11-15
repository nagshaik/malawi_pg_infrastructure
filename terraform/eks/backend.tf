terraform {
  backend "s3" {
    bucket  = "malawi-pg-tf-bucket"
    region  = "eu-central-1"
    key     = "eks/terraform.tfstate"
    encrypt = true
  }
}
