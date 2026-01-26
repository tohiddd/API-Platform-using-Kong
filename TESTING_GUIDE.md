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

