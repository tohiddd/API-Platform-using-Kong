# Secure API Platform using Kong on Kubernetes

A production-ready, self-managed API platform built on Kubernetes with Kong API Gateway. This project demonstrates enterprise-grade API security patterns including JWT authentication, rate limiting, IP whitelisting, and DDoS protection.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Key Features](#key-features)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [API Documentation](#api-documentation)
- [Security Features](#security-features)
- [Testing Guide](#testing-guide)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### High-Level Architecture

```
                                    ┌─────────────────────────────────────────────────────────┐
                                    │                    Kubernetes Cluster                    │
                                    │                                                         │
    ┌──────────┐                   │  ┌─────────────────────────────────────────────────┐   │
    │  Client  │───────────────────┼─▶│              Kong API Gateway                    │   │
    │ (Browser/│   HTTPS/HTTP      │  │  ┌─────────────────────────────────────────┐    │   │
    │   API)   │                   │  │  │ Plugins:                                 │    │   │
    └──────────┘                   │  │  │ • JWT Authentication                     │    │   │
                                    │  │  │ • Rate Limiting (10 req/min per IP)     │    │   │
                                    │  │  │ • IP Whitelisting                       │    │   │
                                    │  │  │ • Custom Lua Plugin                     │    │   │
                                    │  │  │ • Response Transformer                  │    │   │
                                    │  │  └─────────────────────────────────────────┘    │   │
                                    │  └──────────────────────┬──────────────────────────┘   │
                                    │                         │                               │
                                    │                         ▼                               │
                                    │  ┌─────────────────────────────────────────────────┐   │
                                    │  │            User Service (Flask)                 │   │
                                    │  │  ┌─────────────────────────────────────────┐    │   │
                                    │  │  │ Endpoints:                               │    │   │
                                    │  │  │ • POST /login     → Authenticate         │    │   │
                                    │  │  │ • GET  /verify    → Verify JWT           │    │   │
                                    │  │  │ • GET  /users     → List users (JWT)     │    │   │
                                    │  │  │ • GET  /health    → Health check         │    │   │
                                    │  │  └─────────────────────────────────────────┘    │   │
                                    │  │                         │                        │   │
                                    │  │                         ▼                        │   │
                                    │  │              ┌─────────────────┐                │   │
                                    │  │              │  SQLite DB      │                │   │
                                    │  │              │  (users.db)     │                │   │
                                    │  │              └─────────────────┘                │   │
                                    │  └─────────────────────────────────────────────────┘   │
                                    │                                                         │
                                    │  ┌─────────────────────────────────────────────────┐   │
                                    │  │              CrowdSec (DDoS Protection)         │   │
                                    │  │  • HTTP Flood Detection                         │   │
                                    │  │  • Brute Force Prevention                       │   │
                                    │  │  • Behavioral Analysis                          │   │
                                    │  └─────────────────────────────────────────────────┘   │
                                    │                                                         │
                                    └─────────────────────────────────────────────────────────┘
```

### API Request Flow

```
┌──────────┐     ┌──────────────────────────────────────────────────────────────┐     ┌─────────────┐
│  Client  │────▶│                     Kong Gateway                              │────▶│   Backend   │
└──────────┘     │  1. IP Restriction Check                                      │     │   Service   │
                 │  2. Rate Limiting Check                                        │     └─────────────┘
                 │  3. JWT Validation (for protected routes)                      │
                 │  4. Custom Lua Plugin (headers, logging)                       │
                 │  5. Proxy to Upstream Service                                  │
                 └──────────────────────────────────────────────────────────────┘
```

### JWT Authentication Flow

```
┌──────────┐          ┌───────────────┐          ┌─────────────────┐
│  Client  │          │  Kong Gateway │          │  User Service   │
└────┬─────┘          └───────┬───────┘          └────────┬────────┘
     │                        │                           │
     │  1. POST /login        │                           │
     │  {username, password}  │                           │
     │───────────────────────▶│                           │
     │                        │  2. Forward to service    │
     │                        │──────────────────────────▶│
     │                        │                           │
     │                        │                           │ 3. Validate credentials
     │                        │                           │    against SQLite DB
     │                        │                           │
     │                        │  4. Return JWT token      │
     │                        │◀──────────────────────────│
     │  5. JWT Token          │                           │
     │◀───────────────────────│                           │
     │                        │                           │
     │  6. GET /users         │                           │
     │  Authorization: Bearer │                           │
     │───────────────────────▶│                           │
     │                        │ 7. Validate JWT           │
     │                        │    (Kong JWT Plugin)      │
     │                        │                           │
     │                        │ 8. Forward if valid       │
     │                        │──────────────────────────▶│
     │                        │                           │
     │                        │ 9. Return user list       │
     │                        │◀──────────────────────────│
     │  10. Response          │                           │
     │◀───────────────────────│                           │
     │                        │                           │
```

### Authentication Bypass Strategy

Certain routes are configured to bypass JWT authentication:

| Endpoint | Method | Authentication | Reason |
|----------|--------|----------------|--------|
| `/health` | GET | **Bypassed** | Kubernetes probes, monitoring |
| `/verify` | GET | **Bypassed** | Token validation utility |
| `/login` | POST | **Bypassed** | Authentication endpoint |
| `/` | GET | **Bypassed** | Service info |
| `/users` | GET | **Required** | Protected user data |

Kong implements this by only applying the JWT plugin to routes tagged as "protected".

---

## Key Features

- ✅ **JWT Authentication**: Secure token-based authentication
- ✅ **Rate Limiting**: 10 requests per minute per IP
- ✅ **IP Whitelisting**: Configurable CIDR-based access control
- ✅ **DDoS Protection**: CrowdSec integration with behavioral analysis
- ✅ **Custom Lua Plugin**: Request/response transformation and logging
- ✅ **Helm Charts**: Parameterized, reusable deployments
- ✅ **Terraform IaC**: Infrastructure as Code for Kubernetes resources
- ✅ **SQLite Database**: Self-managed, file-based persistence

---

## Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| API Gateway | Kong OSS 3.4 | Traffic management, security |
| Microservice | Python Flask | REST API implementation |
| Database | SQLite | User data persistence |
| Container Runtime | Docker | Application containerization |
| Orchestration | Kubernetes | Container orchestration |
| Package Manager | Helm | Kubernetes package management |
| IaC | Terraform | Infrastructure provisioning |
| DDoS Protection | CrowdSec | Threat detection and prevention |

---

## Project Structure

```
.
├── microservice/                 # User Service Microservice
│   ├── app/
│   │   ├── __init__.py
│   │   ├── config.py            # Configuration management
│   │   ├── database.py          # SQLite operations
│   │   ├── auth.py              # JWT authentication
│   │   ├── routes.py            # API endpoints
│   │   └── main.py              # Application entry point
│   ├── Dockerfile               # Container definition
│   ├── .dockerignore
│   └── requirements.txt         # Python dependencies
│
├── helm/                        # Helm Charts
│   ├── user-service/            # User Service chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── secret.yaml
│   │       ├── configmap.yaml
│   │       ├── pvc.yaml
│   │       ├── serviceaccount.yaml
│   │       └── hpa.yaml
│   │
│   └── kong/                    # Kong configuration chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── kong-configmap.yaml
│           └── kong-plugins-configmap.yaml
│
├── kong/                        # Kong Configuration
│   ├── kong.yaml               # Declarative configuration
│   └── plugins/
│       ├── custom.lua          # Simplified custom plugin
│       └── custom-request-handler/
│           ├── handler.lua     # Full plugin implementation
│           └── schema.lua      # Plugin schema
│
├── k8s/                        # Kubernetes Manifests
│   ├── namespace.yaml
│   ├── deployment.yaml         # Complete deployment
│   └── user-service-deployment.yaml
│
├── crowdsec/                   # DDoS Protection
│   ├── README.md              # CrowdSec documentation
│   ├── crowdsec-deployment.yaml
│   └── helm-values.yaml
│
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                # Main configuration
│   ├── variables.tf           # Variable definitions
│   ├── helm.tf                # Helm releases
│   └── terraform.tfvars.example
│
├── README.md                  # This file
└── ai-usage.md               # AI tool usage documentation
```

---

## Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Docker | 20.10+ | [Install Docker](https://docs.docker.com/get-docker/) |
| kubectl | 1.25+ | [Install kubectl](https://kubernetes.io/docs/tasks/tools/) |
| Helm | 3.12+ | [Install Helm](https://helm.sh/docs/intro/install/) |
| Terraform | 1.0+ | [Install Terraform](https://developer.hashicorp.com/terraform/downloads) |

### Kubernetes Cluster Options

Choose one of the following:

1. **Local Development**
   - [Minikube](https://minikube.sigs.k8s.io/docs/start/)
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - [Kind](https://kind.sigs.k8s.io/)
   - [k3s](https://k3s.io/)

2. **Cloud Providers**
   - Amazon EKS
   - Google GKE
   - Azure AKS

---

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/API-Platform-using-Kong.git
cd API-Platform-using-Kong
```

### 2. Start a Local Kubernetes Cluster

```bash
# Using Minikube
minikube start --memory=4096 --cpus=2

# Or using Kind
kind create cluster --name api-platform
```

### 3. Build the Microservice Image

```bash
cd microservice

# For Minikube: Use Minikube's Docker daemon
eval $(minikube docker-env)

# Build the image
docker build -t user-service:latest .
```

### 4. Deploy Using Helm

```bash
# Create namespace
kubectl create namespace api-platform

# Install User Service
helm install user-service ./helm/user-service -n api-platform

# Install Kong (using official chart)
helm repo add kong https://charts.konghq.com
helm install kong kong/kong -n api-platform \
  --set env.database=off \
  --set proxy.type=NodePort
```

### 5. Verify Deployment

```bash
# Check pods
kubectl get pods -n api-platform

# Get Kong proxy URL
minikube service kong-kong-proxy -n api-platform --url
```

### 6. Test the API

```bash
# Set the Kong URL
export KONG_URL=$(minikube service kong-kong-proxy -n api-platform --url | head -1)

# Health check
curl $KONG_URL/health

# Login
curl -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}'

# Use the token for protected routes
export TOKEN="<token-from-login>"
curl $KONG_URL/users -H "Authorization: Bearer $TOKEN"
```

---

## Detailed Setup

### Option A: Using Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# Preview changes
terraform plan

# Apply infrastructure
terraform apply
```

### Option B: Using Raw Kubernetes Manifests

```bash
# Apply all resources
kubectl apply -f k8s/deployment.yaml

# Apply Kong configuration
kubectl apply -f kong/
```

### Option C: Step-by-Step Helm Installation

```bash
# 1. Create namespace
kubectl create namespace api-platform

# 2. Deploy User Service
helm install user-service ./helm/user-service \
  -n api-platform \
  --set secrets.jwtSecretKey="your-production-secret" \
  --set replicaCount=2

# 3. Deploy Kong with configuration
helm install kong kong/kong -n api-platform \
  -f ./helm/kong/values.yaml

# 4. (Optional) Deploy CrowdSec
helm repo add crowdsec https://crowdsecurity.github.io/helm-charts
helm install crowdsec crowdsec/crowdsec \
  -n api-platform \
  -f ./crowdsec/helm-values.yaml
```

---

## API Documentation

### Authentication Endpoints

#### POST /login
Authenticate a user and receive a JWT token.

**Request:**
```bash
curl -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin123"
  }'
```

**Response:**
```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "username": "admin",
    "email": "admin@example.com"
  }
}
```

#### GET /verify
Verify a JWT token's validity.

**Request:**
```bash
curl "http://localhost:8000/verify?token=eyJhbGciOiJIUzI1NiIs..."
```

**Response:**
```json
{
  "valid": true,
  "payload": {
    "user_id": "1",
    "username": "admin",
    "issued_at": "2024-01-15T10:30:00Z",
    "expires_at": "2024-01-16T10:30:00Z"
  }
}
```

### Protected Endpoints

#### GET /users
List all users (requires JWT authentication).

**Request:**
```bash
curl http://localhost:8000/users \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..."
```

**Response:**
```json
{
  "users": [
    {
      "id": 1,
      "username": "admin",
      "email": "admin@example.com",
      "created_at": "2024-01-15T10:00:00"
    }
  ],
  "total": 1,
  "requested_by": "admin"
}
```

### Public Endpoints

#### GET /health
Health check endpoint for monitoring.

**Request:**
```bash
curl http://localhost:8000/health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "user-service",
  "version": "1.0.0"
}
```

### Default Test Users

| Username | Password | Email |
|----------|----------|-------|
| admin | admin123 | admin@example.com |
| user1 | password1 | user1@example.com |
| user2 | password2 | user2@example.com |

---

## Security Features

### 1. Rate Limiting

Kong enforces rate limiting at the gateway level:
- **Limit**: 10 requests per minute per IP
- **Policy**: Local (in-memory)
- **Response when exceeded**: HTTP 429

**Testing Rate Limiting:**

```bash
# Send 15 requests rapidly
for i in {1..15}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/health
done

# You should see 429 responses after the 10th request
```

### 2. IP Whitelisting

Configured allowed CIDR ranges:
- `127.0.0.1` - Localhost
- `10.0.0.0/8` - Kubernetes internal
- `172.16.0.0/12` - Docker networks
- `192.168.0.0/16` - Local networks

**Testing IP Whitelisting:**

```bash
# From an allowed IP (should work)
curl http://localhost:8000/health

# From a blocked IP (should return 403)
# Configure Kong to block your IP, then test
```

**Modifying Allowed IPs:**

Edit `helm/kong/values.yaml`:
```yaml
ipRestriction:
  config:
    allow:
      - 127.0.0.1
      - 10.0.0.0/8
      - 203.0.113.0/24  # Add your IP range
```

### 3. DDoS Protection (CrowdSec)

CrowdSec provides multi-layer protection:

**Detection Scenarios:**
- HTTP Flood: 50+ requests in 10 seconds
- API Abuse: 20+ failed requests in 1 minute
- Slow Loris: 5+ slow connections

**Testing DDoS Protection:**

```bash
# Generate flood traffic
for i in {1..100}; do
  curl -s http://localhost:8000/health &
done
wait

# Check if banned
curl http://localhost:8000/health
# Should return 403 if CrowdSec blocked your IP

# View CrowdSec decisions
kubectl exec -it $(kubectl get pods -n api-platform -l app=crowdsec -o name) \
  -n api-platform -- cscli decisions list
```

### 4. JWT Authentication

JWT tokens include:
- User ID (sub claim)
- Username
- Expiration time (24 hours default)
- Issuer identification

**Token Validation:**
1. Kong validates signature using shared secret
2. Kong checks expiration
3. Application performs additional validation

---

## Testing Guide

### Complete Test Suite

```bash
#!/bin/bash
# test-api.sh

KONG_URL=${KONG_URL:-"http://localhost:8000"}

echo "=== Testing API Platform ==="

# 1. Health Check
echo -e "\n1. Health Check"
curl -s $KONG_URL/health | jq

# 2. Login
echo -e "\n2. Login Test"
TOKEN=$(curl -s -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}' | jq -r '.token')
echo "Token received: ${TOKEN:0:50}..."

# 3. Token Verification
echo -e "\n3. Token Verification"
curl -s "$KONG_URL/verify?token=$TOKEN" | jq

# 4. Protected Route (with token)
echo -e "\n4. Get Users (authenticated)"
curl -s $KONG_URL/users -H "Authorization: Bearer $TOKEN" | jq

# 5. Protected Route (without token)
echo -e "\n5. Get Users (unauthenticated)"
curl -s -w "\nHTTP Status: %{http_code}\n" $KONG_URL/users

# 6. Rate Limiting Test
echo -e "\n6. Rate Limiting Test (sending 15 requests)"
for i in {1..15}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" $KONG_URL/health)
  echo "Request $i: $STATUS"
done

# 7. Invalid Login
echo -e "\n7. Invalid Login Test"
curl -s -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "wrongpassword"}' | jq

echo -e "\n=== Testing Complete ==="
```

### Individual Tests

**Test JWT Protected Routes:**
```bash
# Without token (should fail)
curl http://localhost:8000/users
# Expected: 401 Unauthorized

# With invalid token
curl http://localhost:8000/users -H "Authorization: Bearer invalid"
# Expected: 401 Unauthorized

# With valid token (should succeed)
curl http://localhost:8000/users -H "Authorization: Bearer $TOKEN"
# Expected: 200 OK with user list
```

**Test Rate Limiting:**
```bash
# Install hey for load testing
# brew install hey (macOS) or go install github.com/rakyll/hey@latest

# Send 50 requests in 10 seconds
hey -n 50 -c 10 http://localhost:8000/health

# Check rate limit headers
curl -v http://localhost:8000/health 2>&1 | grep -i ratelimit
```

---

## Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n api-platform

# View pod events
kubectl describe pod <pod-name> -n api-platform

# View logs
kubectl logs <pod-name> -n api-platform
```

#### Kong Not Routing

```bash
# Check Kong configuration
kubectl exec -it <kong-pod> -n api-platform -- kong config parse /etc/kong/kong.yaml

# View Kong logs
kubectl logs <kong-pod> -n api-platform
```

#### JWT Validation Failing

1. Verify secret matches between Kong and microservice
2. Check token expiration
3. Verify token format (Bearer prefix)

```bash
# Debug JWT
echo $TOKEN | cut -d'.' -f2 | base64 -d | jq
```

#### Rate Limiting Not Working

```bash
# Check if plugin is enabled
kubectl exec -it <kong-pod> -n api-platform -- kong config dbless

# View rate limit headers
curl -v http://localhost:8000/health 2>&1 | grep -i x-ratelimit
```

### Logs Location

```bash
# User Service logs
kubectl logs -l app=user-service -n api-platform

# Kong logs
kubectl logs -l app=kong -n api-platform

# CrowdSec logs
kubectl logs -l app=crowdsec -n api-platform
```

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
