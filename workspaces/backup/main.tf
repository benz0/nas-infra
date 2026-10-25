# Offsite, versioned backup target for the data the agent can change and that
# isn't already covered elsewhere: docs, vault-personal, vault-work, git and
# Vault's raft snapshots. Hyper Backup writes here (task configured in DSM).
#
# The Hyper Backup key is created by hand in the B2 web UI, limited to this
# bucket, so its secret never enters Terraform state.

resource "b2_bucket" "offsite" {
  bucket_name = var.bucket_name
  bucket_type = "allPrivate"

  # B2 keeps every old version of a file by default. Hyper Backup manages its
  # own versions and constantly replaces its index files, so keep only the
  # latest copy: hidden (replaced or deleted) versions are removed after 1 day.
  lifecycle_rules {
    file_name_prefix             = ""
    days_from_hiding_to_deleting = 1
  }

  # Server-side encryption at rest. Hyper Backup also encrypts client-side.
  default_server_side_encryption {
    mode      = "SSE-B2"
    algorithm = "AES256"
  }
}

output "bucket_name" {
  value = b2_bucket.offsite.bucket_name
}

output "bucket_id" {
  value = b2_bucket.offsite.bucket_id
}
