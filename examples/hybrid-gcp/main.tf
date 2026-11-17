provider "google" {
  region  = var.region
  project = var.project_id
}

provider "google-beta" {
  region  = var.region
  project = var.project_id
}

provider "helm" {
  kubernetes = {
    host                   = talos_cluster_kubeconfig.talos.kubernetes_client_configuration.host
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.talos.kubernetes_client_configuration.ca_certificate)
    client_certificate     = base64decode(talos_cluster_kubeconfig.talos.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.talos.kubernetes_client_configuration.client_key)
  }
}

module "factory_gcp" {
  source                = "../../modules/factory"
  talos_platform        = "gcp"
  talos_version         = var.talos_version
  image_upload_platform = "gcp"
  gcp = {
    bucket_name   = "archi-gcp-images"
    project_id    = var.project_id
    create_bucket = false
  }
}

module "network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 18.3"

  project_id                   = var.project_id
  network_name                 = var.cluster_name
  bgp_best_path_selection_mode = "STANDARD"
  mtu                          = 8896

  subnets = [
    {
      subnet_name           = var.cluster_name
      subnet_ip             = "10.42.0.0/16"
      subnet_region         = var.region
      description           = "Subnet dedicated to the nodes of the ${var.cluster_name} talos cluster"
      subnet_flow_logs      = true
      subnet_private_access = true
    },
    {
      subnet_name      = "${var.cluster_name}-lb-proxy"
      subnet_ip        = "10.43.0.0/24"
      subnet_region    = var.region
      description      = "Subnet dedicated to the load balancer proxy of the ${var.cluster_name} talos cluster"
      subnet_flow_logs = false
      role             = "ACTIVE"
      purpose          = "REGIONAL_MANAGED_PROXY"
    },
  ]

  firewall_rules = [
    {
      name        = "${var.cluster_name}-allow-all-egress"
      direction   = "EGRESS"
      description = "Allow all egress traffic"
      ranges      = ["0.0.0.0/0"]
      allow = [{
        protocol = "all"
      }]
  }]
}

module "network_secondary" {
  source  = "terraform-google-modules/network/google"
  version = "~> 18.3"

  project_id                   = var.project_id
  network_name                 = "${var.cluster_name}-secondary"
  bgp_best_path_selection_mode = "STANDARD"
  mtu                          = 8896

  subnets = [
    {
      subnet_name           = "${var.cluster_name}-secondary"
      subnet_ip             = "10.45.0.0/16"
      subnet_region         = var.region_secondary
      description           = "Subnet dedicated to the nodes of the ${var.cluster_name} talos cluster"
      subnet_flow_logs      = true
      subnet_private_access = true
    },
  ]

  firewall_rules = [
    {
      name        = "${var.cluster_name}-secondary-allow-all-egress"
      direction   = "EGRESS"
      description = "Allow all egress traffic"
      ranges      = ["0.0.0.0/0"]
      allow = [{
        protocol = "all"
      }]
  }]

}

module "control_plane" {
  source = "../../modules/control-plane/gcp"

  project_id = var.project_id
  region     = var.region

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version
  talos_image = {
    name = module.factory_gcp.talos_image.gcp.id
  }

  control_plane = {
    machine_type = "c3-standard-4"
    subnetwork   = module.network.subnets_ids[0]
    network      = module.network.network_id
  }
}

module "node_pools" {
  source = "../../modules/node-pools/gcp"

  project_id = var.project_id
  region     = var.region

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version
  talos_image = {
    name = module.factory_gcp.talos_image.gcp.id
  }

  kubernetes_api_url         = module.control_plane.kubernetes_api_url
  talos_client_configuration = module.control_plane.talos_client_configuration
  talos_machine_secrets      = module.control_plane.talos_machine_secrets

  node_pools = {
    default-ew1 = {
      target_size  = 1
      machine_type = "c3-standard-4"
      subnetwork   = module.network.subnets_ids[0]
      network      = module.network.network_id
      region       = var.region
    }
    default-ew4 = {
      target_size  = 1
      machine_type = "c3-standard-4"
      subnetwork   = module.network_secondary.subnets_ids[0]
      network      = module.network_secondary.network_id
      region       = var.region_secondary
    }
  }
}

data "talos_client_configuration" "talos" {
  cluster_name         = var.cluster_name
  client_configuration = module.control_plane.talos_client_configuration
  endpoints            = module.control_plane.external_ips
  nodes = concat(
    module.control_plane.private_ips,
    module.node_pools.private_ips
  )
}

data "talos_cluster_health" "talos" {
  depends_on           = [module.cilium]
  client_configuration = module.control_plane.talos_client_configuration
  control_plane_nodes  = module.control_plane.private_ips
  worker_nodes         = module.node_pools.private_ips
  endpoints            = module.control_plane.external_ips

  timeouts = {
    read = "1m"
  }
}

resource "talos_cluster_kubeconfig" "talos" {
  client_configuration = module.control_plane.talos_client_configuration
  node                 = module.control_plane.external_ips[0]
}

moved {
  from = module.cilium.module.helm_releases["cilium"].helm_release.this[0]
  to   = module.cilium.helm_release.this["cilium"]
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
