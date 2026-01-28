# DDoS Protection with CrowdSec

This document explains the DDoS protection implementation for the Secure API Platform.

---

## 1. Reason for Choosing CrowdSec

After evaluating several open-source DDoS protection solutions, **CrowdSec** was selected for this project.

### Alternatives Considered

| Solution | Pros | Cons | Decision |
|----------|------|------|----------|
| **NGINX Ingress + ModSecurity** | Mature WAF, OWASP rules | Heavy, complex config, not K8s-native | ❌ Rejected |
| **Kong + ModSecurity** | Integrates with Kong | Requires Lua plugin, limited community | ❌ Rejected |
| **Envoy Rate Controls** | Fast, cloud-native | Limited to rate limiting, no behavioral analysis | ❌ Rejected |
| **CrowdSec** | Lightweight, K8s-native, community threat intel | Newer project | ✅ **Selected** |

### Why CrowdSec is the Best Choice

#### 1. **Open-Source & Self-Managed**
- MIT License - no vendor lock-in
- Runs entirely in your Kubernetes cluster
- No SaaS dependency - fully self-managed
- Can run air-gapped if needed

#### 2. **Kubernetes-Native Architecture**
- Official Helm chart for easy deployment
- Runs as Kubernetes Deployments and DaemonSets
- Lightweight footprint (~50MB memory)
- Designed for containerized environments

#### 3. **Behavioral Analysis (Not Just Rate Limiting)**
- Detects attack patterns, not just request counts
- Machine learning-based anomaly detection
- Identifies: HTTP floods, brute force, scanners, crawlers
- Customizable scenarios in YAML

#### 4. **Community Threat Intelligence**
- 70,000+ users share threat data globally
- Real-time blocklists of known attackers
- 15,000+ malicious IPs blocked automatically
- Crowdsourced protection without central dependency

#### 5. **Multi-Layer Protection**
- Layer 4 (Network): Connection-level protection
- Layer 7 (Application): HTTP-level detection
- Works alongside Kong's rate limiting (defense-in-depth)

---

## 2. Integration with Kong and Kubernetes

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           KUBERNETES CLUSTER                                │
│                                                                             │
│  ┌─────────────┐                                                            │
│  │   Client    │                                                            │
│  │  (Attacker) │                                                            │
│  └──────┬──────┘                                                            │
│         │                                                                   │
│         ▼                                                                   │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        KONG API GATEWAY                               │  │
│  │  ┌────────────────────────────────────────────────────────────────┐  │  │
│  │  │                    Protection Layers                            │  │  │
│  │  │                                                                  │  │  │
│  │  │  Layer 1: IP Whitelisting (ip-restriction plugin)              │  │  │
│  │  │           → Block requests from non-whitelisted IPs            │  │  │
│  │  │                                                                  │  │  │
│  │  │  Layer 2: Rate Limiting (rate-limiting plugin)                 │  │  │
│  │  │           → 10 requests/minute per IP                          │  │  │
│  │  │           → Returns HTTP 429 when exceeded                     │  │  │
│  │  │                                                                  │  │  │
│  │  │  Layer 3: JWT Authentication (jwt plugin)                      │  │  │
│  │  │           → Validates tokens for protected routes              │  │  │
│  │  │                                                                  │  │  │
│  │  └────────────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────┬───────────────────────────────────┘  │
│                                     │ Access Logs                          │
│                                     ▼                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                      CROWDSEC (DDoS Protection)                       │  │
│  │                                                                        │  │
│  │  ┌─────────────────────────┐    ┌─────────────────────────────────┐  │  │
│  │  │    CrowdSec Agent       │    │      CrowdSec LAPI              │  │  │
│  │  │    (DaemonSet)          │    │      (Deployment)               │  │  │
│  │  │                         │    │                                  │  │  │
│  │  │  • Collects logs        │───▶│  • Decision engine              │  │  │
│  │  │  • Parses access logs   │    │  • Stores banned IPs            │  │  │
│  │  │  • Detects patterns     │    │  • Community threat intel       │  │  │
│  │  │                         │    │  • API for bouncers             │  │  │
│  │  └─────────────────────────┘    └─────────────────────────────────┘  │  │
│  │                                                                        │  │
│  │  Detection Scenarios:                                                  │  │
│  │  ├── crowdsecurity/http-generic-bf    (Brute Force)                   │  │
│  │  ├── crowdsecurity/http-crawl         (Web Crawlers)                  │  │
│  │  ├── crowdsecurity/http-probing       (Scanning)                      │  │
│  │  ├── crowdsecurity/http-dos           (DoS Attacks)                   │  │
│  │  └── crowdsecurity/http-sensitive-files (Path Traversal)             │  │
│  │                                                                        │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                     │                                      │
│                                     ▼                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        USER SERVICE (Flask)                           │  │
│  │                              + SQLite                                 │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Kubernetes Resources

| Resource | Type | Purpose |
|----------|------|---------|
| `crowdsec-lapi` | Deployment | Decision engine, stores bans, serves bouncer API |
| `crowdsec-agent` | DaemonSet | Collects logs from each node, detects attacks |
| `crowdsec-service` | Service | Internal API for bouncer communication |
| `crowdsec-lapi-secrets` | Secret | API keys and credentials |

### Integration Flow

```
1. Client sends request
        ↓
2. Kong receives request
        ↓
3. Kong plugins process:
   a. IP Restriction → Check whitelist
   b. Rate Limiting → Check request count
   c. JWT Auth → Validate token (if protected route)
        ↓
4. Kong logs request to access log
        ↓
5. CrowdSec Agent reads access logs
        ↓
6. CrowdSec applies detection scenarios
        ↓
7. If attack detected → Add decision (ban IP)
        ↓
8. Future requests from banned IP → Blocked
```

### Helm Deployment

CrowdSec is deployed via Helm chart:

```bash
# Add CrowdSec Helm repo
helm repo add crowdsec https://crowdsecurity.github.io/helm-charts
helm repo update

# Install CrowdSec
helm install crowdsec crowdsec/crowdsec \
  -n api-platform \
  -f crowdsec/helm-values.yaml
```

---

## 3. Demonstrating Basic Protection Behavior

### 3.1 Verify CrowdSec is Running

```bash
# Check pods
kubectl get pods -n api-platform | grep crowdsec

# Expected output:
# crowdsec-lapi-xxxxx   1/1     Running   0          xxh
# crowdsec-agent-xxxxx  1/1     Running   0          xxh (on each node)
```

### 3.2 Check CrowdSec Version and Status

```bash
# Get LAPI pod name
LAPI_POD=$(kubectl get pods -n api-platform -l app=crowdsec-lapi -o jsonpath='{.items[0].metadata.name}')

# Check version
kubectl exec -n api-platform $LAPI_POD -- cscli version

# Expected output:
# version: v1.7.4
# Codename: alphaga
# Platform: docker
```

### 3.3 View Installed Detection Scenarios

```bash
kubectl exec -n api-platform $LAPI_POD -- cscli scenarios list
```

**Expected output:**
```
Name                                    Status    Version
crowdsecurity/http-generic-bf           enabled   0.9
crowdsecurity/http-crawl-non_statics    enabled   0.7
crowdsecurity/http-probing              enabled   0.4
crowdsecurity/http-sensitive-files      enabled   0.4
...
```

### 3.4 View Protection Metrics

```bash
kubectl exec -n api-platform $LAPI_POD -- cscli metrics
```

**Expected output:**
```
+-------------------+--------+--------+-------+
| Reason            | Origin | Action | Count |
+-------------------+--------+--------+-------+
| http:dos          | CAPI   | ban    | 5759  |
| http:bruteforce   | CAPI   | ban    | 1276  |
| http:scan         | CAPI   | ban    | 2509  |
+-------------------+--------+--------+-------+
```

### 3.5 Demonstrate Manual IP Ban

```bash
# Ban a test IP for 5 minutes
kubectl exec -n api-platform $LAPI_POD -- \
  cscli decisions add --ip 203.0.113.100 --duration 5m --reason "test:manual-ban"

# Verify the ban
kubectl exec -n api-platform $LAPI_POD -- cscli decisions list

# Expected output:
# +-------+--------+------------------+-----------------+--------+------------+
# |   ID  | Source |    Scope:Value   |      Reason     | Action | expiration |
# +-------+--------+------------------+-----------------+--------+------------+
# | 12345 | cscli  | Ip:203.0.113.100 | test:manual-ban | ban    | 4m59s      |
# +-------+--------+------------------+-----------------+--------+------------+

# Remove the test ban
kubectl exec -n api-platform $LAPI_POD -- \
  cscli decisions delete --ip 203.0.113.100
```

### 3.6 Demonstrate Rate Limiting (Kong Layer)

```bash
# Set Kong URL
export KONG_URL="http://127.0.0.1:32523"

# Send 15 rapid requests (limit is 10/minute)
for i in {1..15}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" $KONG_URL/health)
  echo "Request $i: HTTP $STATUS"
done
```

**Expected output:**
```
Request 1: HTTP 200
Request 2: HTTP 200
...
Request 10: HTTP 200
Request 11: HTTP 429  ← Rate limited
Request 12: HTTP 429
...
```

### 3.7 View Rate Limit Headers

```bash
curl -I $KONG_URL/health 2>&1 | grep -i ratelimit
```

**Expected output:**
```
X-RateLimit-Limit-Minute: 10
X-RateLimit-Remaining-Minute: 9
RateLimit-Limit: 10
RateLimit-Remaining: 9
RateLimit-Reset: 55
```

---

## Summary

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| **Open-source DDoS protection** | CrowdSec v1.7.4 (MIT License) | ✅ |
| **Self-managed** | Runs in Kubernetes cluster | ✅ |
| **Reason for choosing** | See Section 1 above | ✅ |
| **Kong integration** | Complements Kong rate limiting | ✅ |
| **Kubernetes integration** | Helm chart, Deployment, DaemonSet | ✅ |
| **Basic protection demo** | Manual ban, metrics, rate limiting | ✅ |

---

## Files in This Directory

| File | Purpose |
|------|---------|
| `README.md` | This documentation |
| `helm-values.yaml` | Helm chart values for CrowdSec |
| `crowdsec-deployment.yaml` | Alternative K8s manifests (if not using Helm) |

---

## Quick Reference Commands

```bash
# Get LAPI pod name
LAPI_POD=$(kubectl get pods -n api-platform -l app=crowdsec-lapi -o jsonpath='{.items[0].metadata.name}')

# Check version
kubectl exec -n api-platform $LAPI_POD -- cscli version

# List scenarios
kubectl exec -n api-platform $LAPI_POD -- cscli scenarios list

# View metrics
kubectl exec -n api-platform $LAPI_POD -- cscli metrics

# List banned IPs
kubectl exec -n api-platform $LAPI_POD -- cscli decisions list

# Ban an IP
kubectl exec -n api-platform $LAPI_POD -- cscli decisions add --ip 1.2.3.4 --duration 1h --reason "manual:test"

# Unban an IP
kubectl exec -n api-platform $LAPI_POD -- cscli decisions delete --ip 1.2.3.4

# Install HTTP scenarios
kubectl exec -n api-platform $LAPI_POD -- cscli collections install crowdsecurity/nginx
```
