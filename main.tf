terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.23.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

# VPC
resource "google_compute_network" "vpc_network" {
  for_each                        = var.vpcs
  name                            = each.value.name
  routing_mode                    = var.routing
  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  for_each      = var.subnet
  name          = each.value.name
  ip_cidr_range = each.value.ip_cidr_range
  network       = google_compute_network.vpc_network[each.value.vpc].self_link
  region        = var.region
}

# Route
resource "google_compute_route" "webapp_route" {
  name             = var.route_name
  network          = google_compute_network.vpc_network["vpc1"].self_link
  dest_range       = var.dest_range
  next_hop_gateway = "default-internet-gateway"
}

# Firewall to allow mysql
resource "google_compute_firewall" "webapp_firewall1" {
  name    = var.firewall1
  network = google_compute_network.vpc_network["vpc1"].self_link

  allow {
    protocol = var.tcp
    ports    = [var.port1, var.port2]
  }

  source_ranges = [var.source_range1,var.source_range2]
  target_tags   = ["webapp"]
}

# Firewall to disallow ssh
resource "google_compute_firewall" "webapp_firewall2" {
  name    = var.firewall2
  network = google_compute_network.vpc_network["vpc1"].self_link

  allow {
    protocol = var.tcp
    ports    = [var.port3]
  }

  source_ranges = [var.source_range]
  target_tags   = ["webapp"]
}

# Subnet
resource "google_compute_subnetwork" "private_subnet" {
  name                     = var.private_subnet
  ip_cidr_range            = var.private_cidr
  network                  = google_compute_network.vpc_network["vpc1"].self_link
  region                   = var.region
  private_ip_google_access = true
}

resource "google_compute_global_address" "private_ip_address" {
  name          = var.private_ip_address
  address_type  = var.private_address
  purpose       = var.private_purpose
  prefix_length = var.private_prefix
  network       = google_compute_network.vpc_network["vpc1"].self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network["vpc1"].self_link
  service                 = var.private_vpc_service
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# CloudSQL Instance - MySQL
resource "google_sql_database_instance" "webapp_sql_instance" {
  name                = var.webapp_sql_instance
  project             = var.project
  region              = var.region
  database_version    = var.database_version
  deletion_protection = false
  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_type         = var.disk_type
    disk_size         = var.disk_size
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc_network["vpc1"].self_link

    }
    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }
  }
  encryption_key_name = google_kms_crypto_key.webapp_cloudsql_key.id
  depends_on = [google_service_networking_connection.private_vpc_connection, google_kms_crypto_key.webapp_cloudsql_key]
}

# CloudSQL Database - MySQL
resource "google_sql_database" "webapp_database" {
  name     = var.webapp_database
  instance = google_sql_database_instance.webapp_sql_instance.name
}

# CloudSQL Database User with Randomly Generated Password
resource "random_password" "webapp_db_password" {
  length  = var.webapp_db_password_length
  special = false
}

resource "google_sql_user" "webapp_db_user" {
  name     = var.webapp_db_user
  instance = google_sql_database_instance.webapp_sql_instance.name
  password = random_password.webapp_db_password.result
}

resource "google_service_account" "vm_service_account" {
  account_id   = var.vm_service_account
  display_name = var.vm_service_account
}

resource "google_project_iam_binding" "service_account_pub" {
  project = var.project
  role    = var.pubsub_publisher
  members = [
    "serviceAccount:${google_service_account.vm_service_account.email}",
  ]
}

resource "google_compute_region_instance_template" "webapp_template" {
  name         = var.instance_name
  machine_type = var.machine_type
  region         = var.region
  tags         = ["webapp"]
  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["logging-write", "monitoring-write", "cloud-platform", "pubsub"]
  }
  network_interface {
    network    = google_compute_network.vpc_network["vpc1"].self_link
    subnetwork = google_compute_subnetwork.subnet["subnet1"].self_link
    access_config {
      network_tier = var.network_tier
    }
  }
  scheduling {
    automatic_restart   = true
    on_host_maintenance = var.maintenance
  }
  disk {
    auto_delete = true
    source_image = var.boot_disk_family
    disk_size_gb = var.boot_disk_size
    disk_type = var.boot_disk_type
    disk_encryption_key {
    kms_key_self_link = google_kms_crypto_key.webapp_kms_key.id
  }
  }
  lifecycle{
    create_before_destroy = true
  }
  metadata_startup_script = <<SCRIPT
      #!/bin/bash
      sudo touch /new/app/.env
      echo "DBUSER=${google_sql_user.webapp_db_user.name}" >> /new/app/.env
      echo "DBPASSWORD=${random_password.webapp_db_password.result}" >> /new/app/.env
      echo "DBNAME=healthcheck" >> /new/app/.env
      echo "DBURL=${google_sql_database_instance.webapp_sql_instance.first_ip_address}" >> /new/app/.env
      echo "ENV=PRODUCTION" >> /new/app/.env
      SCRIPT  

  depends_on = [google_project_iam_binding.vm_service_account_metrics_writer]

}

# Health Check
resource "google_compute_region_health_check" "webapp_health_check" {
  name               = var.health_check
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10  
  http_health_check {
    port   = var.port2
    request_path = "/healthz"
  }
}

resource "google_compute_region_instance_group_manager" "webapp_instance_group_manager" {
  name = var.group_manager
  base_instance_name = "webapp-instance"
  region = var.region
  version {
    instance_template = google_compute_region_instance_template.webapp_template.self_link
  }
  auto_healing_policies {
    health_check = google_compute_region_health_check.webapp_health_check.self_link
    initial_delay_sec = 300
  }
  named_port{
    name="http"
    port = 3000
  }
}

resource "google_compute_region_autoscaler" "webapp_autoscaler" {
  name               = "webapp-autoscaler"
  target             = google_compute_region_instance_group_manager.webapp_instance_group_manager.self_link
  autoscaling_policy {
    max_replicas       = 6
    min_replicas       = 3
    cooldown_period = 60
    cpu_utilization {
      target = 0.05
    }
  }
}

resource "google_project_iam_binding" "vm_service_account_roles" {
  project = var.project
  role    = var.role_logging
  members = ["serviceAccount:${google_service_account.vm_service_account.email}"]
}

resource "google_project_iam_binding" "vm_service_account_metrics_writer" {
  project = var.project
  role    = var.role_monitoring
  members = ["serviceAccount:${google_service_account.vm_service_account.email}"]
}

data "google_dns_managed_zone" "existing_zone" {
  name = var.webapp_zone
}


#Service Account  
resource "google_service_account" "cloudfunction_service_account" {
  account_id   = var.cloudfunction_service_account
  display_name = var.cloudfunction_service_account
  depends_on   = [google_pubsub_topic.verify_email_topic]
}

# IAM binding for Pub/Sub publisher role
resource "google_project_iam_binding" "pubsub-publisher" {
  project = var.project
  role    = var.pubsub_subscriber
  members = ["serviceAccount:${google_service_account.cloudfunction_service_account.email}"]
}

# IAM binding for Cloud Function invoker role
resource "google_project_iam_binding" "cloud-function-invoker" {
  project = var.project
  role    = var.run_invoker
  members = ["serviceAccount:${google_service_account.cloudfunction_service_account.email}"]
}

# IAM binding for Cloud Function invoker role
resource "google_project_iam_binding" "cloud-functions-invoker" {
  project = var.project
  role    = var.cloudfunction_invoker
  members = ["serviceAccount:${google_service_account.cloudfunction_service_account.email}"]
}

# IAM binding for Cloud Function invoker role
resource "google_project_iam_binding" "cloud-function-clousql-client" {
  project = var.project
  role    = var.cloudsql_client
  members = ["serviceAccount:${google_service_account.cloudfunction_service_account.email}"]
}

# IAM binding for Cloud Function vpaccess role
resource "google_project_iam_binding" "cloud-function-vpaccess" {
  project = var.project
  role    = var.vpcaccess
  members = ["serviceAccount:${google_service_account.cloudfunction_service_account.email}"]
}

# VPC Connector
resource "google_vpc_access_connector" "webapp_connector" {
  name          = var.webapp_connector
  network       = google_compute_network.vpc_network["vpc1"].self_link
  ip_cidr_range = var.connector_range
}

# Pub/Sub topic
resource "google_pubsub_topic" "verify_email_topic" {
  name                       = var.verify_email
  message_retention_duration = var.duration
  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

# Pub/Sub Subscription
resource "google_pubsub_subscription" "pubsub_subscription" {
  name                 = "pubsub-subscription"
  topic                = google_pubsub_topic.verify_email_topic.name
  ack_deadline_seconds = 20
}

# Cloud Functions
resource "google_cloudfunctions2_function" "verify_email_function" {
  name        = var.verify_email_function
  location    = var.region
  description = var.description

  build_config {
    runtime     = "nodejs18"
    entry_point = var.entry_point
    source {
      storage_source {
        bucket = var.bucket
        object = var.object
      }
    }
  }

  service_config {
    max_instance_count    = 1
    min_instance_count    = 1
    available_cpu         = "1"
    available_memory      = "256M"
    timeout_seconds       = 540
    service_account_email = google_service_account.cloudfunction_service_account.email
    vpc_connector         = google_vpc_access_connector.webapp_connector.self_link
    environment_variables = {
      DBUSER= google_sql_user.webapp_db_user.name
      DBPASSWORD= random_password.webapp_db_password.result
      DBNAME="healthcheck"
      DBURL= google_sql_database_instance.webapp_sql_instance.first_ip_address
      MAILGUN_KEY = var.mailgun_key
    }
  }

  event_trigger {
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.verify_email_topic.id
    retry_policy          = var.retry_policy
    trigger_region        = var.region
    service_account_email = google_service_account.cloudfunction_service_account.email
  }

  depends_on = [google_pubsub_topic.verify_email_topic,google_storage_bucket.webapp_storage_bucket_serverless]
}

# Module
module "gce-lb-http" {
  source  = "terraform-google-modules/lb-http/google"
  version = "~> 10.0"
  project       = var.project
  name          = "group-http-lb"
  target_tags   = ["webapp"]  

  ssl = true
  managed_ssl_certificate_domains = ["webappbysamiksha.me"]
  http_forward = false
  create_address = true
  network = google_compute_network.vpc_network["vpc1"].self_link
  backends = {
    default = {
      port_name    = "http"  
      protocol     = "HTTP"
      timeout_sec  = 10
      enable_cdn = false
      
      health_check = {
        request_path = "/healthz"
        port         = 3000  
      }

      log_config = {
        enable      = true
        sample_rate = 1.0
      }

      groups = [
        {
          group = google_compute_region_instance_group_manager.webapp_instance_group_manager.instance_group 
        },
      ]

      iap_config = {
        enable = false
      }

      firewall_networks =  [google_compute_network.vpc_network["vpc1"].self_link]
    }
  }
}

# Create A record in the existing managed zone
resource "google_dns_record_set" "example_a_record" {
  name         = var.a_record_name
  type         = var.a_record_type
  ttl          = var.ttl
  managed_zone = data.google_dns_managed_zone.existing_zone.name
  rrdatas = [module.gce-lb-http.external_ip]
}

# Create kms key
resource "google_kms_crypto_key" "webapp_kms_key" {
  name            = var.kms_key
  key_ring        = google_kms_key_ring.webapp_keyring.id
  rotation_period = var.rotation_period
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_kms_crypto_key_iam_binding" "webapp_kms_key_iam" {
  crypto_key_id = google_kms_crypto_key.webapp_kms_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members       = ["serviceAccount:${var.account}"]
}

resource "random_id" "webapp_keyring_suffix" {
  byte_length = 4
}

resource "google_kms_key_ring" "webapp_keyring" {
  name     = "webapp-kms-keyring-${random_id.webapp_keyring_suffix.hex}"
  location = var.region
}

resource "google_kms_crypto_key" "webapp_cloudsql_key" {
  name            = var.cloudsql_key
  key_ring        = google_kms_key_ring.webapp_keyring.id
  rotation_period = var.cloudsql_rotation_period
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_kms_crypto_key" "webapp_storage_key" {
  name            = var.storage_key
  key_ring        = google_kms_key_ring.webapp_keyring.id
  rotation_period = var.cloudsql_rotation_period
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_kms_crypto_key" "webapp_object_key" {
  name            = var.object_key
  key_ring        = google_kms_key_ring.webapp_keyring.id
  rotation_period = var.cloudsql_rotation_period
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_service_account" "webapp_cloudsql_service_account" {
  account_id   = "cloudsql-service-account"
  display_name = "cloudsql_service_account"
}

resource "google_service_account" "webapp_key_ring_service_account" {
  account_id   = "key-ring-service-account"
  display_name = "key-ring-service-account"
}

resource "google_kms_key_ring_iam_binding" "key_ring_iam" {
  key_ring_id = google_kms_key_ring.webapp_keyring.id
  role        = "roles/cloudkms.admin"
  members     = ["serviceAccount:${google_service_account.webapp_key_ring_service_account.email}"]
}

resource "google_project_service_identity" "webapp_gcp_sa_cloud_sql" {
  project  = var.project
  provider = google-beta
  service  = "sqladmin.googleapis.com"
}
 
resource "google_kms_crypto_key_iam_binding" "webapp_crypto_key_sql" {
  provider      = google-beta
  crypto_key_id = google_kms_crypto_key.webapp_cloudsql_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
 
  members = [
    "serviceAccount:${google_project_service_identity.webapp_gcp_sa_cloud_sql.email}",
  ]
}

data "google_storage_project_service_account" "storage_service_account" {
}

resource "google_kms_crypto_key_iam_binding" "storage_key_iam" {
  crypto_key_id = google_kms_crypto_key.webapp_storage_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members       = ["serviceAccount:${data.google_storage_project_service_account.storage_service_account.email_address}"]
}

resource "google_kms_crypto_key_iam_binding" "object_key_iam" {
  crypto_key_id = google_kms_crypto_key.webapp_object_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members       = ["serviceAccount:${data.google_storage_project_service_account.storage_service_account.email_address}"]
}

resource "google_storage_bucket" "webapp_storage_bucket_serverless" {
  name                        = var.bucket
  location                    = var.region
  storage_class               = "STANDARD"
  force_destroy               = true
  uniform_bucket_level_access = true
  encryption {
    default_kms_key_name = google_kms_crypto_key.webapp_storage_key.id
  }
  depends_on = [google_kms_crypto_key_iam_binding.storage_key_iam]
}
 
resource "google_storage_bucket_object" "webapp_storage_bucket_object" {
  name         = var.serverless
  bucket       = google_storage_bucket.webapp_storage_bucket_serverless.name
  source       = "./serverless.zip"
  kms_key_name = google_kms_crypto_key.webapp_object_key.id
  depends_on = [ google_storage_bucket.webapp_storage_bucket_serverless ]
}
