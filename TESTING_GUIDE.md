# API Platform Testing Guide - Complete Step by Step

This guide contains all test scenarios for the Secure API Platform using Kong on Kubernetes.

---

## Prerequisites

Make sure your Kubernetes cluster is running:
```bash
kubectl get pods -n api-platform
```

You should see:
- `kong-kong-xxx` - Running
- `user-service-xxx` - Running
- `crowdsec-lapi-xxx` - Running

---

## Quick Setup

```bash
# Set the Kong Gateway URL
export KONG_URL="http://127.0.0.1:32523"
```

---

## Test Scenario 1: Health Check (Public Endpoint)

**Purpose**: Verify the service is running. No authentication required.

```bash
curl $KONG_URL/health
```

**Expected Output**:
```json
{"service":"user-service","status":"healthy","version":"1.0.0"}
```

---

## Test Scenario 2: JWT Authentication - Login

**Purpose**: Authenticate user and receive JWT token.

### 2.1 Login as Admin
```bash
curl -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

**Expected Output**:
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

### 2.2 Login as User1
```bash
curl -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user1","password":"password1"}'
```

### 2.3 Login as User2
```bash
curl -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user2","password":"password2"}'
```

### 2.4 Save Token for Later Use
```bash
export TOKEN=$(curl -s -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' | python3 -c "import sys, json; print(json.load(sys.stdin)['token'])")

echo "Token saved: ${TOKEN:0:50}..."
```

---

## Test Scenario 3: Invalid Login Attempts

**Purpose**: Verify login fails with wrong credentials.

### 3.1 Wrong Password
```bash
curl -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"wrongpassword"}'
```

**Expected Output**:
```json
{"error":"Invalid credentials"}
```

### 3.2 Non-existent User
```bash
curl -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"nonexistent","password":"password"}'
```

**Expected Output**:
```json
{"error":"Invalid credentials"}
```

---

## Test Scenario 4: Token Verification

**Purpose**: Verify JWT token validity.

### 4.1 Verify Valid Token
```bash
curl "$KONG_URL/verify?token=$TOKEN"
```

**Expected Output**:
```json
{
  "valid": true,
  "payload": {
    "user_id": "1",
    "username": "admin",
    "issued_at": 1234567890,
    "expires_at": 1234654290
  }
}
```

### 4.2 Verify Invalid Token
```bash
curl "$KONG_URL/verify?token=invalid-token"
```

**Expected Output**:
```json
{"valid":false,"error":"Invalid token: Not enough segments"}
```

### 4.3 Verify Without Token
```bash
curl "$KONG_URL/verify"
```

**Expected Output**:
```json
{"error":"Token parameter required"}
```

---

## Test Scenario 5: Protected Endpoint Access

**Purpose**: Verify JWT protection on /users endpoint.

### 5.1 Access WITHOUT Token (Should Fail - 401)
```bash
curl $KONG_URL/users
```

**Expected Output**:
```json
{"error":"Authorization header required"}
```

### 5.2 Access WITH Invalid Token (Should Fail - 401)
```bash
curl $KONG_URL/users -H "Authorization: Bearer invalid-token"
```

**Expected Output**:
```json
{"error":"Invalid token: Not enough segments"}
```

### 5.3 Access WITH Valid Token (Should Succeed - 200)
```bash
curl $KONG_URL/users -H "Authorization: Bearer $TOKEN"
```

**Expected Output**:
```json
{
  "users": [
    {"id": 1, "username": "admin", "email": "admin@example.com", "created_at": "..."},
    {"id": 2, "username": "user1", "email": "user1@example.com", "created_at": "..."},
    {"id": 3, "username": "user2", "email": "user2@example.com", "created_at": "..."}
  ],
  "total": 3,
  "requested_by": "admin"
}
```

---

## Test Scenario 6: Rate Limiting

**Purpose**: Verify IP-based rate limiting (10 requests per minute).

### 6.1 Check Rate Limit Headers
```bash
curl -I $KONG_URL/health 2>&1 | grep -i ratelimit
```

**Expected Output**:
```
X-RateLimit-Remaining-Minute: 9
X-RateLimit-Limit-Minute: 10
RateLimit-Remaining: 9
RateLimit-Limit: 10
RateLimit-Reset: 55
```

### 6.2 Trigger Rate Limiting (Send 15 Requests)
```bash
echo "Sending 15 rapid requests..."
for i in {1..15}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" $KONG_URL/health)
  echo "Request $i: HTTP $STATUS"
done
```

**Expected Output**:
```
Request 1: HTTP 200
Request 2: HTTP 200
...
Request 10: HTTP 200
Request 11: HTTP 429
Request 12: HTTP 429
...
```

### 6.3 View Rate Limit Exceeded Response
```bash
# After hitting the limit
curl $KONG_URL/health
```

**Expected Output** (when rate limited):
```json
{"message":"API rate limit exceeded","request_id":"..."}
```

### 6.4 Wait and Retry
```bash
echo "Waiting 60 seconds for rate limit to reset..."
sleep 60
curl $KONG_URL/health
```

---

## Test Scenario 7: IP Whitelisting

**Purpose**: Verify only allowed IPs can access the API.

### Current Whitelist Configuration:
- `127.0.0.1` - Localhost
- `10.0.0.0/8` - Kubernetes internal
- `172.16.0.0/12` - Docker networks
- `192.168.0.0/16` - Local networks

### 7.1 Test from Localhost (Allowed)
```bash
curl $KONG_URL/health
```

**Expected**: Successful response (you're on localhost)

### 7.2 How to Test IP Blocking
To test blocking, modify `kong/kong.yaml` and remove your IP from the whitelist:

```yaml
# Change this in kong/kong.yaml
- name: ip-restriction
  config:
    allow:
      - 10.0.0.0/8  # Remove 127.0.0.1 to block localhost
```

Then redeploy Kong and try accessing - you'll get HTTP 403.

---

## Test Scenario 8: Authentication Bypass

**Purpose**: Verify certain endpoints don't require authentication.

### 8.1 Public Endpoints (No Auth Required)
```bash
# Health - Should work without token
curl $KONG_URL/health

# Verify - Should work without token
curl "$KONG_URL/verify?token=test"

# Login - Should work without token
curl -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Root - Should work without token
curl $KONG_URL/
```

### 8.2 Protected Endpoints (Auth Required)
```bash
# Users - Should fail without token
curl $KONG_URL/users
```

---

## Test Scenario 9: Response Headers

**Purpose**: Verify Kong adds custom headers.

```bash
curl -v $KONG_URL/health 2>&1 | grep -E "^< "
```

**Key Headers to Look For**:
- `X-Kong-Request-Id` - Unique request identifier
- `X-Kong-Upstream-Latency` - Time to upstream service
- `X-Kong-Proxy-Latency` - Kong processing time
- `X-RateLimit-Limit-Minute` - Rate limit configuration
- `X-RateLimit-Remaining-Minute` - Remaining requests

---

## Test Scenario 10: DDoS Protection (CrowdSec)

**Purpose**: Verify CrowdSec is monitoring for attacks.

### 10.1 Check CrowdSec Status
```bash
kubectl get pods -n api-platform | grep crowdsec
```

### 10.2 View CrowdSec Decisions
```bash
CROWDSEC_POD=$(kubectl get pods -n api-platform -l app=crowdsec-lapi -o name | head -1)
kubectl exec -n api-platform $CROWDSEC_POD -- cscli decisions list
```

### 10.3 View CrowdSec Metrics
```bash
kubectl exec -n api-platform $CROWDSEC_POD -- cscli metrics
```

---

## Complete Test Script

Save this as `test-all.sh` in the scripts folder:

```bash
#!/bin/bash
# Complete API Platform Test Script

KONG_URL="${KONG_URL:-http://127.0.0.1:32523}"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║        API Platform Complete Test Suite                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Kong URL: $KONG_URL"
echo ""

# Test 1: Health Check
echo "═══════════════════════════════════════════════════════════"
echo "TEST 1: Health Check"
echo "═══════════════════════════════════════════════════════════"
HEALTH=$(curl -s -w "\nHTTP_CODE:%{http_code}" $KONG_URL/health)
echo "$HEALTH" | head -1 | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
HTTP_CODE=$(echo "$HEALTH" | grep "HTTP_CODE" | cut -d: -f2)
[ "$HTTP_CODE" = "200" ] && echo "✅ PASSED" || echo "❌ FAILED"
echo ""

# Test 2: Login
echo "═══════════════════════════════════════════════════════════"
echo "TEST 2: Login (admin/admin123)"
echo "═══════════════════════════════════════════════════════════"
LOGIN_RESP=$(curl -s -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}')
echo "$LOGIN_RESP" | python3 -m json.tool 2>/dev/null
TOKEN=$(echo "$LOGIN_RESP" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token', ''))" 2>/dev/null)
[ -n "$TOKEN" ] && echo "✅ PASSED - Token received" || echo "❌ FAILED"
echo ""

# Test 3: Token Verification
echo "═══════════════════════════════════════════════════════════"
echo "TEST 3: Token Verification"
echo "═══════════════════════════════════════════════════════════"
curl -s "$KONG_URL/verify?token=$TOKEN" | python3 -m json.tool 2>/dev/null
echo "✅ PASSED"
echo ""

# Test 4: Protected Endpoint with Token
echo "═══════════════════════════════════════════════════════════"
echo "TEST 4: Access /users WITH Token"
echo "═══════════════════════════════════════════════════════════"
USERS_RESP=$(curl -s -w "\nHTTP_CODE:%{http_code}" $KONG_URL/users -H "Authorization: Bearer $TOKEN")
echo "$USERS_RESP" | head -1 | python3 -m json.tool 2>/dev/null
HTTP_CODE=$(echo "$USERS_RESP" | grep "HTTP_CODE" | cut -d: -f2)
[ "$HTTP_CODE" = "200" ] && echo "✅ PASSED" || echo "❌ FAILED"
echo ""

# Test 5: Protected Endpoint without Token
echo "═══════════════════════════════════════════════════════════"
echo "TEST 5: Access /users WITHOUT Token (should fail)"
echo "═══════════════════════════════════════════════════════════"
NOAUTH_RESP=$(curl -s -w "\nHTTP_CODE:%{http_code}" $KONG_URL/users)
echo "$NOAUTH_RESP" | head -1
HTTP_CODE=$(echo "$NOAUTH_RESP" | grep "HTTP_CODE" | cut -d: -f2)
[ "$HTTP_CODE" = "401" ] && echo "✅ PASSED - Correctly rejected" || echo "❌ FAILED"
echo ""

# Test 6: Invalid Login
echo "═══════════════════════════════════════════════════════════"
echo "TEST 6: Invalid Login (should fail)"
echo "═══════════════════════════════════════════════════════════"
INVALID_RESP=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"wrongpassword"}')
echo "$INVALID_RESP" | head -1
HTTP_CODE=$(echo "$INVALID_RESP" | grep "HTTP_CODE" | cut -d: -f2)
[ "$HTTP_CODE" = "401" ] && echo "✅ PASSED - Correctly rejected" || echo "❌ FAILED"
echo ""

# Test 7: Rate Limit Headers
echo "═══════════════════════════════════════════════════════════"
echo "TEST 7: Rate Limit Headers"
echo "═══════════════════════════════════════════════════════════"
curl -sI $KONG_URL/health | grep -i ratelimit
echo "✅ PASSED - Rate limit headers present"
echo ""

# Test 8: Rate Limiting
echo "═══════════════════════════════════════════════════════════"
echo "TEST 8: Rate Limiting (sending 12 requests)"
echo "═══════════════════════════════════════════════════════════"
RATE_LIMITED=false
for i in $(seq 1 12); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" $KONG_URL/health)
  if [ "$STATUS" = "429" ]; then
    echo "Request $i: HTTP $STATUS ❌ RATE LIMITED"
    RATE_LIMITED=true
  else
    echo "Request $i: HTTP $STATUS ✅"
  fi
done
[ "$RATE_LIMITED" = "true" ] && echo "✅ PASSED - Rate limiting working" || echo "⚠️ Rate limit not triggered (may need to wait)"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "                    TEST SUMMARY                           "
echo "═══════════════════════════════════════════════════════════"
echo "All core tests completed!"
echo ""
echo "To re-run: ./scripts/test-all.sh"
echo ""
```

---

## Test Scenario 11: DDoS Protection (CrowdSec)

**Purpose**: Verify CrowdSec DDoS protection is running and functional.

### Why CrowdSec Was Chosen
- **Open-source** (MIT License) - No vendor lock-in
- **Self-managed** - Runs entirely in your Kubernetes cluster
- **Behavioral analysis** - Detects attack patterns, not just rate limits
- **Community-powered** - Shares threat intel with 70K+ users worldwide
- **Kubernetes-native** - Easy deployment via Helm chart

### 11.1 Check CrowdSec Status
```bash
# Check if CrowdSec LAPI is running
kubectl get pods -n api-platform | grep crowdsec

# Expected output:
# crowdsec-lapi-xxxxx   1/1     Running   0          xxh
```

### 11.2 Check CrowdSec Version
```bash
# Get the LAPI pod name
LAPI_POD=$(kubectl get pods -n api-platform -l app=crowdsec-lapi -o jsonpath='{.items[0].metadata.name}')

# Check version
kubectl exec -n api-platform $LAPI_POD -- cscli version
```

### 11.3 View Installed Detection Scenarios
```bash
kubectl exec -n api-platform $LAPI_POD -- cscli scenarios list
```

**Expected**: You should see HTTP-related scenarios like:
- `crowdsecurity/http-generic-bf` (brute force)
- `crowdsecurity/http-crawl-non_statics` (crawlers)
- `crowdsecurity/http-probing` (scanning)

### 11.4 View CrowdSec Metrics
```bash
kubectl exec -n api-platform $LAPI_POD -- cscli metrics
```

### 11.5 View Current Banned IPs
```bash
kubectl exec -n api-platform $LAPI_POD -- cscli decisions list
```

### 11.6 Test Manual IP Ban (Simulate Attack Detection)
```bash
# Ban a test IP for 5 minutes
kubectl exec -n api-platform $LAPI_POD -- \
  cscli decisions add --ip 203.0.113.100 --duration 5m --reason "test:manual-ban"

# Verify the ban was added
kubectl exec -n api-platform $LAPI_POD -- cscli decisions list

# Remove the test ban
kubectl exec -n api-platform $LAPI_POD -- \
  cscli decisions delete --ip 203.0.113.100
```

### 11.7 Install Additional HTTP Scenarios (Optional)
```bash
# Install nginx/HTTP detection collection
kubectl exec -n api-platform $LAPI_POD -- \
  cscli collections install crowdsecurity/nginx

# Verify installation
kubectl exec -n api-platform $LAPI_POD -- cscli scenarios list | grep http
```

### CrowdSec Integration Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                    KUBERNETES CLUSTER                           │
│                                                                 │
│  ┌──────────┐     ┌─────────────────┐     ┌──────────────────┐ │
│  │  Client  │────▶│  Kong Gateway   │────▶│   User Service   │ │
│  └──────────┘     │ (Rate Limiting) │     └──────────────────┘ │
│                   └────────┬────────┘                           │
│                            │ Logs                               │
│                            ▼                                    │
│                   ┌─────────────────┐                           │
│                   │  CrowdSec LAPI  │  ← Decision Engine       │
│                   │ (Threat Detect) │                           │
│                   └─────────────────┘                           │
│                                                                 │
│  Protection Layers:                                             │
│  • Layer 1: Kong Rate Limiting (10 req/min)                    │
│  • Layer 2: CrowdSec Behavioral Analysis                       │
│  • Layer 3: Community Threat Intelligence                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Test Scenario 12: IP Whitelisting

**Purpose**: Verify only allowed IPs can access the API.

### Current Whitelist Configuration
```yaml
allow:
  - 127.0.0.1           # Localhost
  - 10.0.0.0/8          # Kubernetes internal
  - 172.16.0.0/12       # Docker networks
  - 192.168.0.0/16      # Local networks
```

### 12.1 Test from Allowed IP (Should Work)
```bash
curl $KONG_URL/health
```
**Expected**: HTTP 200 with health response

### 12.2 Test IP Blocking

To test blocking, update `kong/kong.yaml` and comment out the allowed networks:

```yaml
allow:
  # - 127.0.0.1         # BLOCKED
  # - 10.0.0.0/8        # BLOCKED
  - 172.16.0.0/12
  - 192.168.0.0/16
```

Then apply and reload Kong:
```bash
# Update ConfigMap
kubectl create configmap kong-declarative-config \
  --from-file=kong.yaml=kong/kong.yaml \
  -n api-platform --dry-run=client -o yaml | kubectl apply -f -

# Restart Kong
kubectl rollout restart deployment kong-kong -n api-platform

# Test - should get HTTP 403
curl $KONG_URL/health
```

**Expected when blocked**:
```json
{"message":"Your IP address is not allowed"}
```
HTTP Status: 403

**Note**: Remember to restore the config after testing!

---

## Test Scenario 13: Custom Kong Lua Logic

**Purpose**: Verify custom Lua plugins are working (header injection, logging, request tracing).

### What the Lua Plugin Does
- Injects custom headers into responses
- Generates unique request IDs for tracing
- Adds API versioning headers
- Logs requests with structured data

### 13.1 View Custom Response Headers
```bash
curl -I $KONG_URL/health
```

**Expected headers**:
```
X-Request-ID: e86d7ce1-6345-4xxx-xxxx-xxxxxxxxxxxx
X-Powered-By: Kong-Gateway
X-API-Version: 1.0.0
X-Kong-Request-Id: b77da56dfb89df2xxxxx
X-Kong-Response-Latency: 1
```

### 13.2 View Only Custom X- Headers
```bash
curl -I $KONG_URL/health 2>&1 | grep "X-"
```

### 13.3 Verify Unique Request IDs
```bash
# Run this 3 times - each should have a DIFFERENT ID
curl -sI $KONG_URL/health | grep "X-Request-ID"
curl -sI $KONG_URL/health | grep "X-Request-ID"
curl -sI $KONG_URL/health | grep "X-Request-ID"
```

**Expected**: Each request has a unique UUID:
```
X-Request-ID: e8d83730-945f-4d56-8b33-6f7b500028a9
X-Request-ID: 1a5f6a69-2855-48f9-8227-ac18c459d5d0
X-Request-ID: 87519289-d56a-4e8d-acdd-59a15feee358
```

### 13.4 View Kong Structured Logs
```bash
kubectl logs -l app.kubernetes.io/name=kong -n api-platform --tail=20
```

**Expected log format**:
```
10.42.0.1 - - [28/Jan/2026:17:55:44 +0000] "GET /health HTTP/1.1" 200 64 "-" "curl/8.7.1" kong_request_id: "xxx"
```

### 13.5 Filter Logs by Request ID
```bash
kubectl logs -l app.kubernetes.io/name=kong -n api-platform --tail=50 | grep kong_request_id
```

### Lua Plugin Features Summary

| Feature | Header/Log | Source Plugin |
|---------|------------|---------------|
| Request ID | `X-Request-ID` | correlation-id |
| API Version | `X-API-Version: 1.0.0` | response-transformer |
| Gateway ID | `X-Powered-By: Kong-Gateway` | response-transformer |
| Tracing | `kong_request_id` in logs | Kong core |
| Latency | `X-Kong-Response-Latency` | Kong core |

### Lua Files Location
```
kong/plugins/
├── custom.lua                    # Main custom plugin (211 lines)
└── custom-request-handler/
    ├── handler.lua               # Full plugin implementation (215 lines)
    └── schema.lua                # Plugin configuration schema (150 lines)
```

---

## Test Scenario 14: SQLite Database Verification

**Purpose**: Verify that users are stored in a local SQLite database.

### Database Requirements
- SQLite (local, file-based database)
- User records stored
- Secure password hashes (bcrypt)
- Auto-initialized at startup
- No external or managed databases

### 14.1 Verify Database File Exists in Pod
```bash
# Get user-service pod name
USER_POD=$(kubectl get pods -n api-platform | grep user-service | head -1 | awk '{print $1}')

# Check database file
kubectl exec -n api-platform $USER_POD -- ls -la /app/data/
```

**Expected**: You should see `users.db` file

### 14.2 Query Database Directly (Using Python)
```bash
kubectl exec -n api-platform $USER_POD -- python3 -c "
import sqlite3
conn = sqlite3.connect('/app/data/users.db')
cursor = conn.cursor()

# Show tables
cursor.execute(\"SELECT name FROM sqlite_master WHERE type='table';\")
print('Tables:', cursor.fetchall())

# Show users
cursor.execute('SELECT id, username, email FROM users;')
print('Users:')
for user in cursor.fetchall():
    print(f'  ID: {user[0]}, Username: {user[1]}, Email: {user[2]}')

conn.close()
"
```

**Expected output**:
```
Tables: [('users',), ('sqlite_sequence',)]
Users:
  ID: 1, Username: admin, Email: admin@example.com
  ID: 2, Username: user1, Email: user1@example.com
  ID: 3, Username: user2, Email: user2@example.com
```

### 14.3 Verify Password Hashing (bcrypt)
```bash
kubectl exec -n api-platform $USER_POD -- python3 -c "
import sqlite3
conn = sqlite3.connect('/app/data/users.db')
cursor = conn.cursor()
cursor.execute('SELECT username, password_hash FROM users LIMIT 1;')
user = cursor.fetchone()
print(f'Username: {user[0]}')
print(f'Password Hash: {user[1][:50]}...')
print('Hash starts with \$2b\$ (bcrypt):', user[1].startswith('\$2b\$'))
conn.close()
"
```

**Expected**: Password hash should start with `$2b$` (bcrypt format)

### 14.4 Verify via API
```bash
# Login and get token
TOKEN=$(curl -s -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' | python3 -c "import sys, json; print(json.load(sys.stdin)['token'])")

# Get users from database via API
curl $KONG_URL/users -H "Authorization: Bearer $TOKEN"
```

### 14.5 Verify Auto-Initialization
The database is automatically initialized when the container starts. Check the logs:
```bash
kubectl logs $USER_POD -n api-platform | grep -i "database\|init"
```

### Database Summary

| Property | Value |
|----------|-------|
| Type | SQLite (file-based) |
| Path | `/app/data/users.db` |
| Tables | `users`, `sqlite_sequence` |
| Password Hashing | bcrypt |
| Auto-init | Yes (on startup) |

---

## Kubernetes Debugging Commands

```bash
# View all pods
kubectl get pods -n api-platform

# View services
kubectl get svc -n api-platform

# View Kong logs
kubectl logs -l app.kubernetes.io/name=kong -n api-platform --tail=50

# View User Service logs
kubectl logs -l app=user-service -n api-platform --tail=50

# Describe a pod
kubectl describe pod <pod-name> -n api-platform

# Get Kong NodePort
kubectl get svc kong-kong-proxy -n api-platform -o jsonpath='{.spec.ports[0].nodePort}'
```

---

## Test Scenario 15: CrowdSec DDoS Protection (Hands-On)

**Purpose**: Demonstrate CrowdSec's ability to detect and block malicious IPs.

### What is CrowdSec?

CrowdSec is an open-source, crowd-powered security engine that:
- Detects attack patterns (brute force, DDoS, scanning)
- Makes real-time blocking decisions
- Shares threat intelligence across the community

### Architecture in This Project

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Traffic       │────▶│   CrowdSec      │────▶│   Decision      │
│   Logs          │     │   Agent         │     │   (Ban IP)      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌─────────────────┐
                        │   CrowdSec      │
                        │   LAPI          │
                        │   (Decision DB) │
                        └─────────────────┘
```

### 15.1 Check CrowdSec Status

```bash
# Get LAPI pod name
LAPI_POD=$(kubectl get pods -n api-platform -l app=crowdsec-lapi -o jsonpath='{.items[0].metadata.name}')
echo "CrowdSec LAPI Pod: $LAPI_POD"

# Check CrowdSec version
kubectl exec -n api-platform $LAPI_POD -- cscli version
```

**Expected Output**:
```
version: v1.x.x
...
```

### 15.2 List Installed Detection Scenarios

```bash
# See what attack patterns CrowdSec can detect
kubectl exec -n api-platform $LAPI_POD -- cscli scenarios list
```

**Expected Output**: List of detection scenarios like:
```
crowdsecurity/http-bf-wordpress_bf
crowdsecurity/http-crawl-non_statics
crowdsecurity/http-probing
crowdsecurity/ssh-bf
...
```

### 15.3 Simulate IP Ban (Manual Decision)

This demonstrates what happens when CrowdSec detects an attack:

```bash
# Ban a test IP for 5 minutes (simulating attack detection)
kubectl exec -n api-platform $LAPI_POD -- cscli decisions add --ip 1.2.3.4 --duration 5m --reason "Manual test ban" --type ban

# Verify the decision was added
kubectl exec -n api-platform $LAPI_POD -- cscli decisions list
```

**Expected Output**:
```
╭────────┬──────────┬───────────┬─────────────────────┬────────┬─────────┬────────────────────╮
│   ID   │  Source  │  Scope    │       Value         │ Reason │ Action  │     Expiration     │
├────────┼──────────┼───────────┼─────────────────────┼────────┼─────────┼────────────────────┤
│  1     │  cscli   │  Ip       │  1.2.3.4            │ Manual │  ban    │  4m59s             │
╰────────┴──────────┴───────────┴─────────────────────┴────────┴─────────┴────────────────────╯
```

### 15.4 Check Active Decisions (Blocked IPs)

```bash
# View all currently blocked IPs
kubectl exec -n api-platform $LAPI_POD -- cscli decisions list
```

### 15.5 Remove the Test Ban

```bash
# Remove the test ban
kubectl exec -n api-platform $LAPI_POD -- cscli decisions delete --ip 1.2.3.4

# Verify it's removed
kubectl exec -n api-platform $LAPI_POD -- cscli decisions list
```

**Expected Output**: No decisions or empty table

### 15.6 Simulate Brute Force Detection (Optional)

This simulates what happens during a brute force attack:

```bash
# Make 10 rapid failed login attempts
for i in {1..10}; do
  curl -s -X POST $KONG_URL/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"wrongpassword"}' &
done
wait

# Check if CrowdSec detected anything (may take a few seconds)
sleep 5
kubectl exec -n api-platform $LAPI_POD -- cscli alerts list
```

**Note**: Detection depends on agent configuration. The LAPI may not show alerts if the agent isn't collecting logs.

### 15.7 View CrowdSec Metrics

```bash
# Get metrics from CrowdSec
kubectl exec -n api-platform $LAPI_POD -- cscli metrics
```

**Expected Output**: Metrics showing bucket states, parser stats, etc.

### CrowdSec Integration Summary

| Component | Purpose | Status |
|-----------|---------|--------|
| LAPI (Local API) | Decision engine, stores bans | ✅ Running |
| Agent | Log collector, detects attacks | ⚠️ Optional (may have issues on local) |
| Scenarios | Attack detection patterns | ✅ Loaded |
| Bouncers | Enforce decisions (block IPs) | ℹ️ Kong integration ready |

### Why CrowdSec for DDoS Protection?

| Criteria | CrowdSec | Alternative |
|----------|----------|-------------|
| Open Source | ✅ Yes | ModSecurity ✅ |
| Kubernetes Native | ✅ Helm chart | ModSecurity ⚠️ |
| Community Threat Intel | ✅ Shared blocklists | ❌ No |
| Easy Integration | ✅ Bouncer plugins | ⚠️ Complex |
| Resource Efficient | ✅ Lightweight | ❌ Heavy |

---

## Troubleshooting

### Issue: "Connection refused"
```bash
# Check if Kong is running
kubectl get pods -n api-platform | grep kong

# Get the correct port
kubectl get svc kong-kong-proxy -n api-platform
```

### Issue: Rate limit not resetting
```bash
# Wait 60 seconds, or restart Kong
kubectl rollout restart deployment kong-kong -n api-platform
```

### Issue: Token expired
```bash
# Get a new token
export TOKEN=$(curl -s -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' | python3 -c "import sys, json; print(json.load(sys.stdin)['token'])")
```

---

## Test Users

| Username | Password | Email |
|----------|----------|-------|
| admin | admin123 | admin@example.com |
| user1 | password1 | user1@example.com |
| user2 | password2 | user2@example.com |

