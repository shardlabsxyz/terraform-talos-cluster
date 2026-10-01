locals {
  control_plane_network_tags = concat([for tag in var.control_plane.network_tags :
    "${var.cluster_name}-${tag}"
    ],
  )

  control_plane_external_ips = compact([
    for inst in data.google_compute_instance.control_plane :
    try(inst.network_interface[0].access_config[0].nat_ip, null)
  ])

  control_plane_private_ips = compact([
    for inst in data.google_compute_instance.control_plane :
    try(inst.network_interface[0].network_ip, null)
  ])
}

resource "google_service_account" "control_plane" {
  provider   = google-beta
  account_id = "${var.cluster_name}-cp"
}

resource "google_compute_address" "control_plane_api_ip" {
  provider = google-beta
  name     = var.cluster_name
}

resource "google_compute_forwarding_rule" "control_plane" {
  provider              = google-beta
  name                  = "${var.cluster_name}-control-plane"
  ip_address            = google_compute_address.control_plane_api_ip.id
  ip_protocol           = "TCP"
  target                = google_compute_region_target_tcp_proxy.control_plane.id
  port_range            = "6443"
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network               = var.control_plane.network
  network_tier          = "PREMIUM"
}

resource "google_compute_firewall" "control_plane_external" {
  provider      = google-beta
  name          = "${var.cluster_name}-control-plane-external"
  direction     = "INGRESS"
  network       = var.control_plane.network
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["6443", "50000", "50001"]
  }

  allow {
    protocol = "udp"
    ports    = ["51820", "51871"]
  }

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "control_plane_internal" {
  provider    = google-beta
  name        = "${var.cluster_name}-control-plane-internal"
  direction   = "INGRESS"
  priority    = 1001
  network     = var.control_plane.network
  source_tags = local.control_plane_network_tags
  target_tags = local.control_plane_network_tags

  allow {
    protocol = "all"
  }
}

resource "google_compute_region_backend_service" "control_plane" {
  provider              = google-beta
  name                  = "${var.cluster_name}-control-plane"
  protocol              = "TCP"
  port_name             = "k8s-api"
  health_checks         = [google_compute_region_health_check.control_plane.self_link]
  load_balancing_scheme = "EXTERNAL_MANAGED"


  log_config {
    enable = true
  }
  backend {
    group           = module.control_plane_mig.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_target_tcp_proxy" "control_plane" {
  provider        = google-beta
  name            = "${var.cluster_name}-control-plane"
  region          = var.region
  backend_service = google_compute_region_backend_service.control_plane.self_link
}

resource "google_compute_region_health_check" "control_plane" {
  provider = google-beta
  name     = "${var.cluster_name}-control-plane"

  timeout_sec         = 2
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 4

  log_config {
    enable = true
  }

  tcp_health_check {
    port               = "6443"
    port_specification = "USE_FIXED_PORT"
  }
}

module "control_plane_instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 13"

  nic_type       = "GVNIC"
  can_ip_forward = true

  access_config = [{
    network_tier = "PREMIUM"
  }]
  name_prefix  = var.cluster_name
  machine_type = var.control_plane.machine_type
  tags         = local.control_plane_network_tags
  labels       = var.control_plane.labels
  metadata = {
    user-data = data.talos_machine_configuration.control_plane.machine_configuration
  }
  service_account = {
    email = google_service_account.control_plane.email
  }

  /* network */
  subnetwork = var.control_plane.subnetwork

  region     = var.region
  project_id = var.project_id

  /* image */
  source_image_project = coalesce(var.control_plane.image.project, var.talos_image.project, var.project_id)
  source_image_family  = coalesce(var.control_plane.image.family, var.talos_image.family)
  source_image         = coalesce(var.control_plane.image.name, var.talos_image.name)

  /* disks */
  disk_size_gb = var.control_plane.disk_size_gb
  disk_type    = var.control_plane.disk_type
  disk_labels  = var.control_plane.disk_labels
  auto_delete  = var.control_plane.auto_delete
}

module "control_plane_mig" {
  source             = "terraform-google-modules/vm/google//modules/mig"
  version            = "~> 15.0"
  region             = var.region
  project_id         = var.project_id
  target_size        = var.control_plane.target_size
  hostname           = "${var.cluster_name}-control-plane"
  instance_template  = module.control_plane_instance_template.self_link
  wait_for_instances = var.control_plane.wait_for_instances
  mig_timeouts       = var.control_plane.mig_timeouts

  stateful_ips = [
    {
      interface_name = "nic0"
      delete_rule    = "ON_PERMANENT_INSTANCE_DELETION"
      is_external    = true
    },
    {
      interface_name = "nic0"
      delete_rule    = "ON_PERMANENT_INSTANCE_DELETION"
      is_external    = false
    }
  ]

  stateful_disks = [{
    device_name = "persistent-disk-0"
    delete_rule = "ON_PERMANENT_INSTANCE_DELETION"
  }]

  update_policy = [var.control_plane.update_policy]

  health_check = var.control_plane.health_check

  named_ports = [
    {
      name = "k8s-api"
      port = 6443
    },
    {
      name = "talos-api"
      port = 50000
    }
  ]
}

data "google_compute_region_instance_group" "control_plane" {
  depends_on = [
    module.control_plane_mig
  ]
  provider = google-beta
  region   = var.region
  name     = module.control_plane_mig.instance_group_manager.name
}

data "google_compute_instance" "control_plane" {
  count     = var.control_plane.target_size
  self_link = data.google_compute_region_instance_group.control_plane.instances[count.index].instance
}

resource "talos_machine_secrets" "talos" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "control_plane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${google_compute_address.control_plane_api_ip.address}:6443"
  machine_type       = "controlplane"
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  machine_secrets    = talos_machine_secrets.talos.machine_secrets

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
        features = {
          kubernetesTalosAPIAccess = {
            enabled = true
            allowedRoles = [
              "os:reader"
            ]
            allowedKubernetesNamespaces = [
              "kube-system"
            ]
          }
        }
      }
      cluster = {
        discovery = {
          enabled = true
        }
        network = {
          cni = {
            name = "none"
          }
        }
        externalCloudProvider = {
          enabled = true
          manifests = [
            "https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/main/docs/deploy/cloud-controller-manager.yml"
          ]
        }
        proxy = {
          disabled = true
        }
        extraManifests = [
          "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/tags/v1.4.1/config/crd/standard/gateway.networking.k8s.io_backendtlspolicies.yaml",
          "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/tags/v1.4.1/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml",
          "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/tags/v1.4.1/config/crd/standard/gateway.networking.k8s.io_gateways.yaml",
          "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/tags/v1.4.1/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml",
          "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/tags/v1.4.1/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml",
          "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/tags/v1.4.1/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml"
        ]
      }
    })
  ]
}

resource "talos_machine_bootstrap" "talos" {
  depends_on = [
    module.control_plane_mig
  ]
  node                 = local.control_plane_external_ips[0]
  client_configuration = talos_machine_secrets.talos.client_configuration
}


resource "talos_cluster_kubeconfig" "talos" {
  depends_on = [
    talos_machine_bootstrap.talos
  ]
  client_configuration = talos_machine_secrets.talos.client_configuration
  node                 = local.control_plane_external_ips[0]
}

resource "talos_machine_configuration_apply" "control_plane" {
  depends_on = [
    talos_machine_bootstrap.talos
  ]
  count                       = var.control_plane.target_size
  client_configuration        = talos_machine_secrets.talos.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane.machine_configuration
  node                        = local.control_plane_external_ips[count.index]
  config_patches              = try(var.control_plane.config_patches, [])
}
