variable "project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
  default     = "sandbox-archi-0"
}

variable "region" {
  description = "The GCP region where resources will be created."
  type        = string
  default     = "europe-west1"
}

variable "region_secondary" {
  description = "The secondary GCP region for additional resources."
  type        = string
  default     = "europe-west4"
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
