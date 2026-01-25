# =============================================================================
# Terraform Variables
# =============================================================================
#
# Key Concept: Terraform Variables
# ---------------------------------
# Variables allow you to parameterize your Terraform configuration.
# They can be set via:
# - Default values (in this file)
# - terraform.tfvars file
# - Command line: terraform apply -var="name=value"
# - Environment variables: TF_VAR_name=value
#

# =============================================================================
# Kubernetes Configuration
# =============================================================================

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = ""  # Empty uses current context
}

variable "namespace" {
  description = "Kubernetes namespace for the API platform"
  type        = string
  default     = "api-platform"
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

# =============================================================================
# Resource Quotas
# =============================================================================

variable "quota_cpu_requests" {
  description = "Total CPU requests allowed in the namespace"
  type        = string
  default     = "4"
}

variable "quota_memory_requests" {
  description = "Total memory requests allowed in the namespace"
  type        = string
  default     = "4Gi"
}

variable "quota_cpu_limits" {
  description = "Total CPU limits allowed in the namespace"
  type        = string
  default     = "8"
}

variable "quota_memory_limits" {
  description = "Total memory limits allowed in the namespace"
  type        = string
  default     = "8Gi"
}

variable "quota_pods" {
  description = "Maximum number of pods allowed in the namespace"
  type        = string
  default     = "20"
}

variable "quota_services" {
  description = "Maximum number of services allowed in the namespace"
  type        = string
  default     = "10"
}

# =============================================================================
# Kong Configuration
# =============================================================================

variable "kong_replica_count" {
  description = "Number of Kong Gateway replicas"
  type        = number
  default     = 2
}

variable "kong_database_mode" {
  description = "Kong database mode (off for DB-less, postgres for database)"
  type        = string
  default     = "off"

  validation {
    condition     = contains(["off", "postgres"], var.kong_database_mode)
    error_message = "Kong database mode must be 'off' or 'postgres'."
  }
}

# =============================================================================
# User Service Configuration
# =============================================================================

variable "user_service_replica_count" {
  description = "Number of User Service replicas"
  type        = number
  default     = 2
}

variable "jwt_expiration_hours" {
  description = "JWT token expiration time in hours"
  type        = number
  default     = 24
}

# =============================================================================
# Security Configuration
# =============================================================================

variable "rate_limit_per_minute" {
  description = "Rate limit: requests per minute per IP"
  type        = number
  default     = 10
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP CIDR ranges"
  type        = list(string)
  default = [
    "127.0.0.1/32",
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16"
  ]
}

# =============================================================================
# CrowdSec Configuration
# =============================================================================

variable "crowdsec_enabled" {
  description = "Enable CrowdSec DDoS protection"
  type        = bool
  default     = true
}

variable "crowdsec_collections" {
  description = "CrowdSec collections to install"
  type        = list(string)
  default = [
    "crowdsecurity/nginx",
    "crowdsecurity/http-cve",
    "crowdsecurity/base-http-scenarios"
  ]
}

