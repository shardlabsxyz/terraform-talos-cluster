variable "cluster_name" {
  description = "The name of the Talos cluster."
  type        = string
}

variable "project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
}

variable "region" {
  description = "The GCP region where resources will be created."
  type        = string
}

variable "talos_version" {
  description = "The version of Talos OS to use for the control plane instances."
  type        = string
  default     = "v1.14.6"
}

variable "talos_image" {
  description = "The Talos OS image details."
  type = object({
    family  = optional(string, "talos")
    name    = optional(string, "talos-v1-14-6-gcp-amd64")
    project = optional(string)
  })
  default = {
    family = "talos"
    name   = "talos-v1-14-6-gcp-amd64"
  }
}

variable "kubernetes_version" {
  description = "The version of Kubernetes to deploy on the Talos control plane."
  type        = string
  default     = "v1.36.6"
}

variable "control_plane" {
  description = "Configuration for the control plane instances."
  type = object({
    machine_type       = string
    target_size        = optional(number, 3)
    network_tags       = optional(list(string), ["control-plane"])
    labels             = optional(map(string))
    subnetwork         = optional(string)
    network            = optional(string)
    disk_size_gb       = optional(number, 50)
    disk_type          = optional(string, "pd-ssd")
    disk_labels        = optional(map(string))
    auto_delete        = optional(bool)
    wait_for_instances = optional(bool, true)
    mig_timeouts = optional(object({
      create = optional(string)
      update = optional(string)
      delete = optional(string)
      }),
      {
        create = "30m"
        update = "30m"
        delete = "30m"
      }
    )
    image = optional(object({
      family  = optional(string)
      name    = optional(string)
      project = optional(string)
      }),
      {
        family  = null
        name    = null
        project = null
      }
    )
    config_patches = optional(list(any), [])
    update_policy = optional(object({
      max_surge_fixed                = optional(number)
      instance_redistribution_type   = optional(string)
      max_surge_percent              = optional(number)
      max_unavailable_fixed          = optional(number)
      max_unavailable_percent        = optional(number)
      min_ready_sec                  = optional(number)
      replacement_method             = optional(string)
      minimal_action                 = string
      type                           = string
      most_disruptive_allowed_action = optional(string)
      }),
      {
        type                           = "PROACTIVE"
        minimal_action                 = "REFRESH"
        max_unavailable_fixed          = 3
        min_ready_sec                  = 10
        max_surge_fixed                = 0
        replacement_method             = "RECREATE"
        most_disruptive_allowed_action = "REFRESH"
        instance_redistribution_type   = "NONE"
    })

    health_check = optional(object({
      type                = string
      initial_delay_sec   = number
      check_interval_sec  = number
      healthy_threshold   = number
      timeout_sec         = number
      unhealthy_threshold = number
      response            = string
      proxy_header        = string
      port                = number
      request             = string
      request_path        = string
      host                = string
      enable_logging      = bool
      }),
      {
        type                = "tcp"
        initial_delay_sec   = "10"
        check_interval_sec  = "10"
        healthy_threshold   = "1"
        timeout_sec         = "10"
        unhealthy_threshold = "5"
        port                = "50000"
        enable_logging      = true
        proxy_header        = null
        host                = null
        response            = null
        request_path        = null
        request             = null
      }
    )
  })
}
