# Hybrid GCP Example

This example deploys a Talos Kubernetes cluster on GCP with a regional control plane, node pools, Cilium, and supporting network resources.

Use it as a complete GCP reference deployment before adapting the module inputs for your own project, regions, and image strategy.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.13.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 8.12.0, < 9.0.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 8.12.0, < 9.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.3 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.12.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.12.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cilium"></a> [cilium](#module\_cilium) | github.com/shardlabsxyz/terraform-kubernetes-addons//modules/talos | v1.11.0 |
| <a name="module_control_plane"></a> [control\_plane](#module\_control\_plane) | ../../modules/control-plane/gcp | n/a |
| <a name="module_factory_gcp"></a> [factory\_gcp](#module\_factory\_gcp) | ../../modules/factory | n/a |
| <a name="module_network"></a> [network](#module\_network) | terraform-google-modules/network/google | ~> 18.3 |
| <a name="module_network_secondary"></a> [network\_secondary](#module\_network\_secondary) | terraform-google-modules/network/google | ~> 18.3 |
| <a name="module_node_pools"></a> [node\_pools](#module\_node\_pools) | ../../modules/node-pools/gcp | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [talos_cluster_kubeconfig.talos](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/cluster_kubeconfig) | resource |
| [talos_client_configuration.talos](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/data-sources/client_configuration) | data source |
| [talos_cluster_health.talos](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/data-sources/cluster_health) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the Talos cluster. | `string` | `"talos-demo-cluster"` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | The version of Kubernetes to deploy. | `string` | `"v1.36.6"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID where resources will be created. | `string` | `"sandbox-archi-0"` | no |
| <a name="input_region"></a> [region](#input\_region) | The GCP region where resources will be created. | `string` | `"europe-west1"` | no |
| <a name="input_region_secondary"></a> [region\_secondary](#input\_region\_secondary) | The secondary GCP region for additional resources. | `string` | `"europe-west4"` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | The version of Talos OS to use. | `string` | `"v1.14.6"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_control_plane"></a> [control\_plane](#output\_control\_plane) | n/a |
| <a name="output_control_plane_api_url"></a> [control\_plane\_api\_url](#output\_control\_plane\_api\_url) | n/a |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | n/a |
| <a name="output_network"></a> [network](#output\_network) | n/a |
| <a name="output_node_pools"></a> [node\_pools](#output\_node\_pools) | n/a |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | n/a |
<!-- END_TF_DOCS -->
