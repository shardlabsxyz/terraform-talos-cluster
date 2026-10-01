terraform {
  required_version = ">= 1.13.0"
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.12.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "< 8.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "< 8.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
