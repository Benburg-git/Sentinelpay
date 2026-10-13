terraform {
  backend "s3" {
    bucket       = "sentinelpay-terraform-state-3ed7fc7c"
    key          = "dev/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}