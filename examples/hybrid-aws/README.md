# Hybrid AWS Example

This example deploys a Talos Kubernetes cluster on AWS with a cloud-hosted control plane, worker node pools, Cilium, and common AWS-integrated add-ons.

It is the AWS reference deployment for this repository. Review the multi-region notes in the root README before enabling the optional secondary-region node pool blocks.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.13.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0, != 2.12 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.12.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_aws.secondary"></a> [aws.secondary](#provider\_aws.secondary) | ~> 6.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.12.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_amazon-eks-pod-identity-webhook"></a> [amazon-eks-pod-identity-webhook](#module\_amazon-eks-pod-identity-webhook) | github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws | v1.5.0 |
| <a name="module_aws-cloud-controller-manager"></a> [aws-cloud-controller-manager](#module\_aws-cloud-controller-manager) | github.com/shardlabsxyz/terraform-kubernetes-addons//modules/talos | v1.5.0 |
| <a name="module_aws_ebs_csi_driver"></a> [aws\_ebs\_csi\_driver](#module\_aws\_ebs\_csi\_driver) | github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws | v1.5.0 |
| <a name="module_aws_load_balancer_controller"></a> [aws\_load\_balancer\_controller](#module\_aws\_load\_balancer\_controller) | github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws | v1.5.0 |
| <a name="module_cert_manager"></a> [cert\_manager](#module\_cert\_manager) | github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws | v1.5.0 |
| <a name="module_cilium"></a> [cilium](#module\_cilium) | github.com/shardlabsxyz/terraform-kubernetes-addons//modules/talos | v1.5.0 |
| <a name="module_cluster_autoscaler"></a> [cluster\_autoscaler](#module\_cluster\_autoscaler) | github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws | v1.5.0 |
| <a name="module_control_plane"></a> [control\_plane](#module\_control\_plane) | ../../modules/control-plane/aws | n/a |
| <a name="module_external_dns"></a> [external\_dns](#module\_external\_dns) | github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws | v1.5.0 |
| <a name="module_flux_instance"></a> [flux\_instance](#module\_flux\_instance) | github.com/shardlabsxyz/terraform-kubernetes-addons//modules/generic | v1.5.0 |
| <a name="module_flux_operator"></a> [flux\_operator](#module\_flux\_operator) | github.com/shardlabsxyz/terraform-kubernetes-addons//modules/generic | v1.5.0 |
| <a name="module_ingress-nginx"></a> [ingress-nginx](#module\_ingress-nginx) | github.com/shardlabsxyz/terraform-kubernetes-addons//modules/aws | v1.5.0 |
| <a name="module_node_pools_primary"></a> [node\_pools\_primary](#module\_node\_pools\_primary) | ../../modules/node-pools/aws | n/a |
| <a name="module_talos_ami"></a> [talos\_ami](#module\_talos\_ami) | ../../modules/cloud-images/aws | n/a |
| <a name="module_talos_ami_secondary"></a> [talos\_ami\_secondary](#module\_talos\_ami\_secondary) | ../../modules/cloud-images/aws | n/a |
| <a name="module_vpc_primary"></a> [vpc\_primary](#module\_vpc\_primary) | terraform-aws-modules/vpc/aws | ~> 6.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [talos_cluster_kubeconfig.talos](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/cluster_kubeconfig) | resource |
| [aws_availability_zones.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_availability_zones.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [talos_client_configuration.talos](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/data-sources/client_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the Talos cluster. | `string` | `"talos-demo-cluster"` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | The version of Kubernetes to deploy. | `string` | `"v1.35.0"` | no |
| <a name="input_region"></a> [region](#input\_region) | The AWS region where resources will be created. | `string` | `"eu-west-1"` | no |
| <a name="input_region_secondary"></a> [region\_secondary](#input\_region\_secondary) | The secondary AWS region for additional resources. | `string` | `"eu-west-3"` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | The version of Talos OS to use. | `string` | `"v1.12.2"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_control_plane_api_url"></a> [control\_plane\_api\_url](#output\_control\_plane\_api\_url) | Kubernetes API endpoint URL |
| <a name="output_control_plane_external_ips"></a> [control\_plane\_external\_ips](#output\_control\_plane\_external\_ips) | Control plane external IP addresses (EIPs) |
| <a name="output_control_plane_instances"></a> [control\_plane\_instances](#output\_control\_plane\_instances) | Control plane instance information |
| <a name="output_control_plane_private_ips"></a> [control\_plane\_private\_ips](#output\_control\_plane\_private\_ips) | Control plane private IP addresses |
| <a name="output_irsa_oidc_issuer_url"></a> [irsa\_oidc\_issuer\_url](#output\_irsa\_oidc\_issuer\_url) | IRSA OIDC issuer URL |
| <a name="output_irsa_oidc_provider_arn"></a> [irsa\_oidc\_provider\_arn](#output\_irsa\_oidc\_provider\_arn) | IRSA OIDC provider ARN for creating IAM roles for service accounts |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubernetes kubeconfig for kubectl access |
| <a name="output_load_balancer"></a> [load\_balancer](#output\_load\_balancer) | Network Load Balancer information |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | Talos client configuration for talosctl |
<!-- END_TF_DOCS -->
