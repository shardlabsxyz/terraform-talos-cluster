variable "region" {
  description = "The AWS region where resources will be created."
  type        = string
  default     = "eu-west-1"
}

variable "region_secondary" {
  description = "The secondary AWS region for additional resources."
  type        = string
  default     = "eu-west-3"
}

variable "cluster_name" {
  description = "The name of the Talos cluster."
  type        = string
  default     = "talos-demo-cluster"
}

variable "kubernetes_version" {
  description = "The version of Kubernetes to deploy."
  type        = string
  default     = "v1.36.6"
}

variable "talos_version" {
  description = "The version of Talos OS to use."
  type        = string
  default     = "v1.14.6"
}
