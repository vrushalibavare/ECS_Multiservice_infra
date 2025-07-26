terraform {
  required_version = ">= 1.0.0"
  backend "s3" {
    bucket = "sctp-ce10-tfstate"
    key    = "vrush-coaching18-tfstate"
    region = "ap-southeast-1"
  }
}