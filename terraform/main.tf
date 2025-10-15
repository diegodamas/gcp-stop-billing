terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
    archive = {
      source  = "hashicorp/archive"
    }
  }
}

provider "google" {
  project = var.gcp_project_management_id
  region  = var.gcp_region
}

data "google_project" "management" {
  project_id = var.gcp_project_management_id
}

resource "google_project_service" "apis" {
  project = data.google_project.management.project_id
  for_each = toset([
    "pubsub.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "cloudbilling.googleapis.com",
    "artifactregistry.googleapis.com"
  ])
  service                    = each.key
  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_service_account" "billing_shutdown_invoker" {
  project      = data.google_project.management.project_id
  account_id   = "billing-shutdown-invoker"
  display_name = "Service Account to stop billing"
  depends_on   = [google_project_service.apis]
}

resource "google_billing_account_iam_member" "sa_billing_admin" {
  billing_account_id = var.billing_account_id
  role                 = "roles/billing.admin"
  member               = "serviceAccount:${google_service_account.billing_shutdown_invoker.email}"
}

data "archive_file" "source_zip" {
  type        = "zip"
  source_dir  = "../${path.module}/billing_kill_switch"
  output_path = "/tmp/billing-function-source.zip"
}

resource "google_storage_bucket" "function_source_bucket" {
  project      = data.google_project.management.project_id
  name         = "${data.google_project.management.project_id}-billing-function-src"
  location     = var.gcp_region
  uniform_bucket_level_access = true
  depends_on   = [google_project_service.apis]
}

resource "google_storage_bucket_object" "source_object" {
  name   = "source.zip"
  bucket = google_storage_bucket.function_source_bucket.name
  source = data.archive_file.source_zip.output_path
}

resource "google_pubsub_topic" "billing_alerts" {
  project = data.google_project.management.project_id
  name    = "billing-alerts"
  depends_on = [google_project_service.apis]
}

resource "google_cloudfunctions2_function" "stop_billing_function" {
  project  = data.google_project.management.project_id
  name     = "stop-billing-function"
  location = var.gcp_region

  build_config {
    runtime     = "python312"
    entry_point = "stop_billing"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source_bucket.name
        object = google_storage_bucket_object.source_object.name
      }
    }
  }

  service_config {
    max_instance_count    = 2
    min_instance_count    = 0
    available_memory      = "256Mi"
    timeout_seconds       = 60
    service_account_email = google_service_account.billing_shutdown_invoker.email
  }

  event_trigger {
    trigger_region = var.gcp_region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.billing_alerts.id
    retry_policy   = "RETRY_POLICY_DO_NOT_RETRY"
  }

  depends_on = [
    google_project_service.apis,
    google_billing_account_iam_member.sa_billing_admin
  ]
}

resource "google_billing_budget" "studies_project_budget" {
  billing_account = var.billing_account_id

  amount {
    specified_amount {
      currency_code = "BRL"
      units         = var.budget_amount
    }
  }

  threshold_rules {
    threshold_percent =  0.5
  }
  
  all_updates_rule {
    pubsub_topic     = google_pubsub_topic.billing_alerts.id
    schema_version   = "1.0"
  }
}