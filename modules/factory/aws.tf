module "s3_bucket" {
  count   = var.image_upload_platform == "aws" && var.aws.create_bucket ? 1 : 0
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.18"
  region  = var.aws.region
  bucket  = var.aws.bucket_name
}

resource "aws_s3_object" "this" {
  depends_on = [
    terraform_data.this,
    module.s3_bucket
  ]
  count  = var.image_upload_platform == "aws" ? 1 : 0
  bucket = var.aws.bucket_name
  key    = local.file_name[var.image_upload_platform]
  source = "${path.module}/${local.file_name[var.image_upload_platform]}"
}

resource "aws_ebs_snapshot_import" "this" {
  depends_on = [
    aws_iam_role_policy_attachment.vmimport,
    aws_s3_object.this
  ]
  count  = var.image_upload_platform == "aws" ? 1 : 0
  region = var.aws.region

  role_name = var.aws.import_iam_role

  disk_container {
    format = "RAW"
    user_bucket {
      s3_bucket = var.aws.bucket_name
      s3_key    = local.file_name[var.image_upload_platform]
    }
  }

  tags = var.aws.tags
}

resource "aws_ami" "this" {
  count               = var.image_upload_platform == "aws" ? 1 : 0
  region              = var.aws.region
  name                = "talos-${replace(var.talos_version, ".", "-")}-${var.talos_platform}-${var.talos_architecture}"
  virtualization_type = "hvm"
  root_device_name    = "/dev/xvda"
  ena_support         = true
  imds_support        = "v2.0"
  ebs_block_device {
    device_name = "/dev/xvda"
    snapshot_id = aws_ebs_snapshot_import.this[0].id
  }
}

resource "aws_ami_copy" "this" {
  count             = var.image_upload_platform == "aws" ? 1 : 0
  name              = "talos-${replace(var.talos_version, ".", "-")}-${var.talos_platform}-${var.talos_architecture}"
  source_ami_id     = aws_ami.this[0].id
  source_ami_region = var.aws.region

  tags = var.aws.tags
}

resource "aws_iam_role" "vmimport" {
  count              = var.image_upload_platform == "aws" && var.aws.create_iam_role ? 1 : 0
  name               = var.aws.import_iam_role
  tags               = var.aws.tags
  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
          {
            "Effect": "Allow",
            "Principal": { "Service": "vmie.amazonaws.com" },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals":{
                  "sts:Externalid": "vmimport"
                }
            }
          }
      ]
    }
    EOF
}

resource "aws_iam_policy" "vmimport" {
  count       = var.image_upload_platform == "aws" && var.aws.create_iam_role ? 1 : 0
  name        = var.aws.import_iam_role
  description = "Policy for ${var.aws.import_iam_role} role"

  policy = <<-EOF
    {
      "Version":"2012-10-17",
      "Statement":[
          {
            "Effect":"Allow",
            "Action":[
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource":[
                "arn:${var.aws.partition}:s3:::${var.aws.bucket_name}",
                "arn:${var.aws.partition}:s3:::${var.aws.bucket_name}/*"
            ]
          },
          {
            "Effect":"Allow",
            "Action":[
                "ec2:ModifySnapshotAttribute",
                "ec2:CopySnapshot",
                "ec2:RegisterImage",
                "ec2:Describe*"
            ],
            "Resource":"*"
          }
      ]
    }
    EOF
}

resource "aws_iam_role_policy_attachment" "vmimport" {
  count      = var.image_upload_platform == "aws" && var.aws.create_iam_role ? 1 : 0
  role       = aws_iam_role.vmimport[0].name
  policy_arn = aws_iam_policy.vmimport[0].arn
}
