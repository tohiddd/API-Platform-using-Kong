# =============================================================================
# Terraform Configuration for API Platform Infrastructure
# =============================================================================
#
# Key Concept: Terraform
# ----------------------
# Terraform is an Infrastructure as Code (IaC) tool that allows you to:
# - Define infrastructure in declarative configuration files
# - Version control your infrastructure
# - Apply changes incrementally and safely
# - Manage state to track real-world resources
#
# This configuration manages:
# - Kubernetes namespace
# - Network policies
# - Base infrastructure resources
#
# Usage:
#   terraform init      # Initialize providers
#   terraform plan      # Preview changes
#   terraform apply     # Apply changes
#   terraform destroy   # Destroy infrastructure
#

terraform {
  # Terraform version constraint
  required_version = ">= 1.0.0"

  # Required providers
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # Backend configuration for state storage
  # Uncomment and configure for production use
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "api-platform/terraform.tfstate"
  #   region         = "us-west-2"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

# =============================================================================
# Provider Configuration
# =============================================================================

# Kubernetes Provider
# Connects to your Kubernetes cluster
provider "kubernetes" {
  # Use kubeconfig file (default for local development)
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

# Helm Provider
# For deploying Helm charts
provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}

# =============================================================================
# Namespace
# =============================================================================

# Create the api-platform namespace
resource "kubernetes_namespace" "api_platform" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "api-platform"
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.environment
    }

    annotations = {
      "description" = "Secure API Platform with Kong Gateway"
    }
  }
}

# =============================================================================
# Network Policies
# =============================================================================

# Default deny all ingress traffic
# Only explicitly allowed traffic will be permitted
resource "kubernetes_network_policy" "default_deny_ingress" {
  metadata {
    name      = "default-deny-ingress"
    namespace = kubernetes_namespace.api_platform.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]
  }
}

# Allow traffic from Kong to User Service
resource "kubernetes_network_policy" "allow_kong_to_user_service" {
  metadata {
    name      = "allow-kong-to-user-service"
    namespace = kubernetes_namespace.api_platform.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "user-service"
      }
    }

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "kong"
          }
        }
      }

      ports {
        port     = 5000
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}

# Allow external traffic to Kong
resource "kubernetes_network_policy" "allow_external_to_kong" {
  metadata {
    name      = "allow-external-to-kong"
    namespace = kubernetes_namespace.api_platform.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "kong"
      }
    }

    ingress {
      ports {
        port     = 8000
        protocol = "TCP"
      }
      ports {
        port     = 8443
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}

# Allow CrowdSec to access Kong logs
resource "kubernetes_network_policy" "allow_crowdsec_access" {
  metadata {
    name      = "allow-crowdsec-access"
    namespace = kubernetes_namespace.api_platform.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "crowdsec"
      }
    }

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "kong"
          }
        }
      }

      ports {
        port     = 8080
        protocol = "TCP"
      }
    }

    egress {
      to {
        pod_selector {}
      }
    }

    policy_types = ["Ingress", "Egress"]
  }
}

# =============================================================================
# Resource Quotas
# =============================================================================

# Limit resources in the namespace
resource "kubernetes_resource_quota" "api_platform_quota" {
  metadata {
    name      = "api-platform-quota"
    namespace = kubernetes_namespace.api_platform.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.quota_cpu_requests
      "requests.memory" = var.quota_memory_requests
      "limits.cpu"      = var.quota_cpu_limits
      "limits.memory"   = var.quota_memory_limits
      "pods"            = var.quota_pods
      "services"        = var.quota_services
    }
  }
}

# =============================================================================
# Limit Ranges
# =============================================================================

# Default resource limits for pods
resource "kubernetes_limit_range" "api_platform_limits" {
  metadata {
    name      = "api-platform-limits"
    namespace = kubernetes_namespace.api_platform.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      default = {
        cpu    = "500m"
        memory = "256Mi"
      }

      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }

      min = {
        cpu    = "50m"
        memory = "64Mi"
      }

      max = {
        cpu    = "2"
        memory = "1Gi"
      }
    }
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "namespace" {
  description = "The name of the created namespace"
  value       = kubernetes_namespace.api_platform.metadata[0].name
}

output "namespace_labels" {
  description = "Labels applied to the namespace"
  value       = kubernetes_namespace.api_platform.metadata[0].labels
}

