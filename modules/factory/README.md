# Talos Factory Module

Build and upload custom Talos Linux images to AWS or GCP. This module uses the [Talos Image Factory](https://factory.talos.dev/) to generate images with custom system extensions, then uploads them to your cloud provider.

## Why Use This Module?

Use this module when you need **custom Talos images** with:
- **System extensions**: NVIDIA drivers, ZFS, iSCSI, etc.
- **Custom schematics**: Specific kernel parameters, embedded configurations
- **Air-gapped environments**: Pre-built images stored in your own infrastructure
- **Reproducible builds**: Pin exact image versions across environments

For standard Talos images without extensions, use the simpler [cloud-images/aws](../cloud-images/aws/README.md) module instead.

## How It Works

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Talos Image    │     │   This Module   │     │  Cloud Provider │
│  Factory API    │────►│  (Downloads &   │────►│  (S3/GCS +      │
│  factory.talos  │     │   Uploads)      │     │   AMI/Image)    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

1. Module queries Talos Image Factory for download URL
2. Downloads the image locally (via curl)
3. Uploads to cloud storage (S3 or GCS)
4. Creates cloud-native image (AMI or Compute Image)

## Usage

### AWS: Build and Upload Custom AMI

```hcl
module "talos_factory" {
  source = "github.com/shardlabsxyz/terraform-talos-cluster//modules/factory"

  talos_version         = "v1.14.6"
  talos_platform        = "aws"
  talos_architecture    = "amd64"
  image_upload_platform = "aws"

  aws = {
    region        = "us-west-2"
    bucket_name   = "my-talos-images"
    create_bucket = true

    # Copy AMI to additional regions
    ami_additional_regions = ["us-east-1", "eu-west-1"]
  }
}

# Use the custom AMI
module "control_plane" {
  source         = "github.com/shardlabsxyz/terraform-talos-cluster//modules/control-plane/aws"
  talos_image_id = module.talos_factory.talos_image.aws.ami_id
  # ...
}
```

### GCP: Build and Upload Custom Image

```hcl
module "talos_factory" {
  source = "github.com/shardlabsxyz/terraform-talos-cluster//modules/factory"

  talos_version         = "v1.14.6"
  talos_platform        = "gcp"
  talos_architecture    = "amd64"
  image_upload_platform = "gcp"

  gcp = {
    project_id        = "my-project"
    bucket_name       = "my-talos-images"
    create_bucket     = true
    storage_locations = ["us", "eu"]
  }
}

# Use the custom image
module "control_plane" {
  source = "github.com/shardlabsxyz/terraform-talos-cluster//modules/control-plane/gcp"
  talos_image = {
    name = module.talos_factory.talos_image.gcp.id
  }
  # ...
}
```

### Use Existing Bucket

If you already have a bucket for storing images:

```hcl
module "talos_factory" {
  source = "github.com/shardlabsxyz/terraform-talos-cluster//modules/factory"

  talos_version         = "v1.14.6"
  talos_platform        = "aws"
  image_upload_platform = "aws"

  aws = {
    create_bucket = false      # Don't create bucket
    bucket_name   = "existing-bucket-name"
    region        = "us-west-2"
  }
}
```

## Custom Schematics

The module uses a default schematic ID that includes common extensions. To use a custom schematic:

1. Go to [Talos Image Factory](https://factory.talos.dev/)
2. Select your extensions and customizations
3. Copy the schematic ID
4. Modify the module source (requires fork) or use the factory URL directly

**Default schematic includes:**
- Talos Cloud Controller Manager support
- Standard platform drivers

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `talos_version` | Talos OS version | `string` | `"v1.14.6"` | no |
| `talos_platform` | Target platform (aws, gcp) | `string` | n/a | yes |
| `talos_architecture` | CPU architecture (amd64, arm64) | `string` | `"amd64"` | no |
| `image_upload_platform` | Cloud to upload image to (aws, gcp) | `string` | n/a | yes |
| `aws` | AWS configuration (see below) | `object` | `null` | no |
| `gcp` | GCP configuration (see below) | `object` | `null` | no |

### AWS Configuration

```hcl
aws = {
  create_bucket          = true              # Create S3 bucket for images
  bucket_name            = "talos-images"    # Bucket name
  region                 = "us-west-2"       # Primary region
  ami_additional_regions = ["us-east-1"]     # Copy AMI to these regions
  create_iam_role        = true              # Create vmimport IAM role
  import_iam_role        = "vmimport"        # IAM role name for import
  partition              = "aws"             # AWS partition (aws, aws-gov, aws-cn)
  tags                   = {}                # Tags for resources
}
```

### GCP Configuration

```hcl
gcp = {
  create_bucket     = true           # Create GCS bucket
  project_id        = "my-project"   # GCP project ID
  bucket_name       = "talos-images" # Bucket name
  storage_locations = ["us", "eu"]   # Multi-region storage
}
```

## Outputs

| Name | Description |
|------|-------------|
| `talos_image` | Image details per platform |
| `talos_image.aws.ami_id` | AWS AMI ID |
| `talos_image.gcp.id` | GCP image name |

## Requirements

### AWS

- **IAM Permissions**: The module creates a `vmimport` IAM role for EC2 image import. Ensure your credentials can create IAM roles.
- **S3 Permissions**: Create buckets, upload objects
- **EC2 Permissions**: Import snapshots, create AMIs, copy AMIs

### GCP

- **Storage Admin**: Create buckets, upload objects
- **Compute Admin**: Create images

### Local Tools

- **curl**: Download images from Talos Factory
- **xz**: Decompress AWS raw images (installed by default on most systems)

## Image Lifecycle

Images are stored in cloud storage and registered as cloud-native images. Consider:

1. **Versioning**: Use different bucket prefixes or names per Talos version
2. **Cleanup**: Old images remain in storage/registered until manually deleted
3. **Cross-region**: AWS AMIs can be copied to multiple regions via `ami_additional_regions`

## Comparison: Factory vs Cloud-Images Module

| Feature | Factory Module | Cloud-Images Module |
|---------|----------------|---------------------|
| **Use case** | Custom images with extensions | Official vanilla images |
| **Source** | Talos Image Factory | Talos Discovery API |
| **Extensions** | ✅ Supported | ❌ Not supported |
| **Storage required** | ✅ S3/GCS bucket | ❌ None |
| **Build time** | ~5-10 minutes | Instant (lookup only) |
| **Cost** | Storage + data transfer | Free |

**Recommendation**: Start with `cloud-images/aws` for simplicity. Switch to `factory` when you need extensions.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.13.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.73 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 8.12.0, < 9.0.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 8.12.0, < 9.0.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.12.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.73 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | >= 8.12.0, < 9.0.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.12.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_gcs_bucket"></a> [gcs\_bucket](#module\_gcs\_bucket) | terraform-google-modules/cloud-storage/google | ~> 12.4 |
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | terraform-aws-modules/s3-bucket/aws | ~> 5.18 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ami.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ami) | resource |
| [aws_ami_copy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ami_copy) | resource |
| [aws_ebs_snapshot_import.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_snapshot_import) | resource |
| [aws_iam_policy.vmimport](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.vmimport](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.vmimport](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_object.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [google-beta_google_compute_image.this](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_image) | resource |
| [google-beta_google_storage_bucket_object.this](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_storage_bucket_object) | resource |
| [terraform_data.this](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [talos_image_factory_urls.this](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/data-sources/image_factory_urls) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws"></a> [aws](#input\_aws) | n/a | <pre>object({<br/>    create_bucket          = optional(bool, true)<br/>    bucket_name            = optional(string, "talos-images")<br/>    tags                   = optional(map(string), {})<br/>    region                 = optional(string, "eu-west-1")<br/>    ami_additional_regions = optional(list(string), ["eu-west-1"])<br/>    import_iam_role        = optional(string, "vmimport")<br/>    create_iam_role        = optional(bool, true)<br/>    partition              = optional(string, "aws")<br/>  })</pre> | `null` | no |
| <a name="input_gcp"></a> [gcp](#input\_gcp) | n/a | <pre>object({<br/>    create_bucket     = optional(bool, true)<br/>    project_id        = string<br/>    bucket_name       = optional(string, "talos-images")<br/>    storage_locations = optional(list(string), ["eu"])<br/>  })</pre> | `null` | no |
| <a name="input_image_upload_platform"></a> [image\_upload\_platform](#input\_image\_upload\_platform) | n/a | `string` | n/a | yes |
| <a name="input_talos_architecture"></a> [talos\_architecture](#input\_talos\_architecture) | n/a | `string` | `"amd64"` | no |
| <a name="input_talos_platform"></a> [talos\_platform](#input\_talos\_platform) | n/a | `string` | n/a | yes |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | n/a | `string` | `"v1.14.6"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_talos_image"></a> [talos\_image](#output\_talos\_image) | n/a |
<!-- END_TF_DOCS -->
