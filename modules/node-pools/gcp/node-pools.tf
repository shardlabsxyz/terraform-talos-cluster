locals {
  node_pools_network_tags = {
    for k, v in var.node_pools : k => concat(
      [for tag in v.network_tags : "${var.cluster_name}-${tag}"],
      [
        "${var.cluster_name}-node-pool",
      ]
    )
  }


  node_pool_instances_pre = {
    for x in flatten([
      for pool_name, pool in var.node_pools : [
        for idx in range(pool.target_size) : {
          pool   = pool_name
          idx    = idx
          region = pool.region
        }
      ]
    ]) : "${x.pool}-${x.idx}" => x
  }

  node_pools_instances_ips_by_pool = {
    for pool in keys(var.node_pools) : pool => [
      for k, n in local.node_pool_instances_pre : {
        nat_ip = try(
          data.google_compute_instance.node_pool_instance[k].network_interface[0].access_config[0].nat_ip,
          null
        )
        internal_ip = data.google_compute_instance.node_pool_instance[k].network_interface[0].network_ip
      }
      if n.pool == pool
    ]
  }

  node_pools_external_ips = flatten([
    for pool, ips in local.node_pools_instances_ips_by_pool : [
      for x in ips : x.nat_ip
      if x.nat_ip != null
    ]
  ])

  node_pools_private_ips = flatten([
    for pool, ips in local.node_pools_instances_ips_by_pool : [
      for x in ips : x.internal_ip
    ]
  ])
}

resource "google_service_account" "node_pool" {
  provider   = google-beta
  for_each   = var.node_pools
  account_id = "${var.cluster_name}-${try(each.value.name, each.key)}"
}

resource "google_compute_firewall" "node_pool_external" {
  for_each      = var.node_pools
  provider      = google-beta
  name          = "${var.cluster_name}-node-pool-${try(each.value.name, each.key)}-external"
  direction     = "INGRESS"
  network       = each.value.network
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["50000"]
  }

  allow {
    protocol = "udp"
    ports    = ["51820", "51871"]
  }

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  allow {
    protocol = "udp"
    ports    = ["30000-32767"]
  }

  allow {
    protocol = "icmp"
  }
}

module "node_pool_instance_template" {
  for_each = var.node_pools
  source   = "terraform-google-modules/vm/google//modules/instance_template"
  version  = "~> 13"

  nic_type       = "GVNIC"
  can_ip_forward = true

  access_config = [{
    network_tier = "PREMIUM"
  }]
  name_prefix  = try(each.value.name, each.key)
  machine_type = each.value.machine_type
  tags         = local.node_pools_network_tags[each.key]
  labels       = each.value.labels
  metadata = {
    user-data = data.talos_machine_configuration.node_pool[each.key].machine_configuration
  }
  service_account = {
    email = google_service_account.node_pool[each.key].email
  }

  /* network */
  subnetwork = each.value.subnetwork

  region     = coalesce(each.value.region, var.region)
  project_id = var.project_id

  /* image */
  source_image_project = coalesce(each.value.image.project, var.talos_image.project, var.project_id)
  source_image_family  = coalesce(each.value.image.family, var.talos_image.family)
  source_image         = coalesce(each.value.image.name, var.talos_image.name)

  /* disks */
  disk_size_gb = each.value.disk_size_gb
  disk_type    = each.value.disk_type
  disk_labels  = each.value.disk_labels
  auto_delete  = each.value.auto_delete
}

module "node_pool_mig" {
  for_each          = var.node_pools
  source            = "terraform-google-modules/vm/google//modules/mig"
  version           = "~> 15.0"
  region            = coalesce(each.value.region, var.region)
  project_id        = var.project_id
  target_size       = each.value.target_size
  hostname          = "${var.cluster_name}-pool-${try(each.value.name, each.key)}"
  instance_template = module.node_pool_instance_template[each.key].self_link
  mig_timeouts      = each.value.mig_timeouts

  update_policy = [each.value.update_policy]

  health_check = each.value.health_check
}

data "google_compute_region_instance_group" "node_pool" {
  depends_on = [
    module.node_pool_mig
  ]
  for_each = var.node_pools
  provider = google-beta
  region   = coalesce(each.value.region, var.region)
  name     = module.node_pool_mig[each.key].instance_group_manager.name
}

data "google_compute_instance" "node_pool_instance" {
  depends_on = [
    module.node_pool_mig
  ]
  provider = google-beta
  for_each = local.node_pool_instances_pre

  self_link = sort([
    for inst in data.google_compute_region_instance_group.node_pool[each.value.pool].instances :
    inst.instance
  ])[each.value.idx]
}

data "talos_machine_configuration" "node_pool" {
  for_each           = var.node_pools
  cluster_name       = var.cluster_name
  cluster_endpoint   = var.kubernetes_api_url
  machine_type       = "worker"
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  machine_secrets    = var.talos_machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        network = {
          kubespan = {
            enabled = true
          }
        }
        kubelet = {
          extraArgs = {
            cloud-provider             = "external"
            rotate-server-certificates = true
          }
        }
      }
      cluster = {
        discovery = {
          enabled = true
        }
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "node_pool" {
  depends_on = [
    module.node_pool_mig
  ]
  for_each                    = local.node_pool_instances_pre
  client_configuration        = var.talos_client_configuration
  machine_configuration_input = data.talos_machine_configuration.node_pool[each.value.pool].machine_configuration
  node                        = local.node_pools_instances_ips_by_pool[each.value.pool][each.value.idx].nat_ip
  config_patches              = try(var.node_pools[each.value.pool].config_patches, [])
}
