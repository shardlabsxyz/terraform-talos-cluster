locals {
  issuer_hostpath = try(module.irsa_s3_bucket[0].s3_bucket_bucket_domain_name, "IRSA_DISABLED")
  openid_configuration = jsonencode({
    issuer                                = "https://${local.issuer_hostpath}"
    jwks_uri                              = "https://${local.issuer_hostpath}/keys.json"
    authorization_endpoint                = "urn:kubernetes:programmatic_authorization"
    response_types_supported              = ["id_token"]
    subject_types_supported               = ["public"]
    id_token_signing_alg_values_supported = ["RS256"]
    claims_supported                      = ["sub", "iss"]
  })

  jwks = jsonencode({
    keys = [
      {
        use = "sig"
        alg = "RS256"
        kty = "RSA"
        kid = try(data.external.pub_der[0].result.der, "IRSA_DISABLED")
        n   = try(data.external.modulus[0].result.modulus, "IRSA_DISABLED")
        e   = "AQAB"
    }]
  })
}

resource "tls_private_key" "irsa_oidc" {
  count     = var.irsa.enabled ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_iam_openid_connect_provider" "irsa_oidc" {
  count           = var.irsa.enabled ? 1 : 0
  url             = "https://${local.issuer_hostpath}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.irsa_oidc[0].certificates[0].sha1_fingerprint]
}

module "irsa_s3_bucket" {
  count = var.irsa.enabled ? 1 : 0

  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.18"

  bucket_prefix = "${var.cluster_name}-irsa-oidc"

  block_public_acls        = false
  block_public_policy      = false
  ignore_public_acls       = false
  restrict_public_buckets  = false
  control_object_ownership = true

  object_ownership = "BucketOwnerPreferred"
  acl              = "public-read"

  tags = var.tags
}

module "irsa_s3_bucket_object_openid-configuration" {
  count = var.irsa.enabled ? 1 : 0

  source  = "terraform-aws-modules/s3-bucket/aws//modules/object"
  version = "~> 5.18"

  bucket  = module.irsa_s3_bucket[0].s3_bucket_id
  key     = ".well-known/openid-configuration"
  content = local.openid_configuration
  acl     = "public-read"
}

module "irsa_s3_bucket_object_keys_json" {
  count = var.irsa.enabled ? 1 : 0

  source  = "terraform-aws-modules/s3-bucket/aws//modules/object"
  version = "~> 5.18"

  bucket  = module.irsa_s3_bucket[0].s3_bucket_id
  key     = "keys.json"
  content = local.jwks
  acl     = "public-read"
}

data "tls_certificate" "irsa_oidc" {
  count = var.irsa.enabled ? 1 : 0
  url   = "https://${local.issuer_hostpath}"
}

data "external" "pub_der" {
  count = var.irsa.enabled ? 1 : 0
  program = ["/bin/bash", "-c", <<EOF
set -euo pipefail
pem=$(jq -r .pem)
der=$(echo "$pem" | openssl pkey -pubin -inform PEM -outform DER | openssl dgst -sha256 -binary | base64 -w0 | tr -d '=' | tr '/+' '_-')
jq -n --arg der "$der" '{"der":$der}'
EOF
  ]
  query = { pem = tls_private_key.irsa_oidc[0].public_key_pem }
}

data "external" "modulus" {
  count = var.irsa.enabled ? 1 : 0
  program = ["/bin/bash", "-c", <<EOF
set -euo pipefail
pem=$(jq -r .pem)
modulus=$(echo "$pem" | openssl rsa -inform PEM -modulus -noout | cut -d'=' -f2 | xxd -r -p | base64 -w0 | tr -d '=' | tr '/+' '_-')
jq -n --arg modulus "$modulus" '{"modulus":$modulus}'
EOF
  ]
  query = { pem = tls_private_key.irsa_oidc[0].private_key_pem }
}
