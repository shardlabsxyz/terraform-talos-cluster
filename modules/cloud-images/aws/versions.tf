terraform {
  required_version = ">= 1.13.0"
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "3.6.2"
    }
  }
}
