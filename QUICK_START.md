# Quick Start Guide - Clone and Run

This guide helps you set up the Secure API Platform from scratch on any system.

---

## Prerequisites

### Required Tools

| Tool | Version | Check Command | Install Link |
|------|---------|---------------|--------------|
| Docker | 20.10+ | `docker --version` | [Install Docker](https://docs.docker.com/get-docker/) |
| kubectl | 1.25+ | `kubectl version` | [Install kubectl](https://kubernetes.io/docs/tasks/tools/) |
| Helm | 3.12+ | `helm version` | [Install Helm](https://helm.sh/docs/intro/install/) |

### Kubernetes Cluster (Choose One)

| Option | Best For | Install |
|--------|----------|---------|
| **Rancher Desktop** | macOS/Windows | [Install](https://rancherdesktop.io/) |
| **Docker Desktop** | macOS/Windows | [Install](https://www.docker.com/products/docker-desktop/) |
| **Minikube** | All platforms | [Install](https://minikube.sigs.k8s.io/docs/start/) |
| **Kind** | CI/CD, Linux | [Install](https://kind.sigs.k8s.io/) |

---

## Step-by-Step Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/tohiddd/API-Platform-using-Kong.git
cd API-Platform-using-Kong
```

### Step 2: Start Your Kubernetes Cluster

**Option A: Rancher Desktop**
- Open Rancher Desktop application
- Wait for Kubernetes to be ready (green indicator)

**Option B: Docker Desktop**
- Open Docker Desktop
- Go to Settings → Kubernetes → Enable Kubernetes
- Wait for Kubernetes to start

**Option C: Minikube**
```bash
minikube start --memory=4096 --cpus=2
```

**Option D: Kind**
```bash
kind create cluster --name api-platform
```

### Step 3: Verify Cluster is Running

```bash
kubectl cluster-info
kubectl get nodes
```

Expected output:
```
Kubernetes control plane is running at https://127.0.0.1:6443
NAME                   STATUS   ROLES           AGE   VERSION
docker-desktop         Ready    control-plane   10m   v1.28.0
```

### Step 4: Run the Setup Script

```bash
# Make script executable
chmod +x scripts/setup-local.sh

# Run setup
./scripts/setup-local.sh
```

This script will:
1. ✅ Check prerequisites (Docker, kubectl, Helm)
2. ✅ Create namespace `api-platform`
3. ✅ Build the Docker image for user-service
4. ✅ Deploy user-service via Helm
5. ✅ Deploy Kong API Gateway via Helm
6. ✅ Apply Kong declarative configuration
7. ✅ Deploy CrowdSec for DDoS protection

### Step 5: Wait for Pods to be Ready

```bash
# Watch pods until all are Running
kubectl get pods -n api-platform -w

# Expected output (wait until all show Running):
# kong-kong-xxx          1/1     Running   0          2m
# user-service-xxx       1/1     Running   0          3m
# crowdsec-lapi-xxx      1/1     Running   0          1m
```

### Step 6: Get Kong Gateway URL

```bash
# Get the NodePort
kubectl get svc kong-kong-proxy -n api-platform

# Expected output:
# NAME              TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)
# kong-kong-proxy   NodePort   10.43.137.82   <none>        80:32523/TCP

# Set the URL (replace 32523 with your NodePort)
export KONG_URL="http://127.0.0.1:32523"
```

### Step 7: Test the API

```bash
# Health check
curl $KONG_URL/health

# Login
curl -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Save the token and access protected endpoint
export TOKEN="<paste-token-from-login>"
curl $KONG_URL/users -H "Authorization: Bearer $TOKEN"
```

### Step 8: Run Full Test Suite

```bash
./scripts/test-all.sh
```

---

## Quick Commands Reference

### Check Status
```bash
# All pods
kubectl get pods -n api-platform

# All services
kubectl get svc -n api-platform

# Kong proxy URL
kubectl get svc kong-kong-proxy -n api-platform
```

### View Logs
```bash
# Kong logs
kubectl logs -l app.kubernetes.io/name=kong -n api-platform --tail=50

# User Service logs
kubectl logs -l app.kubernetes.io/name=user-service -n api-platform --tail=50
```

### Restart Services
```bash
# Restart Kong
kubectl rollout restart deployment kong-kong -n api-platform

# Restart User Service
kubectl rollout restart deployment user-service -n api-platform
```

### Clean Up
```bash
# Delete all resources
kubectl delete namespace api-platform

# Stop Minikube (if using)
minikube stop
```

---

## Troubleshooting

### Issue: "connection refused" when accessing Kong

```bash
# Check if Kong pod is running
kubectl get pods -n api-platform | grep kong

# Check Kong logs
kubectl logs -l app.kubernetes.io/name=kong -n api-platform --tail=20

# Verify correct port
kubectl get svc kong-kong-proxy -n api-platform -o jsonpath='{.spec.ports[0].nodePort}'
```

### Issue: Pods stuck in "Pending" or "ImagePullBackOff"

```bash
# Check pod events
kubectl describe pod <pod-name> -n api-platform

# For Minikube: Make sure to use Minikube's Docker daemon
eval $(minikube docker-env)
docker build -t user-service:1.0.0 ./microservice
```

### Issue: Rate limit exceeded (HTTP 429)

```bash
# Wait 60 seconds for rate limit to reset
# Or restart Kong to clear rate limit cache
kubectl rollout restart deployment kong-kong -n api-platform
```

### Issue: Token expired or invalid

```bash
# Get a new token
curl -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

---

## Test Users

| Username | Password | Email |
|----------|----------|-------|
| admin | admin123 | admin@example.com |
| user1 | password1 | user1@example.com |
| user2 | password2 | user2@example.com |

---

## API Endpoints

| Endpoint | Method | Auth Required | Description |
|----------|--------|---------------|-------------|
| `/health` | GET | No | Health check |
| `/login` | POST | No | Get JWT token |
| `/verify` | GET | No | Verify JWT token |
| `/users` | GET | Yes (JWT) | List all users |

---

## Next Steps

1. **Run full test suite**: `./scripts/test-all.sh`
2. **Read the testing guide**: [TESTING_GUIDE.md](TESTING_GUIDE.md)
3. **Explore the architecture**: [README.md](README.md)
4. **Fill in AI usage doc**: [ai-usage.md](ai-usage.md) (required for submission)

---

## Support

If you encounter issues:
1. Check pod logs: `kubectl logs <pod-name> -n api-platform`
2. Describe pods: `kubectl describe pod <pod-name> -n api-platform`
3. Check events: `kubectl get events -n api-platform --sort-by='.lastTimestamp'`

