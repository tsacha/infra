resource "aws_dynamodb_table" "terraform" {
  name           = "terraform-state-locking"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "terraform-backend"
  }
}

resource "aws_s3_bucket" "terraform" {
  bucket        = "tsacha"
  acl           = "private"

  force_destroy = true

  lifecycle_rule {
    id      = "generic-cleanup"
    enabled = true

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      days = 8
    }

   abort_incomplete_multipart_upload_days = 8
  }

  lifecycle {
    prevent_destroy = false
  }

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = {
    Name        = "terraform-backend"
    Terraform   = true
  }
}
