variable "talos_version" {
  type    = string
  default = "v1.14.6"
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "arch" {
  type    = string
  default = "amd64"
  validation {
    condition     = contains(["amd64", "arm64"], var.arch)
    error_message = "Architecture must be either 'amd64' or 'arm64'."
  }
}
