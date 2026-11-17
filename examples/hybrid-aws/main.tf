provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "secondary"
  region = var.region_secondary
}

provider "helm" {
  kubernetes = {
    host                   = module.control_plane.kubeconfig != null ? yamldecode(module.control_plane.kubeconfig).clusters[0].cluster.server : ""
    cluster_ca_certificate = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).clusters[0].cluster["certificate-authority-data"]) : ""
    client_certificate     = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).users[0].user["client-certificate-data"]) : ""
    client_key             = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).users[0].user["client-key-data"]) : ""
  }
}

provider "kubernetes" {
  host                   = module.control_plane.kubeconfig != null ? yamldecode(module.control_plane.kubeconfig).clusters[0].cluster.server : ""
  cluster_ca_certificate = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).clusters[0].cluster["certificate-authority-data"]) : ""
  client_certificate     = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).users[0].user["client-certificate-data"]) : ""
  client_key             = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).users[0].user["client-key-data"]) : ""
}

provider "kubectl" {
  host                   = module.control_plane.kubeconfig != null ? yamldecode(module.control_plane.kubeconfig).clusters[0].cluster.server : ""
  cluster_ca_certificate = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).clusters[0].cluster["certificate-authority-data"]) : ""
  client_certificate     = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).users[0].user["client-certificate-data"]) : ""
  client_key             = module.control_plane.kubeconfig != null ? base64decode(yamldecode(module.control_plane.kubeconfig).users[0].user["client-key-data"]) : ""
  load_config_file       = false
}

module "talos_ami" {
  source        = "../../modules/cloud-images/aws"
  talos_version = var.talos_version
  region        = var.region
}

module "talos_ami_secondary" {
  source = "../../modules/cloud-images/aws"

  talos_version = var.talos_version
  region        = var.region_secondary
}

data "aws_availability_zones" "primary" {
  state = "available"
}

data "aws_availability_zones" "secondary" {
  provider = aws.secondary
  state    = "available"
}

module "vpc_primary" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.8"

  name = var.cluster_name
  cidr = "10.1.0.0/16"

  azs             = slice(data.aws_availability_zones.primary.names, 0, 3)
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Terraform   = "true"
    Environment = "demo"
    Cluster     = var.cluster_name
  }
}


module "control_plane" {
  source = "../../modules/control-plane/aws"

  cluster_name = var.cluster_name
  vpc_id       = module.vpc_primary.vpc_id

  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version
  talos_image_id     = module.talos_ami.ami_id

  irsa = {
    enabled = true
  }

  control_plane = {
    instance_type = "m6i.large"
    subnet_ids    = module.vpc_primary.public_subnets

    nodes = {
      "cp-0" = {}
      "cp-1" = {}
      "cp-2" = {}
    }

    root_volume = {
      size_gb = 20
      type    = "gp3"
    }

    ephemeral_volume = {
      enabled = true
      size_gb = 20
    }
  }

  nlb = {
    internal                   = false
    enable_deletion_protection = false
  }

  cloudwatch = {
    create_alarms = true
  }

  tags = {
    Terraform   = "true"
    Environment = "demo"
  }
}

data "talos_client_configuration" "talos" {
  cluster_name         = var.cluster_name
  client_configuration = module.control_plane.talos_client_configuration
  endpoints            = [module.control_plane.load_balancer.dns_name]
  nodes = concat(
    module.control_plane.private_ips,
    module.node_pools_primary.private_ips,
    # module.node_pools_secondary.private_ips  # Uncomment when enabling secondary region
  )
}

resource "talos_cluster_kubeconfig" "talos" {
  client_configuration = module.control_plane.talos_client_configuration
  endpoint             = module.control_plane.load_balancer.dns_name
  node                 = module.control_plane.private_ips[0]
}


module "cilium" {
  source = "github.com/shardlabsxyz/terraform-kubernetes-addons//modules/talos?ref=v1.11.0"

  cluster_name = var.cluster_name

  addons = {
    cilium = {
      enabled = true
    }
  }
}

module "aws-cloud-controller-manager" {
  source = "github.com/shardlabsxyz/terraform-kubernetes-addons//modules/talos?ref=v1.11.0"

  cluster_name = var.cluster_name

  addons = {
    aws-cloud-controller-manager = {
      enabled      = true
      extra_values = <<-EXTRA_VALUES
      image:
        tag: ${var.kubernetes_version}
      EXTRA_VALUES
    }
  }
}

module "cert_manager" {
  source = "github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws?ref=v1.11.0"

  cluster_name = var.cluster_name

  aws = {
    region = var.region
  }

  addons = {
    cert-manager = {
      enabled = true
      iam = {
        eks_pod_identity = {
          enabled = false
        }
      }
    }
  }
}

module "amazon-eks-pod-identity-webhook" {
  depends_on = [module.cert_manager]

  source = "github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws?ref=v1.11.0"

  cluster_name = var.cluster_name

  aws = {
    region = var.region
  }

  addons = {
    amazon-eks-pod-identity-webhook = {
      enabled = true
    }
  }
}

module "aws_ebs_csi_driver" {
  source = "github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws?ref=v1.11.0"

  cluster_name = var.cluster_name

  aws = {
    region = var.region
  }

  addons = {
    aws-ebs-csi-driver = {
      enabled = true
      iam = {
        eks_pod_identity = {
          enabled = false
        }
        irsa = {
          enabled           = true
          oidc_provider_arn = module.control_plane.irsa_oidc_provider_arn
        }
      }
      kubernetes_manifests = {
        volume_snapshot_class = {
          enabled = false
        }
      }
      helm_release = {
        extra_values = <<-EOF
          controller:
            nodeSelector:
              node.cloudprovider.kubernetes.io/platform: aws
              topology.kubernetes.io/region: eu-west-1
          node:
            nodeSelector:
              node.cloudprovider.kubernetes.io/platform: aws
              topology.kubernetes.io/region: eu-west-1
          EOF
      }
    }
  }
}

module "aws_load_balancer_controller" {
  source = "github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws?ref=v1.11.0"

  cluster_name = var.cluster_name

  aws = {
    region = var.region
  }

  addons = {
    aws-load-balancer-controller = {
      enabled = true
      iam = {
        eks_pod_identity = {
          enabled = false
        }
        irsa = {
          enabled           = true
          oidc_provider_arn = module.control_plane.irsa_oidc_provider_arn
        }
      }
      helm_release = {
        extra_values = <<-EOF
          vpcId: "${module.vpc_primary.vpc_id}"
          nodeSelector:
            node.cloudprovider.kubernetes.io/platform: aws
            topology.kubernetes.io/region: eu-west-1
          EOF
      }
    }
  }
}

module "ingress-nginx" {
  depends_on = [module.aws_load_balancer_controller]

  source = "github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws?ref=v1.11.0"

  cluster_name = var.cluster_name

  aws = {
    region = var.region
  }

  addons = {
    ingress-nginx = {
      enabled = true
      helm_release = {
        extra_values = <<-EOT
          controller:
            replicaCount: 3
            nodeSelector:
              node.cloudprovider.kubernetes.io/platform: aws
              topology.kubernetes.io/region: eu-west-1
            metrics:
              enabled: true
              serviceMonitor:
                enabled: false
            ingressClassResource:
              default: true
            updateStrategy:
              rollingUpdate:
                maxUnavailable: 1
              type: RollingUpdate
            topologySpreadConstraints:
            - maxSkew: 1
              topologyKey: topology.kubernetes.io/zone
              whenUnsatisfiable: DoNotSchedule
              labelSelector:
                matchLabels:
                  app.kubernetes.io/component: controller
                  app.kubernetes.io/instance: ingress-nginx
                  app.kubernetes.io/name: ingress-nginx
            service:
              annotations:
                service.kubernetes.io/topology-mode: "Auto"
                service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: preserve_client_ip.enabled=true
                service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "false"
                service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
                service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "instance"
          EOT
      }
    }
  }
}

module "cluster_autoscaler" {
  source = "github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws?ref=v1.11.0"

  cluster_name = var.cluster_name

  aws = {
    region = var.region
  }

  addons = {
    cluster-autoscaler = {
      enabled = true
      image = {
        tag = "v1.36.2"
      }
      iam = {
        eks_pod_identity = {
          enabled = false
        }
        irsa = {
          enabled           = true
          oidc_provider_arn = module.control_plane.irsa_oidc_provider_arn
        }
      }
      helm_release = {
        extra_values = <<-EXTRA_VALUES
          extraArgs:
            scale-down-utilization-threshold: 0.7
        EXTRA_VALUES
      }
    }
  }
}

module "external_dns" {
  source = "github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws?ref=v1.11.0"

  cluster_name = var.cluster_name

  aws = {
    region = var.region
  }

  addons = {
    external-dns = {
      enabled = true
      iam = {
        eks_pod_identity = {
          enabled = false
        }
        irsa = {
          enabled           = true
          oidc_provider_arn = module.control_plane.irsa_oidc_provider_arn
        }
      }
      route53 = {
        hosted_zone_arns = ["arn:aws:route53:::hostedzone/*"]
      }
    }
  }
}

module "flux_operator" {
  source = "github.com/shardlabsxyz/terraform-kubernetes-addons//modules/generic?ref=v1.11.0"

  cluster_name = var.cluster_name

  addons = {
    flux-operator = {
      enabled = true
      helm_release = {
        extra_values = <<-EXTRA_VALUES
        multitenancy:
          enabled: true
        EXTRA_VALUES
      }
    }
  }
}

module "flux_instance" {
  depends_on = [module.flux_operator]
  source     = "github.com/shardlabsxyz/terraform-kubernetes-addons//modules/generic?ref=v1.11.0"

  cluster_name = var.cluster_name

  addons = {
    flux-instance = {
      enabled = true
      helm_release = {
        extra_values = <<-EXTRA_VALUES
        instance:
          cluster:
            multitenant: true
          distribution:
            version: v2.10.0
        EXTRA_VALUES
      }
    }
  }
}

module "node_pools_primary" {
  source = "../../modules/node-pools/aws"

  cluster_name   = var.cluster_name
  vpc_id         = module.vpc_primary.vpc_id
  talos_image_id = module.talos_ami.ami_id

  kubernetes_version         = var.kubernetes_version
  talos_version              = var.talos_version
  kubernetes_api_url         = module.control_plane.kubernetes_api_url
  talos_client_configuration = module.control_plane.talos_client_configuration
  talos_machine_secrets      = module.control_plane.talos_machine_secrets

  node_pools = {
    default-ew1 = {
      instance_type    = "t3.medium"
      desired_capacity = 3
      min_size         = 3
      max_size         = 3
      subnet_ids       = module.vpc_primary.public_subnets

      labels = {
        "topology.kubernetes.io/region" = var.region
        "node-pool"                     = "primary"
      }

      enable_cluster_autoscaler = true
    }
  }

  tags = {
    Terraform   = "true"
    Environment = "demo"
  }
}

# -----------------------------------------------------------------------------
# Node Pools - Secondary Region (Hybrid) - EXAMPLE
# While it is technically possible to have another AWS node pool in a different region,
# in practice AWS specific tools such as AWS Load Balancer, EBS CSI Driver etc
# are designed to work with a single region. But for stateless workers it's working.
# Uncomment the following blocks to enable a secondary region node pool.
# -----------------------------------------------------------------------------

# module "vpc_secondary" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "~> 6.8"
#
#   providers = {
#     aws = aws.secondary
#   }
#
#   name = "${var.cluster_name}-secondary"
#   cidr = "10.2.0.0/16"
#
#   azs             = slice(data.aws_availability_zones.secondary.names, 0, 3)
#   private_subnets = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
#   public_subnets  = ["10.2.101.0/24", "10.2.102.0/24", "10.2.103.0/24"]
#
#   enable_nat_gateway     = true
#   single_nat_gateway     = true
#   one_nat_gateway_per_az = false
#
#   enable_dns_hostnames = true
#   enable_dns_support   = true
#
#   public_subnet_tags = {
#     "kubernetes.io/role/elb"                    = 1
#     "kubernetes.io/cluster/${var.cluster_name}" = "shared"
#   }
#
#   private_subnet_tags = {
#     "kubernetes.io/role/internal-elb"           = 1
#     "kubernetes.io/cluster/${var.cluster_name}" = "shared"
#   }
#
#   tags = {
#     Terraform   = "true"
#     Environment = "demo"
#     Cluster     = var.cluster_name
#   }
# }

# module "node_pools_secondary" {
#   source = "../../modules/node-pools/aws"
#
#   providers = {
#     aws = aws.secondary
#   }
#
#   cluster_name   = var.cluster_name
#   vpc_id         = module.vpc_secondary.vpc_id
#   talos_image_id = module.talos_ami_secondary.ami_id
#
#   kubernetes_version         = var.kubernetes_version
#   talos_version              = var.talos_version
#   kubernetes_api_url         = module.control_plane.kubernetes_api_url
#   talos_client_configuration = module.control_plane.talos_client_configuration
#   talos_machine_secrets      = module.control_plane.talos_machine_secrets
#
#   node_pools = {
#     default-ew3 = {
#       instance_type    = "t3.medium"
#       desired_capacity = 1
#       min_size         = 1
#       max_size         = 3
#       subnet_ids       = module.vpc_secondary.public_subnets
#
#       labels = {
#         "topology.kubernetes.io/region" = var.region_secondary
#         "node-pool"                     = "secondary"
#       }
#
#       enable_cluster_autoscaler = true
#     }
#   }
#
#   tags = {
#     Terraform   = "true"
#     Environment = "demo"
#   }
# }
