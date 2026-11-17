variable "talos_version" {
  type    = string
  default = "v1.14.6"
}

variable "talos_platform" {
  type = string
}

variable "image_upload_platform" {
  type = string
  validation {
    condition     = contains(["gcp", "aws"], var.image_upload_platform)
    error_message = "invalid value, can be either aws or gcp or empty"
  }
}

variable "talos_architecture" {
  type    = string
  default = "amd64"
  validation {
    condition     = contains(["amd64", "arm64"], var.talos_architecture)
    error_message = "invalid value, can be either amd64 or arm64"
  }
}

variable "gcp" {
  type = object({
    create_bucket     = optional(bool, true)
    project_id        = string
    bucket_name       = optional(string, "talos-images")
    storage_locations = optional(list(string), ["eu"])
  })
  default = null
}

variable "aws" {
  type = object({
    create_bucket          = optional(bool, true)
    bucket_name            = optional(string, "talos-images")
    tags                   = optional(map(string), {})
    region                 = optional(string, "eu-west-1")
    ami_additional_regions = optional(list(string), ["eu-west-1"])
    import_iam_role        = optional(string, "vmimport")
    create_iam_role        = optional(bool, true)
    partition              = optional(string, "aws")
  })
  default = null
}
