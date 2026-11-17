variable "cluster_name" {
  description = "The name of the Talos cluster."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.cluster_name)) && length(var.cluster_name) <= 63
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens, start and end with alphanumeric, and be at most 63 characters"
  }
}

variable "vpc_id" {
  description = "ID of the VPC where node pools will be deployed."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "VPC ID must be a valid AWS VPC ID (vpc-xxxxx)"
  }
}

variable "talos_version" {
  description = "The version of Talos OS to use for the node pool instances."
  type        = string
  default     = "v1.14.6"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.talos_version))
    error_message = "Talos version must be in format vX.Y.Z"
  }
}

variable "talos_image_id" {
  description = "Talos OS AMI ID. Use the cloud-images module to get the official AMI ID for your region."
  type        = string
}

variable "kubernetes_version" {
  description = "The version of Kubernetes to deploy on the node pools."
  type        = string
  default     = "v1.36.6"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format vX.Y.Z"
  }
}

variable "kubernetes_api_url" {
  description = "The URL of the Kubernetes API server."
  type        = string
}

variable "talos_machine_secrets" {
  description = "Talos machine secrets from the control plane."
  type        = any
}

variable "talos_client_configuration" {
  description = "Talos client configuration from the control plane."
  type        = any
}

variable "node_pools" {
  description = "Configuration for the worker node pools."
  type = map(object({
    # Instance configuration
    instance_type    = string
    desired_capacity = optional(number, 3)
    min_size         = optional(number, 1)
    max_size         = optional(number, 10)

    # Network configuration
    subnet_ids          = list(string)
    associate_public_ip = optional(bool, true)

    # Kubernetes node configuration
    # Labels are applied via kubelet extraArgs and used for CA node templates
    labels = optional(map(string), {})

    # Taints are applied via kubelet registerWithTaints and used for CA node templates
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string # NoSchedule, NoExecute, or PreferNoSchedule
    })), [])

    # Cluster Autoscaler - when enabled, ASG tags are auto-derived from labels/taints
    enable_cluster_autoscaler = optional(bool, false)

    # Volume configuration (root volume only, ephemeral)
    root_volume = optional(object({
      size_gb               = optional(number, 50)
      type                  = optional(string, "gp3")
      iops                  = optional(number, 3000)
      throughput            = optional(number, 125)
      encrypted             = optional(bool, true)
      delete_on_termination = optional(bool, true)
    }), {})

    # Instance metadata (IMDSv2)
    instance_metadata = optional(object({
      http_tokens                 = optional(string, "required")
      http_put_response_hop_limit = optional(number, 1)
      instance_metadata_tags      = optional(string, "disabled")
    }), {})

    # ASG configuration
    health_check_type         = optional(string, "EC2")
    health_check_grace_period = optional(number, 300)
    default_cooldown          = optional(number, 300)

    # Launch template version control - when true, ASG uses $Latest version triggering instance refresh
    update_launch_template_default_version = optional(bool, true)

    # Instance refresh configuration (always enabled, version controls when refresh happens)
    instance_refresh = optional(object({
      min_healthy_percentage       = optional(number, 90)
      max_healthy_percentage       = optional(number, 100)
      instance_warmup              = optional(number, 60)
      checkpoint_delay             = optional(number)
      checkpoint_percentages       = optional(list(number))
      skip_matching                = optional(bool, false)
      auto_rollback                = optional(bool, false)
      scale_in_protected_instances = optional(string, "Ignore")
      standby_instances            = optional(string, "Ignore")
      alarm_specification = optional(object({
        alarms = list(string)
      }))
    }), {})

    # Talos configuration patches (additional patches beyond labels/taints)
    config_patches = optional(list(any), [])

    # Tags
    tags = optional(map(string), {})
  }))

  validation {
    condition     = length(var.node_pools) >= 1
    error_message = "At least one node pool must be defined"
  }

  validation {
    condition     = alltrue([for k, v in var.node_pools : length(v.subnet_ids) >= 1])
    error_message = "Each node pool must have at least one subnet"
  }
}

variable "tags" {
  description = "Tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
