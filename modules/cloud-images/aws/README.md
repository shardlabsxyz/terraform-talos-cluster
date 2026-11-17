# AWS Cloud Images Module

Lookup official Talos Linux AMI IDs for any AWS region. This module queries the [Talos image discovery API](https://www.talos.dev/latest/talos-guides/install/cloud-platforms/aws/) to retrieve the official AMI ID for your specified version and region.

## Why Use This Module?

- **Always up-to-date**: Fetches AMI IDs directly from Talos, no hardcoded values
- **Region-aware**: Automatically returns the correct AMI for your target region
- **Version-specific**: Pin to specific Talos versions for reproducible infrastructure
- **No manual lookup**: No need to search the AWS Marketplace or console

## Usage

### Basic Example

```hcl
module "talos_ami" {
  source = "github.com/shardlabsxyz/terraform-talos-cluster//modules/cloud-images/aws"

  talos_version = "v1.12.2"
  region        = "us-west-2"
}

# Use the AMI ID
resource "aws_instance" "example" {
  ami           = module.talos_ami.ami_id
  instance_type = "m6i.large"
}
```

### With Control Plane Module

```hcl
module "talos_ami" {
  source        = "github.com/shardlabsxyz/terraform-talos-cluster//modules/cloud-images/aws"
  talos_version = "v1.12.2"
  region        = var.region
}

module "control_plane" {
  source = "github.com/shardlabsxyz/terraform-talos-cluster//modules/control-plane/aws"

  cluster_name   = "my-cluster"
  vpc_id         = module.vpc.vpc_id
  talos_image_id = module.talos_ami.ami_id  # Use the discovered AMI

  # ... rest of configuration
}
```

### Multi-Region Deployment

```hcl
module "talos_ami_us_west_2" {
  source        = "github.com/shardlabsxyz/terraform-talos-cluster//modules/cloud-images/aws"
  talos_version = "v1.12.2"
  region        = "us-west-2"
}

module "talos_ami_eu_west_1" {
  source        = "github.com/shardlabsxyz/terraform-talos-cluster//modules/cloud-images/aws"
  talos_version = "v1.12.2"
  region        = "eu-west-1"
}

# Use each AMI in its respective region
module "control_plane_us" {
  providers = { aws = aws.us_west_2 }
  # ...
  talos_image_id = module.talos_ami_us_west_2.ami_id
}

module "node_pool_eu" {
  providers = { aws = aws.eu_west_1 }
  # ...
  talos_image_id = module.talos_ami_eu_west_1.ami_id
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `talos_version` | Talos OS version (e.g., "v1.12.2") | `string` | `"v1.11.6"` | no |
| `region` | AWS region to get AMI for | `string` | `"eu-west-1"` | no |
| `arch` | CPU architecture (amd64 or arm64) | `string` | `"amd64"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `ami_id` | The official Talos AMI ID for the specified version and region |

## Supported Versions

This module supports any Talos version that has official AWS AMIs published. Check the [Talos releases page](https://github.com/siderolabs/talos/releases) for available versions.

## Architecture Support

| Architecture | Value | Notes |
|--------------|-------|-------|
| AMD64/x86_64 | `amd64` | Default, most common |
| ARM64 | `arm64` | For Graviton instances |

## Alternative: Custom Images

If you need custom Talos images with extensions (e.g., NVIDIA drivers, ZFS), use the [factory module](../factory/README.md) instead to build and upload your own images.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.13.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | 3.6.3 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_http"></a> [http](#provider\_http) | 3.6.3 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [http_http.this](https://registry.terraform.io/providers/hashicorp/http/3.6.3/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_arch"></a> [arch](#input\_arch) | n/a | `string` | `"amd64"` | no |
| <a name="input_region"></a> [region](#input\_region) | n/a | `string` | `"eu-west-1"` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | n/a | `string` | `"v1.11.6"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ami_id"></a> [ami\_id](#output\_ami\_id) | n/a |
<!-- END_TF_DOCS -->
