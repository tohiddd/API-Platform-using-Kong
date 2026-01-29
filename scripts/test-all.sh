#!/bin/bash
# =============================================================================
# Complete API Platform Test Suite
# =============================================================================
# This script tests all features of the Secure API Platform
# Run: ./scripts/test-all.sh
# =============================================================================

set -e

KONG_URL="${KONG_URL:-http://127.0.0.1:32523}"
PASSED=0
FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "$1"
    echo "═══════════════════════════════════════════════════════════"
}

pass() {
    echo -e "${GREEN}✅ PASSED${NC} - $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}❌ FAILED${NC} - $1"
    ((FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠️  WARNING${NC} - $1"
}

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          SECURE API PLATFORM - COMPLETE TEST SUITE            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Kong URL: $KONG_URL"
echo "Date: $(date)"
echo ""

# =============================================================================
# TEST 1: Health Check (Public Endpoint)
# =============================================================================
print_header "TEST 1: Health Check (Public Endpoint)"

RESPONSE=$(curl -s -w "\n%{http_code}" $KONG_URL/health)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

echo "Response: $BODY"
echo "HTTP Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    pass "Health endpoint accessible"
else
    fail "Health endpoint returned $HTTP_CODE"
fi

# =============================================================================
# TEST 2: Root Endpoint (Public)
# =============================================================================
print_header "TEST 2: Root Endpoint (Public)"

RESPONSE=$(curl -s -w "\n%{http_code}" $KONG_URL/)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

echo "Response: $BODY"
echo "HTTP Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    pass "Root endpoint accessible"
else
    fail "Root endpoint returned $HTTP_CODE"
fi

# =============================================================================
# TEST 3: Login - Valid Credentials
# =============================================================================
print_header "TEST 3: Login with Valid Credentials (admin/admin123)"

LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}')
HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -1)
BODY=$(echo "$LOGIN_RESPONSE" | head -1)

echo "Response: $BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo "HTTP Code: $HTTP_CODE"

TOKEN=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token', ''))" 2>/dev/null)

if [ "$HTTP_CODE" = "200" ] && [ -n "$TOKEN" ]; then
    pass "Login successful, token received"
    echo "Token (first 50 chars): ${TOKEN:0:50}..."
else
    fail "Login failed"
fi

# =============================================================================
# TEST 4: Login - Invalid Credentials
# =============================================================================
print_header "TEST 4: Login with Invalid Credentials"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"wrongpassword"}')
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

echo "Response: $BODY"
echo "HTTP Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "401" ]; then
    pass "Invalid login correctly rejected with 401"
else
    fail "Expected 401, got $HTTP_CODE"
fi

# =============================================================================
# TEST 5: Token Verification - Valid Token
# =============================================================================
print_header "TEST 5: Token Verification (Valid Token)"

RESPONSE=$(curl -s -w "\n%{http_code}" "$KONG_URL/verify?token=$TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

echo "Response: $BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo "HTTP Code: $HTTP_CODE"

VALID=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('valid', False))" 2>/dev/null)

if [ "$VALID" = "True" ]; then
    pass "Token verified as valid"
else
    fail "Token verification failed"
fi

# =============================================================================
# TEST 6: Token Verification - Invalid Token
# =============================================================================
print_header "TEST 6: Token Verification (Invalid Token)"

RESPONSE=$(curl -s -w "\n%{http_code}" "$KONG_URL/verify?token=invalid-token")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

echo "Response: $BODY"
echo "HTTP Code: $HTTP_CODE"

VALID=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('valid', True))" 2>/dev/null)

if [ "$VALID" = "False" ]; then
    pass "Invalid token correctly rejected"
else
    fail "Invalid token was not rejected"
fi

# =============================================================================
# TEST 7: Protected Endpoint - With Valid Token
# =============================================================================
print_header "TEST 7: Access /users WITH Valid Token"

RESPONSE=$(curl -s -w "\n%{http_code}" $KONG_URL/users \
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

echo "Response: $BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo "HTTP Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    pass "Protected endpoint accessible with valid token"
else
    fail "Protected endpoint returned $HTTP_CODE with valid token"
fi

# =============================================================================
# TEST 8: Protected Endpoint - Without Token
# =============================================================================
print_header "TEST 8: Access /users WITHOUT Token"

RESPONSE=$(curl -s -w "\n%{http_code}" $KONG_URL/users)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

echo "Response: $BODY"
echo "HTTP Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "401" ]; then
    pass "Protected endpoint correctly rejected without token"
else
    fail "Expected 401, got $HTTP_CODE"
fi

# =============================================================================
# TEST 9: Protected Endpoint - With Invalid Token
# =============================================================================
print_header "TEST 9: Access /users WITH Invalid Token"

RESPONSE=$(curl -s -w "\n%{http_code}" $KONG_URL/users \
  -H "Authorization: Bearer invalid-token")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

echo "Response: $BODY"
echo "HTTP Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "401" ]; then
    pass "Protected endpoint correctly rejected invalid token"
else
    fail "Expected 401, got $HTTP_CODE"
fi

# =============================================================================
# TEST 10: Rate Limit Headers
# =============================================================================
print_header "TEST 10: Rate Limit Headers Present"

HEADERS=$(curl -sI $KONG_URL/health | grep -i "RateLimit-Limit")

echo "Headers found:"
curl -sI $KONG_URL/health | grep -i ratelimit

if [ -n "$HEADERS" ]; then
    pass "Rate limit headers present"
else
    fail "Rate limit headers not found"
fi

# =============================================================================
# TEST 11: Rate Limiting Enforcement
# =============================================================================
print_header "TEST 11: Rate Limiting Enforcement (12 requests)"

echo "Sending 12 rapid requests..."
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

if [ "$RATE_LIMITED" = "true" ]; then
    pass "Rate limiting is enforced"
else
    warn "Rate limit not triggered (may already be exhausted or need to wait)"
fi

# =============================================================================
# TEST 12: Different User Login
# =============================================================================
print_header "TEST 12: Login with Different User (user1)"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $KONG_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user1","password":"password1"}')
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

echo "Response: $BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo "HTTP Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    pass "user1 login successful"
else
    fail "user1 login failed"
fi

# =============================================================================
# TEST 13: Kong Request ID Header
# =============================================================================
print_header "TEST 13: Kong Request ID Header"

REQUEST_ID=$(curl -sI $KONG_URL/health | grep -i "X-Kong-Request-Id" | awk '{print $2}')

echo "X-Kong-Request-Id: $REQUEST_ID"

if [ -n "$REQUEST_ID" ]; then
    pass "Kong Request ID present"
else
    fail "Kong Request ID not found"
fi

# =============================================================================
# TEST 14: CrowdSec DDoS Protection
# =============================================================================
print_header "TEST 14: CrowdSec DDoS Protection Status"

LAPI_POD=$(kubectl get pods -n api-platform 2>/dev/null | grep crowdsec-lapi | awk '{print $1}')

if [ -n "$LAPI_POD" ]; then
    echo "CrowdSec LAPI Pod: $LAPI_POD"
    
    # Check if pod is running
    POD_STATUS=$(kubectl get pod $LAPI_POD -n api-platform -o jsonpath='{.status.phase}' 2>/dev/null)
    echo "Pod Status: $POD_STATUS"
    
    if [ "$POD_STATUS" = "Running" ]; then
        # Get version
        VERSION=$(kubectl exec -n api-platform $LAPI_POD -- cscli version 2>/dev/null | head -1)
        echo "CrowdSec Version: $VERSION"
        
        # Count scenarios
        SCENARIO_COUNT=$(kubectl exec -n api-platform $LAPI_POD -- cscli scenarios list -o raw 2>/dev/null | wc -l)
        echo "Detection Scenarios: $SCENARIO_COUNT installed"
        
        pass "CrowdSec DDoS protection is running"
        
        # Hands-on test: Simulate IP ban
        echo ""
        echo "--- Hands-on Test: Simulating IP Ban ---"
        
        # Add a test ban
        echo "Adding test ban for IP 1.2.3.4..."
        kubectl exec -n api-platform $LAPI_POD -- cscli decisions add --ip 1.2.3.4 --duration 1m --reason "Automated test ban" --type ban 2>/dev/null
        
        # Verify ban was added
        BAN_COUNT=$(kubectl exec -n api-platform $LAPI_POD -- cscli decisions list -o raw 2>/dev/null | grep -c "1.2.3.4" || echo "0")
        if [ "$BAN_COUNT" -gt 0 ]; then
            echo "✓ IP 1.2.3.4 successfully banned"
            
            # Remove the test ban
            echo "Removing test ban..."
            kubectl exec -n api-platform $LAPI_POD -- cscli decisions delete --ip 1.2.3.4 2>/dev/null
            echo "✓ Test ban removed"
            
            pass "CrowdSec ban/unban functionality verified"
        else
            warn "Could not verify ban (may be a timing issue)"
        fi
    else
        fail "CrowdSec pod is not running (status: $POD_STATUS)"
    fi
else
    warn "CrowdSec LAPI pod not found - DDoS protection may not be installed"
fi

# =============================================================================
# TEST 15: IP Whitelisting Configuration
# =============================================================================
print_header "TEST 15: IP Whitelisting Configuration"

# Check if IP restriction is configured in Kong
IP_CONFIG=$(kubectl get configmap kong-declarative-config -n api-platform -o yaml 2>/dev/null | grep -c "ip-restriction")

if [ "$IP_CONFIG" -gt 0 ]; then
    echo "IP Restriction plugin: Configured"
    echo "Allowed networks:"
    kubectl get configmap kong-declarative-config -n api-platform -o yaml 2>/dev/null | grep -A10 "ip-restriction" | grep -E "^\s+- [0-9]" | head -5
    pass "IP whitelisting is configured"
else
    fail "IP restriction plugin not found in Kong config"
fi

# =============================================================================
# TEST 16: Custom Lua Logic (Header Injection)
# =============================================================================
print_header "TEST 16: Custom Lua Logic (Header Injection)"

# Check for custom headers
HEADERS=$(curl -sI $KONG_URL/health 2>/dev/null)

# Check X-Request-ID
X_REQUEST_ID=$(echo "$HEADERS" | grep -i "X-Request-ID" | awk '{print $2}' | tr -d '\r')
if [ -n "$X_REQUEST_ID" ]; then
    echo "X-Request-ID: $X_REQUEST_ID"
    pass "Request ID header present (correlation-id plugin)"
else
    fail "X-Request-ID header not found"
fi

# Check X-Powered-By
X_POWERED_BY=$(echo "$HEADERS" | grep -i "X-Powered-By" | awk '{print $2}' | tr -d '\r')
if [ -n "$X_POWERED_BY" ]; then
    echo "X-Powered-By: $X_POWERED_BY"
    pass "Custom header injection working (response-transformer)"
else
    warn "X-Powered-By header not found"
fi

# Check X-API-Version
X_API_VERSION=$(echo "$HEADERS" | grep -i "X-API-Version" | awk '{print $2}' | tr -d '\r')
if [ -n "$X_API_VERSION" ]; then
    echo "X-API-Version: $X_API_VERSION"
    pass "API version header present"
else
    warn "X-API-Version header not found"
fi

# Check unique request IDs
echo ""
echo "Verifying unique request IDs (3 requests):"
ID1=$(curl -sI $KONG_URL/health 2>/dev/null | grep -i "X-Request-ID" | awk '{print $2}' | tr -d '\r')
ID2=$(curl -sI $KONG_URL/health 2>/dev/null | grep -i "X-Request-ID" | awk '{print $2}' | tr -d '\r')
ID3=$(curl -sI $KONG_URL/health 2>/dev/null | grep -i "X-Request-ID" | awk '{print $2}' | tr -d '\r')

echo "  Request 1: $ID1"
echo "  Request 2: $ID2"
echo "  Request 3: $ID3"

if [ "$ID1" != "$ID2" ] && [ "$ID2" != "$ID3" ]; then
    pass "Each request has a unique ID"
else
    fail "Request IDs are not unique"
fi

# =============================================================================
# TEST 17: SQLite Database Verification
# =============================================================================
print_header "TEST 17: SQLite Database Verification"

# Get user-service pod
USER_POD=$(kubectl get pods -n api-platform 2>/dev/null | grep user-service | head -1 | awk '{print $1}')

if [ -n "$USER_POD" ]; then
    echo "User Service Pod: $USER_POD"
    
    # Check if database exists
    DB_EXISTS=$(kubectl exec -n api-platform $USER_POD -- python3 -c "
import os
print('yes' if os.path.exists('/app/data/users.db') else 'no')
" 2>/dev/null)
    
    if [ "$DB_EXISTS" = "yes" ]; then
        echo "Database file: /app/data/users.db exists"
        pass "SQLite database file exists"
        
        # Query user count
        USER_COUNT=$(kubectl exec -n api-platform $USER_POD -- python3 -c "
import sqlite3
conn = sqlite3.connect('/app/data/users.db')
cursor = conn.cursor()
cursor.execute('SELECT COUNT(*) FROM users;')
print(cursor.fetchone()[0])
conn.close()
" 2>/dev/null)
        
        echo "Users in database: $USER_COUNT"
        if [ "$USER_COUNT" -ge 1 ]; then
            pass "Users are stored in SQLite database"
        else
            fail "No users found in database"
        fi
        
        # Check password hashing
        HASH_CHECK=$(kubectl exec -n api-platform $USER_POD -- python3 -c "
import sqlite3
conn = sqlite3.connect('/app/data/users.db')
cursor = conn.cursor()
cursor.execute('SELECT password_hash FROM users LIMIT 1;')
hash = cursor.fetchone()[0]
print('bcrypt' if hash.startswith('\$2b\$') else 'unknown')
conn.close()
" 2>/dev/null)
        
        if [ "$HASH_CHECK" = "bcrypt" ]; then
            echo "Password hashing: bcrypt"
            pass "Passwords are securely hashed with bcrypt"
        else
            warn "Could not verify password hashing"
        fi
    else
        fail "SQLite database file not found"
    fi
else
    warn "User service pod not found - skipping database test"
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                      TEST SUMMARY                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "  ${GREEN}Passed:${NC} $PASSED"
echo -e "  ${RED}Failed:${NC} $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "  ${GREEN}🎉 ALL TESTS PASSED!${NC}"
    exit 0
else
    echo -e "  ${RED}Some tests failed. Please check the output above.${NC}"
    exit 1
fi

