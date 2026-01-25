# =============================================================================
# Helm Releases via Terraform
# =============================================================================
#
# Key Concept: Helm Provider in Terraform
# ----------------------------------------
# Terraform's Helm provider allows you to manage Helm releases
# as part of your infrastructure code. Benefits:
# - Single source of truth for infrastructure
# - Declarative chart deployments
# - Integrated with Terraform state
#

# =============================================================================
# Kong API Gateway
# =============================================================================

# Deploy Kong using the official Helm chart
resource "helm_release" "kong" {
  name       = "kong"
  namespace  = kubernetes_namespace.api_platform.metadata[0].name
  repository = "https://charts.konghq.com"
  chart      = "kong"
  version    = "2.33.0"  # Pin to specific version for reproducibility

  # Wait for deployment to complete
  wait    = true
  timeout = 600

  # Kong configuration values
  values = [
    yamlencode({
      # Deployment configuration
      replicaCount = var.kong_replica_count

      # Image configuration
      image = {
        repository = "kong"
        tag        = "3.4"
      }

      # Environment variables
      env = {
        database = var.kong_database_mode
        # Enable bundled plugins
        plugins = "bundled"
        # Logging
        proxy_access_log = "/dev/stdout"
        proxy_error_log  = "/dev/stderr"
        admin_access_log = "/dev/stdout"
        admin_error_log  = "/dev/stderr"
      }

      # Proxy service (external access)
      proxy = {
        enabled = true
        type    = "LoadBalancer"
        http = {
          enabled       = true
          containerPort = 8000
          servicePort   = 80
        }
        tls = {
          enabled       = true
          containerPort = 8443
          servicePort   = 443
        }
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
        }
      }

      # Admin API (internal only)
      admin = {
        enabled = true
        type    = "ClusterIP"
        http = {
          enabled       = true
          containerPort = 8001
          servicePort   = 8001
        }
      }

      # Ingress controller disabled (using Kong as standalone gateway)
      ingressController = {
        enabled = false
      }

      # Resources
      resources = {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        requests = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }

      # Pod disruption budget
      podDisruptionBudget = {
        enabled        = true
        maxUnavailable = 1
      }
    })
  ]

  depends_on = [kubernetes_namespace.api_platform]
}

# =============================================================================
# User Service (Local Chart)
# =============================================================================

# Deploy User Service using local Helm chart
resource "helm_release" "user_service" {
  name      = "user-service"
  namespace = kubernetes_namespace.api_platform.metadata[0].name
  chart     = "${path.module}/../helm/user-service"

  wait    = true
  timeout = 300

  values = [
    yamlencode({
      replicaCount = var.user_service_replica_count

      image = {
        repository = "user-service"
        tag        = "latest"
        pullPolicy = "IfNotPresent"
      }

      config = {
        flask = {
          host  = "0.0.0.0"
          port  = 5000
          debug = var.environment != "production"
        }
        jwt = {
          expirationHours = var.jwt_expiration_hours
        }
        database = {
          path = "/app/data/users.db"
        }
      }

      # Secrets are managed separately
      secrets = {
        jwtSecretKey = "PLACEHOLDER_REPLACE_WITH_ACTUAL_SECRET"
      }

      persistence = {
        enabled      = true
        size         = "1Gi"
        accessMode   = "ReadWriteOnce"
      }

      resources = {
        limits = {
          cpu    = "500m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.api_platform]
}

# =============================================================================
# CrowdSec (Optional)
# =============================================================================

resource "helm_release" "crowdsec" {
  count = var.crowdsec_enabled ? 1 : 0

  name       = "crowdsec"
  namespace  = kubernetes_namespace.api_platform.metadata[0].name
  repository = "https://crowdsecurity.github.io/helm-charts"
  chart      = "crowdsec"
  version    = "0.9.0"

  wait    = true
  timeout = 300

  values = [
    yamlencode({
      agent = {
        enabled = true
        env = [
          {
            name  = "COLLECTIONS"
            value = join(" ", var.crowdsec_collections)
          }
        ]
        resources = {
          limits = {
            memory = "256Mi"
            cpu    = "500m"
          }
          requests = {
            memory = "128Mi"
            cpu    = "100m"
          }
        }
      }

      lapi = {
        enabled = true
        persistence = {
          enabled = true
          size    = "1Gi"
        }
      }

      dashboard = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.api_platform]
}

# =============================================================================
# Outputs
# =============================================================================

output "kong_release_status" {
  description = "Kong Helm release status"
  value       = helm_release.kong.status
}

output "user_service_release_status" {
  description = "User Service Helm release status"
  value       = helm_release.user_service.status
}

output "crowdsec_release_status" {
  description = "CrowdSec Helm release status"
  value       = var.crowdsec_enabled ? helm_release.crowdsec[0].status : "disabled"
}

