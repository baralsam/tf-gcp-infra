variable "project" { 
    default = "clod-assignment"
} 

variable "region" {
  default = "us-east1"
}

variable "zone" {
  default = "us-east1-c"
}

variable "routing" {
  default = "REGIONAL"
}

variable "vpcs" {
  default = {
    vpc1 = {
      name  = "vpc1"
    },
#    vpc2 = {
#    name   = "vpc2"
#    },
#    vpc3 = {
#      name  = "vpc3"
#    }
  }
}

variable "subnet" {
  default = {
    subnet1 = {
      vpc = "vpc1"
      name  = "webapp"
      ip_cidr_range = "10.1.0.0/24"
    },
    subnet2 = {
      vpc = "vpc1"
      name  = "db"
      ip_cidr_range = "10.2.0.0/24"
    },
#    subnet3 = {
#      vpc = "vpc2"
#      name  = "webapp-2"
#      ip_cidr_range = "10.3.0.0/24"
#    },
#    subnet4 = {
#      vpc = "vpc2"
#      name  = "db-2"
#      ip_cidr_range = "10.4.0.0/24"
#    },
#    subnet5 = {
#      vpc = "vpc3"
#      name  = "webapp-3"
#      ip_cidr_range = "10.5.0.0/24"
#    },
#    subnet6 = {
#      vpc = "vpc3"
#      name  = "db-3"
#      ip_cidr_range = "10.6.0.0/24"
#    }
  }
}

variable "dest_range" {
  default = "0.0.0.0/0"
}

variable "port1"{
  default = 80
}

variable "port2"{
  default = 3000
}

variable "source_range" {
 default = "0.0.0.0/0"
}

variable "port3"{
  default = 22
}

variable "machine_type"{
  default = "n1-standard-1"
}

variable "network_tier"{
  default = "PREMIUM"
}

variable "boot_disk_size"{
  default = 20
}

variable "boot_disk_type"{
  default = "pd-balanced"
}

variable "boot_disk_family"{
  default = "centos-family"
}

variable "route_name"{
  default = "webapp-route"
}

variable "firewall1"{
  default = "webapp-firewall1"
}

variable "tcp"{
  default = "tcp"
}

variable "firewall2"{
  default = "webapp-firewall2"
}

variable "instance_name"{
  default = "webapp-instance"
}

variable "private_subnet"{
  default = "private-subnet"
}

variable "private_cidr"{
  default = "10.5.0.0/24"
}

variable "private_address"{
  default = "INTERNAL"
}

variable "private_purpose"{
  default = "VPC_PEERING"
}

variable "private_prefix"{
  default = 16
}

variable "private_vpc_service"{
  default = "servicenetworking.googleapis.com"
}

variable "private_ip_address"{
  default = "private-ip-address"
}

variable "webapp_sql_instance"{
  default = "webapp-sql-instance"
}

variable "database_version"{
  default = "MYSQL_8_0"
}

variable "tier"{
  default = "db-n1-standard-1"
}

variable "availability_type"{
  default = "REGIONAL"
}

variable "disk_type"{
  default = "pd-ssd"
}

variable "disk_size"{
  default = "100"
}

variable "webapp_database"{
  default = "webapp-database"
}

variable "webapp_db_password_length"{
  default = 16
}

variable "webapp_db_user"{
  default = "webapp-db-user"
}

variable "vm_service_account"{
  default = "vm-service-account"
}

variable "role_logging"{
  default = "roles/logging.admin"
}

variable "role_monitoring"{
  default = "roles/monitoring.metricWriter"
}

variable "webapp_zone"{
  default = "webapp-zone"
}

variable "a_record_name"{
  default = "webappbysamiksha.me."
}

variable "a_record_type"{
  default = "A"
}

variable "ttl"{
  default = 300
}

variable "cloudfunction_service_account"{
  default = "cloudfunction-service-account"
}

variable "pubsub_subscriber"{
  default = "roles/pubsub.subscriber"
}

variable "run_invoker"{
  default = "roles/run.invoker"
}

variable "cloudfunction_invoker"{
  default = "roles/cloudfunctions.invoker"
}

variable "cloudsql_client"{
  default = "roles/cloudsql.client"
}

variable "vpcaccess"{
  default = "roles/vpcaccess.user"
}

variable "pubsub_publisher"{
  default = "roles/pubsub.publisher"
}

variable "webapp_connector"{
  default = "webapp-connector"
}

variable "connector_range"{
  default = "10.8.0.0/28"
}

variable "verify_email"{
  default = "verify_email"
}

variable "duration"{
  default = "604800s"
}

variable "verify_email_function"{
  default = "verify_email_function"
}

variable "description"{
  default = "Send emails to user for verifications"
}

variable "entry_point"{
  default = "helloPubSub"
}

variable "bucket"{
  default = "serverless-bucket-samiksha"
}

variable "object"{
  default = "serverless"
}

variable "retry_policy"{
  default = "RETRY_POLICY_RETRY"
}

variable "maintenance"{
  default = "MIGRATE"
}

variable "health_check"{
  default = "webapp-health-check"
}

variable "group_manager"{
  default = "webapp-instance-group-manager"
}

variable "source_range1" {
 default = "130.211.0.0/22"
}

variable "source_range2" {
 default = "35.191.0.0/16"
}

variable "mailgun_key"{
  default = "0efc8714590af835c49c2dfe48e0ce14-f68a26c9-df767f84"
}

variable "account" {
  default = "service-759856488127@compute-system.iam.gserviceaccount.com"
}

variable "kms_key"{
  default = "webapp-kms-key"
}

variable "rotation_period"{
  default = "2592000s"
}

variable "cloudsql_key"{
  default = "webapp-cloudsql-key"
}

variable "cloudsql_rotation_period"{
  default = "604800s"
}

variable "storage_key"{
  default = "webapp-storage-key"
}

variable "object_key"{
  default = "webapp-object-key"
}

variable "serverless"{
  default = "serverless"
}