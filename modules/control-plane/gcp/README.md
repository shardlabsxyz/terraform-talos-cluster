# GCP Control Plane Module for Talos Kubernetes

This module deploys a regional Talos Kubernetes control plane on GCP with a managed instance group, external load balancer, Talos machine configuration, and Kubespan-ready networking.

Use it with the GCP node pool module when you want a cloud-hosted control plane and replaceable worker pools in the same or another GCP region.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.13.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | < 9.0.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | < 9.0.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.12.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | < 9.0.0 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | < 9.0.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.12.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_control_plane_instance_template"></a> [control\_plane\_instance\_template](#module\_control\_plane\_instance\_template) | terraform-google-modules/vm/google//modules/instance_template | ~> 13 |
| <a name="module_control_plane_mig"></a> [control\_plane\_mig](#module\_control\_plane\_mig) | terraform-google-modules/vm/google//modules/mig | ~> 15.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [google-beta_google_compute_address.control_plane_api_ip](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_address) | resource |
| [google-beta_google_compute_firewall.control_plane_external](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_firewall) | resource |
| [google-beta_google_compute_firewall.control_plane_internal](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_firewall) | resource |
| [google-beta_google_compute_forwarding_rule.control_plane](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_forwarding_rule) | resource |
| [google-beta_google_compute_region_backend_service.control_plane](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_region_backend_service) | resource |
| [google-beta_google_compute_region_health_check.control_plane](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_region_health_check) | resource |
| [google-beta_google_compute_region_target_tcp_proxy.control_plane](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_region_target_tcp_proxy) | resource |
| [google-beta_google_service_account.control_plane](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_service_account) | resource |
| [talos_cluster_kubeconfig.talos](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.talos](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.control_plane](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.talos](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/machine_secrets) | resource |
| [google-beta_google_compute_region_instance_group.control_plane](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/data-sources/google_compute_region_instance_group) | data source |
| [google_compute_instance.control_plane](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_instance) | data source |
| [talos_machine_configuration.control_plane](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the Talos cluster. | `string` | n/a | yes |
| <a name="input_control_plane"></a> [control\_plane](#input\_control\_plane) | Configuration for the control plane instances. | <pre>object({<br/>    machine_type       = string<br/>    target_size        = optional(number, 3)<br/>    network_tags       = optional(list(string), ["control-plane"])<br/>    labels             = optional(map(string))<br/>    subnetwork         = optional(string)<br/>    network            = optional(string)<br/>    disk_size_gb       = optional(number, 50)<br/>    disk_type          = optional(string, "pd-ssd")<br/>    disk_labels        = optional(map(string))<br/>    auto_delete        = optional(bool)<br/>    wait_for_instances = optional(bool, true)<br/>    mig_timeouts = optional(object({<br/>      create = optional(string)<br/>      update = optional(string)<br/>      delete = optional(string)<br/>      }),<br/>      {<br/>        create = "30m"<br/>        update = "30m"<br/>        delete = "30m"<br/>      }<br/>    )<br/>    image = optional(object({<br/>      family  = optional(string)<br/>      name    = optional(string)<br/>      project = optional(string)<br/>      }),<br/>      {<br/>        family  = null<br/>        name    = null<br/>        project = null<br/>      }<br/>    )<br/>    config_patches = optional(list(any), [])<br/>    update_policy = optional(object({<br/>      max_surge_fixed                = optional(number)<br/>      instance_redistribution_type   = optional(string)<br/>      max_surge_percent              = optional(number)<br/>      max_unavailable_fixed          = optional(number)<br/>      max_unavailable_percent        = optional(number)<br/>      min_ready_sec                  = optional(number)<br/>      replacement_method             = optional(string)<br/>      minimal_action                 = string<br/>      type                           = string<br/>      most_disruptive_allowed_action = optional(string)<br/>      }),<br/>      {<br/>        type                           = "PROACTIVE"<br/>        minimal_action                 = "REFRESH"<br/>        max_unavailable_fixed          = 3<br/>        min_ready_sec                  = 10<br/>        max_surge_fixed                = 0<br/>        replacement_method             = "RECREATE"<br/>        most_disruptive_allowed_action = "REFRESH"<br/>        instance_redistribution_type   = "NONE"<br/>    })<br/><br/>    health_check = optional(object({<br/>      type                = string<br/>      initial_delay_sec   = number<br/>      check_interval_sec  = number<br/>      healthy_threshold   = number<br/>      timeout_sec         = number<br/>      unhealthy_threshold = number<br/>      response            = string<br/>      proxy_header        = string<br/>      port                = number<br/>      request             = string<br/>      request_path        = string<br/>      host                = string<br/>      enable_logging      = bool<br/>      }),<br/>      {<br/>        type                = "tcp"<br/>        initial_delay_sec   = "10"<br/>        check_interval_sec  = "10"<br/>        healthy_threshold   = "1"<br/>        timeout_sec         = "10"<br/>        unhealthy_threshold = "5"<br/>        port                = "50000"<br/>        enable_logging      = true<br/>        proxy_header        = null<br/>        host                = null<br/>        response            = null<br/>        request_path        = null<br/>        request             = null<br/>      }<br/>    )<br/>  })</pre> | n/a | yes |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | The version of Kubernetes to deploy on the Talos control plane. | `string` | `"v1.35.0"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID where resources will be created. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region where resources will be created. | `string` | n/a | yes |
| <a name="input_talos_image"></a> [talos\_image](#input\_talos\_image) | The Talos OS image details. | <pre>object({<br/>    family  = optional(string, "talos")<br/>    name    = optional(string, "talos-v1-11-6-gcp-amd64")<br/>    project = optional(string)<br/>  })</pre> | <pre>{<br/>  "family": "talos",<br/>  "name": "talos-v1-11-6-gcp-amd64"<br/>}</pre> | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | The version of Talos OS to use for the control plane instances. | `string` | `"v1.12.1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_external_ips"></a> [external\_ips](#output\_external\_ips) | n/a |
| <a name="output_instance_templates"></a> [instance\_templates](#output\_instance\_templates) | n/a |
| <a name="output_instances"></a> [instances](#output\_instances) | n/a |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | n/a |
| <a name="output_kubernetes_api_ip"></a> [kubernetes\_api\_ip](#output\_kubernetes\_api\_ip) | n/a |
| <a name="output_kubernetes_api_url"></a> [kubernetes\_api\_url](#output\_kubernetes\_api\_url) | n/a |
| <a name="output_mig"></a> [mig](#output\_mig) | n/a |
| <a name="output_private_ips"></a> [private\_ips](#output\_private\_ips) | Private IP addresses of control plane instances |
| <a name="output_talos_api_ip"></a> [talos\_api\_ip](#output\_talos\_api\_ip) | n/a |
| <a name="output_talos_client_configuration"></a> [talos\_client\_configuration](#output\_talos\_client\_configuration) | n/a |
| <a name="output_talos_machine_secrets"></a> [talos\_machine\_secrets](#output\_talos\_machine\_secrets) | n/a |
<!-- END_TF_DOCS -->
