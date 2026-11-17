module "gcs_bucket" {
  count      = var.image_upload_platform == "gcp" && var.gcp.create_bucket ? 1 : 0
  source     = "terraform-google-modules/cloud-storage/google"
  version    = "~> 12.4"
  project_id = var.gcp.project_id
  names      = [var.gcp.bucket_name]
}

resource "google_storage_bucket_object" "this" {
  depends_on = [
    terraform_data.this,
    module.gcs_bucket
  ]
  provider = google-beta
  count    = var.image_upload_platform == "gcp" ? 1 : 0
  name     = "talos-${var.talos_version}-${var.talos_platform}-${var.talos_architecture}.tar.gz"
  source   = "${path.module}/talos-${var.talos_version}-${var.talos_platform}-${var.talos_architecture}.tar.gz"
  bucket   = var.gcp.bucket_name
}

resource "google_compute_image" "this" {
  provider = google-beta
  count    = var.image_upload_platform == "gcp" ? 1 : 0

  name   = "talos-${replace(var.talos_version, ".", "-")}-${var.talos_platform}-${var.talos_architecture}"
  family = "talos"

  guest_os_features {
    type = "VIRTIO_SCSI_MULTIQUEUE"
  }

  guest_os_features {
    type = "GVNIC"
  }

  guest_os_features {
    type = "UEFI_COMPATIBLE"
  }
  storage_locations = var.gcp.storage_locations

  raw_disk {
    source = google_storage_bucket_object.this[0].self_link
  }
}
