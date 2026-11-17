# AWS Control Plane Module for Talos Kubernetes

This module deploys a highly available Talos Kubernetes control plane on AWS with Network Load Balancer, IRSA support, and CloudWatch monitoring.

## Features

- **Per-node architecture**: Each control plane node has dedicated ENI, EIP, and EBS volumes for stable etcd identity
- **Network Load Balancer**: Exposes Kubernetes API (6443) and Talos API (50000)
- **IRSA support**: Native AWS IAM integration for Kubernetes service accounts
- **Kubespan enabled**: WireGuard mesh networking for hybrid cluster connectivity
- **CloudWatch alarms**: Optional monitoring for unhealthy target groups
- **IMDSv2 enforced**: Secure instance metadata service by default

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS Control Plane                               │
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │     cp-0        │  │     cp-1        │  │     cp-2        │         │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────┐  │         │
│  │  │ EC2       │  │  │  │ EC2       │  │  │  │ EC2       │  │         │
│  │  │ Instance  │  │  │  │ Instance  │  │  │  │ Instance  │  │         │
│  │  └─────┬─────┘  │  │  └─────┬─────┘  │  │  └─────┬─────┘  │         │
│  │        │        │  │        │        │  │        │        │         │
│  │  ┌─────┴─────┐  │  │  ┌─────┴─────┐  │  │  ┌─────┴─────┐  │         │
│  │  │    ENI    │  │  │  │    ENI    │  │  │  │    ENI    │  │         │
│  │  │ (fixed IP)│  │  │  │ (fixed IP)│  │  │  │ (fixed IP)│  │         │
│  │  └─────┬─────┘  │  │  └─────┬─────┘  │  │  └─────┬─────┘  │         │
│  │        │        │  │        │        │  │        │        │         │
│  │  ┌─────┴─────┐  │  │  ┌─────┴─────┐  │  │  ┌─────┴─────┐  │         │
│  │  │    EIP    │  │  │  │    EIP    │  │  │  │    EIP    │  │         │
│  │  └───────────┘  │  │  └───────────┘  │  │  └───────────┘  │         │
│  │                 │  │                 │  │                 │         │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────┐  │         │
│  │  │ EBS Vol   │  │  │  │ EBS Vol   │  │  │  │ EBS Vol   │  │         │
│  │  │ (etcd)    │  │  │  │ (etcd)    │  │  │  │ (etcd)    │  │         │
│  │  └───────────┘  │  │  └───────────┘  │  │  └───────────┘  │         │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘         │
│           │                    │                    │                   │
│           └────────────────────┼────────────────────┘                   │
│                                │                                        │
│                    ┌───────────┴───────────┐                            │
│                    │    Network Load       │                            │
│                    │    Balancer (NLB)     │                            │
│                    │  ├── :6443 (K8s API)  │                            │
│                    │  └── :50000 (Talos)   │                            │
│                    └───────────────────────┘                            │
└─────────────────────────────────────────────────────────────────────────┘
```

### Why Per-Node Resources?

Unlike worker nodes which are ephemeral, control plane nodes need **stable identity** for etcd:

1. **Fixed ENI with private IP**: etcd identifies peers by IP. Changing IPs breaks cluster.
2. **Persistent EBS volume**: etcd data must survive instance replacement.
3. **Elastic IP**: Stable public endpoint for Talos API access.

This architecture allows replacing a control plane instance without losing its identity:
- New instance attaches to existing ENI → same private IP
- New instance attaches to existing EBS → same etcd data
- EIP moves to new instance → same public endpoint

## Usage

### Basic Example

```hcl
module "talos_ami" {
  source        = "github.com/shardlabsxyz/terraform-talos-cluster//modules/cloud-images/aws"
  talos_version = "v1.14.6"
  region        = "us-west-2"
}

module "control_plane" {
  source = "github.com/shardlabsxyz/terraform-talos-cluster//modules/control-plane/aws"

  cluster_name       = "my-cluster"
  vpc_id             = "vpc-12345678"
  talos_image_id     = module.talos_ami.ami_id
  kubernetes_version = "v1.36.6"
  talos_version      = "v1.14.6"

  control_plane = {
    instance_type = "m6i.large"
    subnet_ids    = ["subnet-aaa", "subnet-bbb", "subnet-ccc"]

    nodes = {
      "cp-0" = {}
      "cp-1" = {}
      "cp-2" = {}
    }
  }
}
```

### With IRSA (IAM Roles for Service Accounts)

IRSA allows Kubernetes pods to assume AWS IAM roles without storing credentials. This module sets up the required OIDC provider and S3 bucket automatically.

```hcl
module "control_plane" {
  source = "github.com/shardlabsxyz/terraform-talos-cluster//modules/control-plane/aws"

  cluster_name       = "my-cluster"
  vpc_id             = "vpc-12345678"
  talos_image_id     = module.talos_ami.ami_id
  kubernetes_version = "v1.36.6"
  talos_version      = "v1.14.6"

  control_plane = {
    instance_type = "m6i.large"
    subnet_ids    = ["subnet-aaa", "subnet-bbb", "subnet-ccc"]
    nodes = {
      "cp-0" = {}
      "cp-1" = {}
      "cp-2" = {}
    }
  }

  # Enable IRSA
  irsa = {
    enabled = true
  }
}

# Use the OIDC provider ARN for IAM role trust policies
output "irsa_oidc_provider_arn" {
  value = module.control_plane.irsa_oidc_provider_arn
}
```

**Using IRSA with add-ons (e.g., AWS Load Balancer Controller):**

```hcl
module "aws_load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.control_plane.irsa_oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
```

### Advanced: Custom Node Configuration

```hcl
module "control_plane" {
  source = "github.com/shardlabsxyz/terraform-talos-cluster//modules/control-plane/aws"

  cluster_name       = "production-cluster"
  vpc_id             = module.vpc.vpc_id
  talos_image_id     = module.talos_ami.ami_id
  kubernetes_version = "v1.36.6"
  talos_version      = "v1.14.6"

  control_plane = {
    instance_type = "m6i.xlarge"
    subnet_ids    = module.vpc.public_subnets

    # Root volume for Talos OS
    root_volume = {
      size_gb   = 20
      type      = "gp3"
      iops      = 3000
      encrypted = true
    }

    # Ephemeral volume for /var (etcd data, logs, etc.)
    ephemeral_volume = {
      enabled    = true
      size_gb    = 100
      type       = "gp3"
      iops       = 6000
      throughput = 250
      encrypted  = true
    }

    # Per-node configuration
    nodes = {
      "cp-0" = {
        private_ip    = "10.0.1.10"  # Fixed IP for etcd stability
        instance_type = "m6i.2xlarge"  # Override for this node
      }
      "cp-1" = {
        private_ip = "10.0.2.10"
      }
      "cp-2" = {
        private_ip = "10.0.3.10"
      }
    }

    # Global Talos config patches (applied to all nodes)
    config_patches = [
      yamlencode({
        machine = {
          sysctls = {
            "net.core.somaxconn" = "65535"
          }
        }
      })
    ]
  }

  nlb = {
    internal                         = false
    enable_cross_zone_load_balancing = true
    enable_deletion_protection       = true
  }

  cloudwatch = {
    create_alarms       = true
    alarm_sns_topic_arn = aws_sns_topic.alerts.arn
  }

  security_group = {
    k8s_api_ingress_cidr_blocks   = ["10.0.0.0/8"]  # Restrict API access
    talos_api_ingress_cidr_blocks = ["10.0.0.0/8"]
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### Private Control Plane (No Public IPs)

For private clusters accessible only via VPN or Direct Connect:

```hcl
module "control_plane" {
  source = "github.com/shardlabsxyz/terraform-talos-cluster//modules/control-plane/aws"

  cluster_name       = "private-cluster"
  vpc_id             = module.vpc.vpc_id
  talos_image_id     = module.talos_ami.ami_id
  kubernetes_version = "v1.36.6"
  talos_version      = "v1.14.6"

  control_plane = {
    instance_type = "m6i.large"
    subnet_ids    = module.vpc.private_subnets  # Private subnets

    nodes = {
      "cp-0" = { enable_eip = false }
      "cp-1" = { enable_eip = false }
      "cp-2" = { enable_eip = false }
    }
  }

  nlb = {
    internal = true  # Internal NLB
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `cluster_name` | Name of the Talos cluster (alphanumeric, hyphens, max 63 chars) | `string` | n/a | yes |
| `vpc_id` | VPC ID for control plane resources | `string` | n/a | yes |
| `talos_image_id` | Talos AMI ID (use cloud-images/aws module to get this) | `string` | n/a | yes |
| `kubernetes_version` | Kubernetes version | `string` | `"v1.36.6"` | no |
| `talos_version` | Talos OS version | `string` | `"v1.14.6"` | no |
| `control_plane` | Control plane configuration (see below) | `object` | n/a | yes |
| `irsa` | IRSA configuration | `object` | `{ enabled = true }` | no |
| `nlb` | Network Load Balancer configuration | `object` | `{}` | no |
| `cloudwatch` | CloudWatch monitoring configuration | `object` | `{}` | no |
| `security_group` | Security group configuration | `object` | `{}` | no |
| `tags` | Tags for all resources | `map(string)` | `{}` | no |

### Control Plane Configuration

```hcl
control_plane = {
  instance_type = "m6i.large"      # Default instance type
  subnet_ids    = ["subnet-xxx"]   # Subnets for control plane

  # Root volume (Talos OS)
  root_volume = {
    size_gb   = 20
    type      = "gp3"
    iops      = 3000
    encrypted = true
  }

  # Ephemeral volume (/var partition - etcd, logs)
  ephemeral_volume = {
    enabled    = true
    size_gb    = 50
    type       = "gp3"
    iops       = 3000
    throughput = 125
    encrypted  = true
  }

  # Per-node configuration (must be odd number: 1, 3, 5, 7)
  nodes = {
    "cp-0" = {
      subnet_id      = "subnet-xxx"   # Override subnet
      private_ip     = "10.0.1.10"    # Fixed private IP
      instance_type  = "m6i.xlarge"   # Override instance type
      enable_eip     = true           # Attach Elastic IP
      config_patches = []             # Node-specific Talos patches
    }
  }

  # Global Talos config patches
  config_patches = []
}
```

## Outputs

| Name | Description |
|------|-------------|
| `instances` | Control plane instance details (id, subnet, IPs) |
| `network_interfaces` | ENI details |
| `elastic_ips` | EIP details |
| `external_ips` | List of public IPs |
| `private_ips` | List of private IPs |
| `kubernetes_api_ip` | NLB DNS name |
| `kubernetes_api_url` | Full Kubernetes API URL |
| `load_balancer` | NLB details (ARN, DNS, zone ID) |
| `irsa_oidc_provider_arn` | IRSA OIDC provider ARN |
| `irsa_oidc_issuer_url` | IRSA OIDC issuer URL |
| `security_group_id` | Security group ID |
| `iam_role_arn` | Instance IAM role ARN |
| `talos_machine_secrets` | Talos secrets (sensitive) |
| `talos_client_configuration` | Talos client config (sensitive) |
| `kubeconfig` | Kubernetes kubeconfig (sensitive) |

## Network Ports

| Port | Protocol | Purpose | Source |
|------|----------|---------|--------|
| 6443 | TCP | Kubernetes API | Configurable CIDR |
| 50000 | TCP | Talos API | Configurable CIDR |
| 50001 | TCP | Talos Trustd | Configurable CIDR |
| 51820 | UDP | Kubespan (WireGuard) | 0.0.0.0/0 |

## Integration with Node Pools

```hcl
module "control_plane" {
  source = "github.com/shardlabsxyz/terraform-talos-cluster//modules/control-plane/aws"
  # ... configuration
}

module "node_pools" {
  source = "github.com/shardlabsxyz/terraform-talos-cluster//modules/node-pools/aws"

  cluster_name   = var.cluster_name
  vpc_id         = module.vpc.vpc_id
  talos_image_id = module.talos_ami.ami_id

  # Required from control plane
  kubernetes_api_url         = module.control_plane.kubernetes_api_url
  talos_client_configuration = module.control_plane.talos_client_configuration
  talos_machine_secrets      = module.control_plane.talos_machine_secrets

  node_pools = {
    general = {
      instance_type    = "m6i.large"
      desired_capacity = 3
      subnet_ids       = module.vpc.private_subnets
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.13.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.73 |
| <a name="requirement_external"></a> [external](#requirement\_external) | ~> 2.4 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.12.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.4 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.73 |
| <a name="provider_external"></a> [external](#provider\_external) | ~> 2.4 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.12.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~> 4.4 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_irsa_s3_bucket"></a> [irsa\_s3\_bucket](#module\_irsa\_s3\_bucket) | terraform-aws-modules/s3-bucket/aws | ~> 5.18 |
| <a name="module_irsa_s3_bucket_object_keys_json"></a> [irsa\_s3\_bucket\_object\_keys\_json](#module\_irsa\_s3\_bucket\_object\_keys\_json) | terraform-aws-modules/s3-bucket/aws//modules/object | ~> 5.18 |
| <a name="module_irsa_s3_bucket_object_openid-configuration"></a> [irsa\_s3\_bucket\_object\_openid-configuration](#module\_irsa\_s3\_bucket\_object\_openid-configuration) | terraform-aws-modules/s3-bucket/aws//modules/object | ~> 5.18 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_metric_alarm.instance_status_check](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.nlb_unhealthy_hosts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_ebs_volume.ephemeral](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_eip.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip_association.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip_association) | resource |
| [aws_iam_instance_profile.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_openid_connect_provider.irsa_oidc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_instance.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_lb.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.k8s_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.talos_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.k8s_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.talos_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.k8s_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_lb_target_group_attachment.talos_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_network_interface.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_interface) | resource |
| [aws_security_group.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.additional_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.additional_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.egress_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.icmp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.internal_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.k8s_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.kubespan_discovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.kubespan_wireguard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.talos_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.talos_trustd](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_volume_attachment.ephemeral](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/volume_attachment) | resource |
| [talos_cluster_kubeconfig.talos](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.talos](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.control_plane](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.talos](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/machine_secrets) | resource |
| [tls_private_key.irsa_oidc](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [aws_subnet.control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [external_external.modulus](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [external_external.pub_der](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [talos_machine_configuration.control_plane](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/data-sources/machine_configuration) | data source |
| [tls_certificate.irsa_oidc](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cloudwatch"></a> [cloudwatch](#input\_cloudwatch) | CloudWatch monitoring and alerting configuration. | <pre>object({<br/>    create_alarms       = optional(bool, true)<br/>    alarm_sns_topic_arn = optional(string)<br/>    tags                = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the Talos cluster. | `string` | n/a | yes |
| <a name="input_control_plane"></a> [control\_plane](#input\_control\_plane) | Configuration for the control plane instances. | <pre>object({<br/>    # Default instance type (can be overridden per node)<br/>    instance_type = string<br/>    subnet_ids    = list(string)<br/><br/>    # Root volume configuration (global)<br/>    root_volume = optional(object({<br/>      size_gb               = optional(number, 5)<br/>      type                  = optional(string, "gp3")<br/>      iops                  = optional(number, 3000)<br/>      throughput            = optional(number, 125)<br/>      encrypted             = optional(bool, true)<br/>      kms_key_id            = optional(string)<br/>      delete_on_termination = optional(bool, true)<br/>    }), {})<br/><br/>    # Ephemeral volume configuration (persistent EBS for Talos EPHEMERAL partition - /var)<br/>    ephemeral_volume = optional(object({<br/>      enabled    = optional(bool, true)<br/>      size_gb    = optional(number, 50)<br/>      type       = optional(string, "gp3")<br/>      iops       = optional(number, 3000)<br/>      throughput = optional(number, 125)<br/>      encrypted  = optional(bool, true)<br/>      kms_key_id = optional(string)<br/>    }), {})<br/><br/>    # Instance metadata configuration (IMDSv2)<br/>    instance_metadata_options = optional(object({<br/>      http_tokens                 = optional(string, "required")<br/>      http_put_response_hop_limit = optional(number, 1)<br/>      instance_metadata_tags      = optional(string, "disabled")<br/>    }), {})<br/><br/>    # Tags (global)<br/>    tags = optional(map(string), {})<br/><br/>    # Talos configuration patches (global, applied to all nodes)<br/>    config_patches = optional(list(any), [])<br/><br/>    # Per-node configuration - map with explicit node keys<br/>    # Each node MUST specify a private_ip for stable etcd identity<br/>    nodes = map(object({<br/>      subnet_id      = optional(string)     # Override AZ for this node (defaults to round-robin)<br/>      private_ip     = optional(string)     # Fixed private IP for ENI (required for stable etcd identity)<br/>      instance_type  = optional(string)     # Override instance type for this node<br/>      enable_eip     = optional(bool, true) # Whether to attach an Elastic IP<br/>      config_patches = optional(list(any))  # Additional Talos config patches for this node<br/>      tags           = optional(map(string))<br/>      root_volume = optional(object({<br/>        size_gb               = optional(number)<br/>        type                  = optional(string)<br/>        iops                  = optional(number)<br/>        throughput            = optional(number)<br/>        encrypted             = optional(bool)<br/>        kms_key_id            = optional(string)<br/>        delete_on_termination = optional(bool)<br/>      }), {})<br/>      ephemeral_volume = optional(object({<br/>        enabled               = optional(bool)<br/>        size_gb               = optional(number)<br/>        type                  = optional(string)<br/>        iops                  = optional(number)<br/>        throughput            = optional(number)<br/>        encrypted             = optional(bool)<br/>        kms_key_id            = optional(string)<br/>        delete_on_termination = optional(bool)<br/>      }), {})<br/>      instance_metadata_options = optional(object({<br/>        http_tokens                 = optional(string)<br/>        http_put_response_hop_limit = optional(number)<br/>        instance_metadata_tags      = optional(string)<br/>      }), {})<br/>    }))<br/><br/>  })</pre> | n/a | yes |
| <a name="input_irsa"></a> [irsa](#input\_irsa) | Configuration for IAM Roles for Service Accounts (IRSA). | <pre>object({<br/>    enabled = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "enabled": true<br/>}</pre> | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | The version of Kubernetes to deploy on the Talos control plane. | `string` | `"v1.36.6"` | no |
| <a name="input_nlb"></a> [nlb](#input\_nlb) | Network Load Balancer configuration for Kubernetes API and Talos API. | <pre>object({<br/>    internal                         = optional(bool, false)<br/>    enable_cross_zone_load_balancing = optional(bool, true)<br/>    enable_deletion_protection       = optional(bool, true)<br/><br/>    # Kubernetes API target group configuration<br/>    k8s_api = optional(object({<br/>      deregistration_delay = optional(number, 10)<br/>      health_check = optional(object({<br/>        enabled             = optional(bool, true)<br/>        interval            = optional(number, 10)<br/>        healthy_threshold   = optional(number, 2)<br/>        unhealthy_threshold = optional(number, 10)<br/>        timeout             = optional(number, 5)<br/>        port                = optional(number, 6443)<br/>        protocol            = optional(string, "TCP")<br/>      }), {})<br/>    }), {})<br/><br/>    # Talos API target group configuration<br/>    talos_api = optional(object({<br/>      deregistration_delay = optional(number, 10)<br/>      health_check = optional(object({<br/>        enabled             = optional(bool, true)<br/>        interval            = optional(number, 10)<br/>        healthy_threshold   = optional(number, 2)<br/>        unhealthy_threshold = optional(number, 10)<br/>        timeout             = optional(number, 5)<br/>      }), {})<br/>    }), {})<br/><br/>    tags = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_security_group"></a> [security\_group](#input\_security\_group) | Security group configuration for control plane instances. | <pre>object({<br/>    # Additional ingress rules<br/>    additional_ingress_rules = optional(list(object({<br/>      description = string<br/>      from_port   = number<br/>      to_port     = number<br/>      protocol    = string<br/>      cidr_blocks = list(string)<br/>    })), [])<br/><br/>    # Additional egress rules (default allows all outbound)<br/>    additional_egress_rules = optional(list(object({<br/>      description = string<br/>      from_port   = number<br/>      to_port     = number<br/>      protocol    = string<br/>      cidr_blocks = list(string)<br/>    })), [])<br/><br/>    # Allowed CIDR blocks for API access<br/>    k8s_api_ingress_cidr_blocks        = optional(list(string), ["0.0.0.0/0"])<br/>    talos_api_ingress_cidr_blocks      = optional(list(string), ["0.0.0.0/0"])<br/>    talos_trustd_ingress_cidr_blocks   = optional(list(string), ["0.0.0.0/0"])<br/>    talos_kubespan_ingress_cidr_blocks = optional(list(string), ["0.0.0.0/0"])<br/><br/>    tags = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources created by this module. | `map(string)` | `{}` | no |
| <a name="input_talos_image_id"></a> [talos\_image\_id](#input\_talos\_image\_id) | Talos OS AMI ID. Use the cloud-images module to get the official AMI ID for your region. | `string` | n/a | yes |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | The version of Talos OS to use for the control plane instances. | `string` | `"v1.14.6"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where control plane will be deployed. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_elastic_ips"></a> [elastic\_ips](#output\_elastic\_ips) | Elastic IP information |
| <a name="output_ephemeral_volumes"></a> [ephemeral\_volumes](#output\_ephemeral\_volumes) | EBS volumes for Talos ephemeral partition (/var) |
| <a name="output_external_ips"></a> [external\_ips](#output\_external\_ips) | External IP addresses of control plane instances (EIPs) |
| <a name="output_iam_instance_profile_name"></a> [iam\_instance\_profile\_name](#output\_iam\_instance\_profile\_name) | IAM instance profile name for control plane instances |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | IAM role ARN for control plane instances |
| <a name="output_instances"></a> [instances](#output\_instances) | Control plane instance information |
| <a name="output_irsa_oidc_issuer_url"></a> [irsa\_oidc\_issuer\_url](#output\_irsa\_oidc\_issuer\_url) | IRSA OIDC issuer URL |
| <a name="output_irsa_oidc_provider_arn"></a> [irsa\_oidc\_provider\_arn](#output\_irsa\_oidc\_provider\_arn) | IRSA OIDC provider ARN |
| <a name="output_irsa_private_key"></a> [irsa\_private\_key](#output\_irsa\_private\_key) | IRSA private key for service account signing |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubernetes kubeconfig for kubectl access |
| <a name="output_kubernetes_api_ip"></a> [kubernetes\_api\_ip](#output\_kubernetes\_api\_ip) | Kubernetes API endpoint IP address (NLB DNS name) |
| <a name="output_kubernetes_api_url"></a> [kubernetes\_api\_url](#output\_kubernetes\_api\_url) | Kubernetes API endpoint URL |
| <a name="output_load_balancer"></a> [load\_balancer](#output\_load\_balancer) | Network Load Balancer information |
| <a name="output_network_interfaces"></a> [network\_interfaces](#output\_network\_interfaces) | Network interface information |
| <a name="output_private_ips"></a> [private\_ips](#output\_private\_ips) | Private IP addresses of control plane instances |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID for control plane instances |
| <a name="output_talos_ami"></a> [talos\_ami](#output\_talos\_ami) | Talos AMI used for control plane instances |
| <a name="output_talos_client_configuration"></a> [talos\_client\_configuration](#output\_talos\_client\_configuration) | Talos client configuration for talosctl |
| <a name="output_talos_machine_secrets"></a> [talos\_machine\_secrets](#output\_talos\_machine\_secrets) | Talos machine secrets (sensitive) |
<!-- END_TF_DOCS -->
