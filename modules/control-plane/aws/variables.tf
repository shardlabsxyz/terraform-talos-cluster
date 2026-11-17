variable "cluster_name" {
  description = "The name of the Talos cluster."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.cluster_name)) && length(var.cluster_name) <= 63
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens, start and end with alphanumeric, and be at most 63 characters"
  }
}

variable "irsa" {
  description = "Configuration for IAM Roles for Service Accounts (IRSA)."
  type = object({
    enabled = optional(bool, true)
  })
  default = {
    enabled = true
  }
}

variable "vpc_id" {
  description = "ID of the VPC where control plane will be deployed."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "VPC ID must be a valid AWS VPC ID (vpc-xxxxx)"
  }
}

variable "talos_version" {
  description = "The version of Talos OS to use for the control plane instances."
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
  description = "The version of Kubernetes to deploy on the Talos control plane."
  type        = string
  default     = "v1.36.6"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format vX.Y.Z"
  }
}

variable "control_plane" {
  description = "Configuration for the control plane instances."
  type = object({
    # Default instance type (can be overridden per node)
    instance_type = string
    subnet_ids    = list(string)

    # Root volume configuration (global)
    root_volume = optional(object({
      size_gb               = optional(number, 5)
      type                  = optional(string, "gp3")
      iops                  = optional(number, 3000)
      throughput            = optional(number, 125)
      encrypted             = optional(bool, true)
      kms_key_id            = optional(string)
      delete_on_termination = optional(bool, true)
    }), {})

    # Ephemeral volume configuration (persistent EBS for Talos EPHEMERAL partition - /var)
    ephemeral_volume = optional(object({
      enabled    = optional(bool, true)
      size_gb    = optional(number, 50)
      type       = optional(string, "gp3")
      iops       = optional(number, 3000)
      throughput = optional(number, 125)
      encrypted  = optional(bool, true)
      kms_key_id = optional(string)
    }), {})

    # Instance metadata configuration (IMDSv2)
    instance_metadata_options = optional(object({
      http_tokens                 = optional(string, "required")
      http_put_response_hop_limit = optional(number, 1)
      instance_metadata_tags      = optional(string, "disabled")
    }), {})

    # Tags (global)
    tags = optional(map(string), {})

    # Talos configuration patches (global, applied to all nodes)
    config_patches = optional(list(any), [])

    # Per-node configuration - map with explicit node keys
    # Each node MUST specify a private_ip for stable etcd identity
    nodes = map(object({
      subnet_id      = optional(string)     # Override AZ for this node (defaults to round-robin)
      private_ip     = optional(string)     # Fixed private IP for ENI (required for stable etcd identity)
      instance_type  = optional(string)     # Override instance type for this node
      enable_eip     = optional(bool, true) # Whether to attach an Elastic IP
      config_patches = optional(list(any))  # Additional Talos config patches for this node
      tags           = optional(map(string))
      root_volume = optional(object({
        size_gb               = optional(number)
        type                  = optional(string)
        iops                  = optional(number)
        throughput            = optional(number)
        encrypted             = optional(bool)
        kms_key_id            = optional(string)
        delete_on_termination = optional(bool)
      }), {})
      ephemeral_volume = optional(object({
        enabled               = optional(bool)
        size_gb               = optional(number)
        type                  = optional(string)
        iops                  = optional(number)
        throughput            = optional(number)
        encrypted             = optional(bool)
        kms_key_id            = optional(string)
        delete_on_termination = optional(bool)
      }), {})
      instance_metadata_options = optional(object({
        http_tokens                 = optional(string)
        http_put_response_hop_limit = optional(number)
        instance_metadata_tags      = optional(string)
      }), {})
    }))

  })

  validation {
    condition     = length(var.control_plane.nodes) >= 1 && length(var.control_plane.nodes) % 2 == 1
    error_message = "Control plane must have an odd number of nodes (1, 3, 5, 7, etc.) for etcd quorum"
  }
}

variable "nlb" {
  description = "Network Load Balancer configuration for Kubernetes API and Talos API."
  type = object({
    internal                         = optional(bool, false)
    enable_cross_zone_load_balancing = optional(bool, true)
    enable_deletion_protection       = optional(bool, true)

    # Kubernetes API target group configuration
    k8s_api = optional(object({
      deregistration_delay = optional(number, 10)
      health_check = optional(object({
        enabled             = optional(bool, true)
        interval            = optional(number, 10)
        healthy_threshold   = optional(number, 2)
        unhealthy_threshold = optional(number, 10)
        timeout             = optional(number, 5)
        port                = optional(number, 6443)
        protocol            = optional(string, "TCP")
      }), {})
    }), {})

    # Talos API target group configuration
    talos_api = optional(object({
      deregistration_delay = optional(number, 10)
      health_check = optional(object({
        enabled             = optional(bool, true)
        interval            = optional(number, 10)
        healthy_threshold   = optional(number, 2)
        unhealthy_threshold = optional(number, 10)
        timeout             = optional(number, 5)
      }), {})
    }), {})

    tags = optional(map(string), {})
  })
  default  = {}
  nullable = false
}

variable "cloudwatch" {
  description = "CloudWatch monitoring and alerting configuration."
  type = object({
    create_alarms       = optional(bool, true)
    alarm_sns_topic_arn = optional(string)
    tags                = optional(map(string), {})
  })
  default = {}
}

variable "security_group" {
  description = "Security group configuration for control plane instances."
  type = object({
    # Additional ingress rules
    additional_ingress_rules = optional(list(object({
      description = string
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    })), [])

    # Additional egress rules (default allows all outbound)
    additional_egress_rules = optional(list(object({
      description = string
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    })), [])

    # Allowed CIDR blocks for API access
    k8s_api_ingress_cidr_blocks        = optional(list(string), ["0.0.0.0/0"])
    talos_api_ingress_cidr_blocks      = optional(list(string), ["0.0.0.0/0"])
    talos_trustd_ingress_cidr_blocks   = optional(list(string), ["0.0.0.0/0"])
    talos_kubespan_ingress_cidr_blocks = optional(list(string), ["0.0.0.0/0"])

    tags = optional(map(string), {})
  })
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
