# Demo Guide - Secure API Platform using Kong on Kubernetes

This guide explains all features, test scenarios, and benefits of the project. Use this for demo presentations or video walkthroughs.

---

## 🎯 Project Overview

### What This Project Does

This is a **Secure API Platform** that demonstrates enterprise-grade API security patterns using:

| Component | Technology | Purpose |
|-----------|------------|---------|
| API Gateway | Kong OSS | Routes traffic, enforces security |
| Microservice | Flask (Python) | Sample user service |
| Database | SQLite | Stores user credentials |
| Authentication | JWT | Secures protected endpoints |
| DDoS Protection | CrowdSec | Detects and blocks attacks |
| Orchestration | Kubernetes | Container management |
| Deployment | Helm Charts | Reproducible deployments |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         KUBERNETES CLUSTER                           │
│                                                                       │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────────────────┐ │
│  │   Client    │────▶│    Kong     │────▶│    User Service         │ │
│  │  (Browser/  │     │   Gateway   │     │    (Flask App)          │ │
│  │   curl)     │     │             │     │                         │ │
│  └─────────────┘     │  Plugins:   │     │  Endpoints:             │ │
│                      │  - JWT      │     │  - /login  (POST)       │ │
│                      │  - Rate     │     │  - /verify (GET)        │ │
│                      │    Limit    │     │  - /users  (GET)        │ │
│                      │  - IP       │     │  - /health (GET)        │ │
│                      │    Restrict │     │                         │ │
│                      └─────────────┘     │  Database:              │ │
│                             │            │  - SQLite (users.db)    │ │
│                             ▼            └─────────────────────────┘ │
│                      ┌─────────────┐                                 │
│                      │  CrowdSec   │                                 │
│                      │  (DDoS      │                                 │
│                      │  Protection)│                                 │
│                      └─────────────┘                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Test Scenarios Explained

### Test Scenario 1: Health Check (Public Endpoint)

**Purpose**: Verify the API is running and accessible without authentication.

**Why It Matters**:
- Health checks are used by Kubernetes for pod readiness
- Load balancers use health endpoints to route traffic
- Monitoring systems check health for alerting

**Demo Command**:
```bash
curl http://127.0.0.1:$KONG_PORT/health
```

**Expected Result**: `{"status": "healthy"}`

**Business Benefit**: 
- ✅ Zero-downtime deployments
- ✅ Automatic failover
- ✅ Monitoring integration

---

### Test Scenario 2: User Login (Authentication)

**Purpose**: Authenticate users and issue JWT tokens.

**Why It Matters**:
- Users must prove their identity before accessing protected resources
- JWT tokens are stateless and scalable
- Tokens have expiration times for security

**Demo Command**:
```bash
curl -X POST http://127.0.0.1:$KONG_PORT/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

**Expected Result**: 
```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {"id": 1, "username": "admin", "email": "admin@example.com"}
}
```

**Business Benefit**:
- ✅ Secure user authentication
- ✅ Stateless tokens (no server-side sessions)
- ✅ Token expiration for security

---

### Test Scenario 3: Token Verification

**Purpose**: Verify that a JWT token is valid and not expired.

**Why It Matters**:
- Clients can check if their token is still valid
- Useful for session refresh logic
- Debugging authentication issues

**Demo Command**:
```bash
curl http://127.0.0.1:$KONG_PORT/verify \
  -H "Authorization: Bearer $TOKEN"
```

**Expected Result**: `{"valid": true, "user": {...}}`

**Business Benefit**:
- ✅ Client-side token validation
- ✅ Proactive session management
- ✅ Reduced failed API calls

---

### Test Scenario 4: Protected Endpoint Access

**Purpose**: Access a protected resource using a valid JWT token.

**Why It Matters**:
- Demonstrates the core security model
- Only authenticated users can access sensitive data
- Kong validates the token before forwarding to microservice

**Demo Command**:
```bash
# With valid token
curl http://127.0.0.1:$KONG_PORT/users \
  -H "Authorization: Bearer $TOKEN"

# Without token (should fail)
curl http://127.0.0.1:$KONG_PORT/users
```

**Expected Results**:
- With token: `{"users": [...]}`
- Without token: `401 Unauthorized`

**Business Benefit**:
- ✅ Data protection
- ✅ Access control
- ✅ Compliance (GDPR, HIPAA, etc.)

---

### Test Scenario 5: Invalid Token Handling

**Purpose**: Verify that invalid/expired tokens are rejected.

**Why It Matters**:
- Ensures attackers can't use fake tokens
- Expired tokens are properly rejected
- Security audit compliance

**Demo Command**:
```bash
curl http://127.0.0.1:$KONG_PORT/users \
  -H "Authorization: Bearer invalid_token_here"
```

**Expected Result**: `401 Unauthorized`

**Business Benefit**:
- ✅ Prevents unauthorized access
- ✅ Security best practices
- ✅ Audit trail for failed attempts

---

### Test Scenario 6: Rate Limiting

**Purpose**: Prevent abuse by limiting requests per IP.

**Why It Matters**:
- Protects against brute force attacks
- Ensures fair usage across clients
- Prevents API abuse and overload

**Demo Command**:
```bash
# Make 15 rapid requests (limit is 10/minute)
for i in {1..15}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:$KONG_PORT/health
done
```

**Expected Result**: 
- First 10 requests: `200 OK`
- Remaining requests: `429 Too Many Requests`

**Configuration** (in `kong.yaml`):
```yaml
plugins:
  - name: rate-limiting
    config:
      minute: 10
      policy: local
      limit_by: ip
```

**Business Benefit**:
- ✅ DDoS mitigation
- ✅ Fair usage enforcement
- ✅ Cost control (API usage)
- ✅ Prevents brute force attacks

---

### Test Scenario 7: Authentication Bypass

**Purpose**: Verify that certain endpoints don't require authentication.

**Why It Matters**:
- Health checks must be accessible for monitoring
- Login endpoint must be public for users to authenticate
- Some endpoints are intentionally public

**Bypass Endpoints**:
| Endpoint | Reason for Bypass |
|----------|-------------------|
| `/health` | Kubernetes readiness probes |
| `/login` | Users need to authenticate |
| `/verify` | Token validation service |

**Demo Command**:
```bash
# These should work WITHOUT a token
curl http://127.0.0.1:$KONG_PORT/health   # ✅ Works
curl http://127.0.0.1:$KONG_PORT/verify   # ✅ Works
curl -X POST http://127.0.0.1:$KONG_PORT/login -d '...'  # ✅ Works

# This should REQUIRE a token
curl http://127.0.0.1:$KONG_PORT/users    # ❌ 401 Unauthorized
```

**Business Benefit**:
- ✅ Flexible security policies
- ✅ Proper system integration
- ✅ User-friendly authentication flow

---

### Test Scenario 8: IP Whitelisting

**Purpose**: Allow only trusted IP addresses to access the API.

**Why It Matters**:
- Restricts access to known networks
- Blocks traffic from unknown sources
- Defense in depth strategy

**Configuration** (in `kong.yaml`):
```yaml
plugins:
  - name: ip-restriction
    config:
      allow:
        - 127.0.0.1           # Localhost
        - 10.0.0.0/8          # Kubernetes pods
        - 172.16.0.0/12       # Docker networks
        - 192.168.0.0/16      # Private networks
```

**Demo Command**:
```bash
# Check current whitelist
kubectl get configmap kong-declarative-config -n api-platform -o yaml | grep -A10 "ip-restriction"
```

**Testing IP Blocking**:
1. Remove `127.0.0.1` and `10.0.0.0/8` from whitelist
2. Redeploy Kong
3. Try to access API → Should get `403 Forbidden`

**Business Benefit**:
- ✅ Network-level security
- ✅ Block malicious IPs
- ✅ Compliance requirements
- ✅ Zero-trust architecture

---

### Test Scenario 9-10: Error Handling

**Purpose**: Verify proper error responses for invalid requests.

**Test 9 - Invalid Credentials**:
```bash
curl -X POST http://127.0.0.1:$KONG_PORT/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"wrongpassword"}'
```
**Expected**: `401 Unauthorized - Invalid credentials`

**Test 10 - Missing Fields**:
```bash
curl -X POST http://127.0.0.1:$KONG_PORT/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin"}'
```
**Expected**: `400 Bad Request - Missing required fields`

**Business Benefit**:
- ✅ Clear error messages
- ✅ Debugging support
- ✅ Client-friendly API

---

### Test Scenario 11-12: Kong Headers & Request Tracing

**Purpose**: Verify custom headers are injected for observability.

**Demo Command**:
```bash
curl -I http://127.0.0.1:$KONG_PORT/health
```

**Expected Headers**:
```
X-Kong-Request-Id: abc-123-def-456
X-Kong-Response-Latency: 5
X-Powered-By: Kong-Gateway
```

**Business Benefit**:
- ✅ Request tracing
- ✅ Performance monitoring
- ✅ Debugging support
- ✅ API versioning

---

### Test Scenario 13: Custom Kong Lua Logic

**Purpose**: Demonstrate custom request/response processing.

**Implemented Features**:
| Feature | Description |
|---------|-------------|
| Request ID | Unique ID for each request |
| Response Timing | Latency measurement |
| Security Headers | X-Powered-By header |
| Structured Logging | Request details in logs |

**Lua Plugin Location**:
```
kong/plugins/
├── custom.lua                    # Main custom plugin
└── custom-request-handler/
    ├── handler.lua               # Full implementation
    └── schema.lua                # Configuration schema
```

**Business Benefit**:
- ✅ Custom business logic at gateway level
- ✅ No code changes to microservice
- ✅ Centralized request processing
- ✅ Observability enhancement

---

### Test Scenario 14: SQLite Database

**Purpose**: Verify user data is stored securely in SQLite.

**Demo Commands**:
```bash
# Get pod name
USER_POD=$(kubectl get pods -n api-platform | grep user-service | head -1 | awk '{print $1}')

# Check database exists
kubectl exec -n api-platform $USER_POD -- ls -la /app/data/

# Query users
kubectl exec -n api-platform $USER_POD -- python3 -c "
import sqlite3
conn = sqlite3.connect('/app/data/users.db')
cursor = conn.cursor()
cursor.execute('SELECT id, username, email FROM users;')
for user in cursor.fetchall():
    print(f'ID: {user[0]}, Username: {user[1]}, Email: {user[2]}')
conn.close()
"
```

**Expected Output**:
```
ID: 1, Username: admin, Email: admin@example.com
ID: 2, Username: user1, Email: user1@example.com
ID: 3, Username: user2, Email: user2@example.com
```

**Security Features**:
- ✅ Passwords hashed with bcrypt
- ✅ Auto-initialized at startup
- ✅ File-based (no external database needed)

---

### Test Scenario 15: CrowdSec DDoS Protection

**Purpose**: Demonstrate DDoS detection and IP blocking.

**What is CrowdSec?**
An open-source security engine that:
- Detects attack patterns (brute force, DDoS)
- Makes real-time blocking decisions
- Shares threat intelligence with community

**Demo Commands**:
```bash
# Set pod name
LAPI_POD=$(kubectl get pods -n api-platform | grep crowdsec-lapi | awk '{print $1}')

# 1. Check version
kubectl exec -n api-platform $LAPI_POD -- cscli version

# 2. List attack detection scenarios
kubectl exec -n api-platform $LAPI_POD -- cscli scenarios list

# 3. Ban a test IP (simulates attack detection)
kubectl exec -n api-platform $LAPI_POD -- cscli decisions add --ip 1.2.3.4 --duration 5m --reason "Test ban" --type ban

# 4. View blocked IPs
kubectl exec -n api-platform $LAPI_POD -- cscli decisions list

# 5. Remove ban
kubectl exec -n api-platform $LAPI_POD -- cscli decisions delete --ip 1.2.3.4
```

**Why CrowdSec?**
| Feature | CrowdSec | ModSecurity |
|---------|----------|-------------|
| Open Source | ✅ | ✅ |
| Kubernetes Native | ✅ | ⚠️ |
| Community Threat Intel | ✅ | ❌ |
| Resource Efficient | ✅ | ❌ |

**Business Benefit**:
- ✅ DDoS protection
- ✅ Brute force detection
- ✅ Community threat intelligence
- ✅ Real-time blocking

---

## 🎥 Demo Video Script

### Introduction (1 min)
"This is a Secure API Platform built on Kubernetes using Kong as the API Gateway. It demonstrates enterprise-grade security patterns including JWT authentication, rate limiting, IP whitelisting, and DDoS protection."

### Architecture Overview (2 min)
Show the architecture diagram and explain:
- Client requests go through Kong Gateway
- Kong applies security plugins (JWT, rate limiting, IP restriction)
- Valid requests are forwarded to the User Service
- CrowdSec monitors for attacks

### Demo: Health Check (30 sec)
```bash
curl http://127.0.0.1:$KONG_PORT/health
```
"Health endpoint is public for Kubernetes probes."

### Demo: Authentication Flow (2 min)
```bash
# Login
curl -X POST http://127.0.0.1:$KONG_PORT/login \
  -d '{"username":"admin","password":"admin123"}'

# Access protected endpoint
curl http://127.0.0.1:$KONG_PORT/users \
  -H "Authorization: Bearer $TOKEN"
```
"JWT tokens are issued on login and required for protected endpoints."

### Demo: Rate Limiting (1 min)
```bash
for i in {1..15}; do
  curl -s -o /dev/null -w "%{http_code} " http://127.0.0.1:$KONG_PORT/health
done
```
"After 10 requests, we get 429 Too Many Requests."

### Demo: DDoS Protection (2 min)
```bash
# Ban an IP
kubectl exec -n api-platform $LAPI_POD -- cscli decisions add --ip 1.2.3.4 --duration 5m --reason "Attack detected" --type ban

# View bans
kubectl exec -n api-platform $LAPI_POD -- cscli decisions list
```
"CrowdSec can detect and block malicious IPs in real-time."

### Conclusion (30 sec)
"This platform provides comprehensive API security with Kong Gateway, JWT authentication, rate limiting, IP whitelisting, and CrowdSec DDoS protection - all running on Kubernetes with reproducible Helm deployments."

---

## 📁 Project Structure

```
API-Platform-using-Kong/
├── microservice/           # Flask User Service
│   ├── app/
│   │   ├── auth.py         # JWT token handling
│   │   ├── database.py     # SQLite operations
│   │   ├── routes.py       # API endpoints
│   │   └── main.py         # Application entry
│   └── Dockerfile
├── helm/
│   ├── user-service/       # User Service Helm chart
│   └── kong/               # Kong Helm chart
├── kong/
│   ├── kong.yaml           # Declarative configuration
│   └── plugins/            # Custom Lua plugins
├── k8s/                    # Kubernetes manifests
├── crowdsec/               # DDoS protection config
├── terraform/              # Infrastructure as Code
├── scripts/
│   ├── setup-local.sh      # Local setup script
│   └── test-all.sh         # Automated tests
├── README.md               # Main documentation
├── QUICK_START.md          # Setup guide
├── TESTING_GUIDE.md        # Detailed test scenarios
└── DEMO_GUIDE.md           # This file
```

---

## ✅ Requirements Checklist

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| JWT Authentication | ✅ | Kong JWT plugin + Flask |
| Authentication Bypass | ✅ | `/health`, `/login`, `/verify` |
| Rate Limiting | ✅ | Kong rate-limiting plugin (10/min) |
| IP Whitelisting | ✅ | Kong ip-restriction plugin |
| DDoS Protection | ✅ | CrowdSec |
| Kubernetes | ✅ | Deployments, Services, ConfigMaps |
| Kong OSS | ✅ | Self-managed via Helm |
| SQLite Database | ✅ | Local file-based, bcrypt passwords |
| Helm Charts | ✅ | user-service, kong charts |
| Custom Lua Logic | ✅ | Request ID, headers, logging |
| Terraform | ✅ | Optional infrastructure code |

---

## 🔗 Quick Reference

### Test Users
| Username | Password |
|----------|----------|
| admin | admin123 |
| user1 | password1 |
| user2 | password2 |

### API Endpoints
| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/health` | GET | No | Health check |
| `/login` | POST | No | Get JWT token |
| `/verify` | GET | No | Verify token |
| `/users` | GET | Yes | List users |

### Kubernetes Commands
```bash
# Check pods
kubectl get pods -n api-platform

# View logs
kubectl logs -l app.kubernetes.io/name=kong -n api-platform --tail=20

# Restart Kong
kubectl rollout restart deployment kong-kong -n api-platform
```

---

*This guide was created to help explain the Secure API Platform for demos and presentations.*

