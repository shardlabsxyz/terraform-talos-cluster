# GCP Node Pools Module for Talos Kubernetes

This module creates replaceable Talos worker node pools on GCP using regional managed instance groups.

Use it with the GCP control plane module outputs for Talos machine secrets, client configuration, and Kubernetes API endpoint wiring.

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
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | < 9.0.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.12.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_node_pool_instance_template"></a> [node\_pool\_instance\_template](#module\_node\_pool\_instance\_template) | terraform-google-modules/vm/google//modules/instance_template | ~> 13 |
| <a name="module_node_pool_mig"></a> [node\_pool\_mig](#module\_node\_pool\_mig) | terraform-google-modules/vm/google//modules/mig | ~> 15.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [google-beta_google_compute_firewall.node_pool_external](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_firewall) | resource |
| [google-beta_google_service_account.node_pool](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_service_account) | resource |
| [talos_machine_configuration_apply.node_pool](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/machine_configuration_apply) | resource |
| [google-beta_google_compute_instance.node_pool_instance](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/data-sources/google_compute_instance) | data source |
| [google-beta_google_compute_region_instance_group.node_pool](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/data-sources/google_compute_region_instance_group) | data source |
| [talos_machine_configuration.node_pool](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the Talos cluster. | `string` | n/a | yes |
| <a name="input_kubernetes_api_url"></a> [kubernetes\_api\_url](#input\_kubernetes\_api\_url) | The URL of the Kubernetes API server. | `string` | n/a | yes |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | The version of Kubernetes to deploy on the Talos control plane. | `string` | `"v1.35.0"` | no |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | Configuration for the worker node pools. | <pre>map(object({<br/>    machine_type = string<br/>    target_size  = optional(number, 3)<br/>    network_tags = optional(list(string), ["worker-node"])<br/>    labels       = optional(map(string))<br/>    subnetwork   = optional(string)<br/>    network      = optional(string)<br/>    region       = optional(string)<br/>    disk_size_gb = optional(number, 50)<br/>    disk_type    = optional(string, "pd-ssd")<br/>    disk_labels  = optional(map(string))<br/>    auto_delete  = optional(bool)<br/>    mig_timeouts = optional(object({<br/>      create = optional(string)<br/>      update = optional(string)<br/>      delete = optional(string)<br/>      }),<br/>      {<br/>        create = "30m"<br/>        update = "30m"<br/>        delete = "30m"<br/>      }<br/>    )<br/>    image = optional(object({<br/>      family  = optional(string)<br/>      name    = optional(string)<br/>      project = optional(string)<br/>      }),<br/>      {<br/>        family  = null<br/>        name    = null<br/>        project = null<br/>      }<br/>    )<br/>    config_patches = optional(list(any), [])<br/>    update_policy = optional(object({<br/>      max_surge_fixed                = optional(number)<br/>      instance_redistribution_type   = optional(string)<br/>      max_surge_percent              = optional(number)<br/>      max_unavailable_fixed          = optional(number)<br/>      max_unavailable_percent        = optional(number)<br/>      min_ready_sec                  = optional(number)<br/>      replacement_method             = optional(string)<br/>      minimal_action                 = string<br/>      type                           = string<br/>      most_disruptive_allowed_action = optional(string)<br/>      }),<br/>      {<br/>        type                           = "PROACTIVE"<br/>        minimal_action                 = "REPLACE"<br/>        max_unavailable_fixed          = 3<br/>        min_ready_sec                  = 60<br/>        max_surge_fixed                = 0<br/>        replacement_method             = "RECREATE"<br/>        most_disruptive_allowed_action = "REPLACE"<br/>        instance_redistribution_type   = "NONE"<br/>    })<br/><br/>    health_check = optional(object({<br/>      type                = string<br/>      initial_delay_sec   = number<br/>      check_interval_sec  = number<br/>      healthy_threshold   = number<br/>      timeout_sec         = number<br/>      unhealthy_threshold = number<br/>      response            = string<br/>      proxy_header        = string<br/>      port                = number<br/>      request             = string<br/>      request_path        = string<br/>      host                = string<br/>      enable_logging      = bool<br/>      }),<br/>      {<br/>        type                = "tcp"<br/>        initial_delay_sec   = "120"<br/>        check_interval_sec  = "10"<br/>        healthy_threshold   = "2"<br/>        timeout_sec         = "10"<br/>        unhealthy_threshold = "5"<br/>        port                = "50000"<br/>        enable_logging      = true<br/>        proxy_header        = null<br/>        host                = null<br/>        response            = null<br/>        request_path        = null<br/>        request             = null<br/>      }<br/>    )<br/>  }))</pre> | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID where resources will be created. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region where resources will be created. | `string` | n/a | yes |
| <a name="input_talos_client_configuration"></a> [talos\_client\_configuration](#input\_talos\_client\_configuration) | Talos client configuration from the control plane. | `any` | n/a | yes |
| <a name="input_talos_image"></a> [talos\_image](#input\_talos\_image) | The Talos OS image details. | <pre>object({<br/>    family  = optional(string, "talos")<br/>    name    = optional(string, "talos-v1-11-6-gcp-amd64")<br/>    project = optional(string)<br/>  })</pre> | <pre>{<br/>  "family": "talos",<br/>  "name": "talos-v1-11-6-gcp-amd64"<br/>}</pre> | no |
| <a name="input_talos_machine_secrets"></a> [talos\_machine\_secrets](#input\_talos\_machine\_secrets) | Talos machine secrets from the control plane. | `any` | n/a | yes |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | The version of Talos OS to use for the control plane instances. | `string` | `"v1.12.1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_external_ips"></a> [external\_ips](#output\_external\_ips) | n/a |
| <a name="output_instance_templates"></a> [instance\_templates](#output\_instance\_templates) | n/a |
| <a name="output_instances"></a> [instances](#output\_instances) | n/a |
| <a name="output_instances_ips_by_pools"></a> [instances\_ips\_by\_pools](#output\_instances\_ips\_by\_pools) | n/a |
| <a name="output_migs"></a> [migs](#output\_migs) | n/a |
| <a name="output_private_ips"></a> [private\_ips](#output\_private\_ips) | n/a |
<!-- END_TF_DOCS -->
