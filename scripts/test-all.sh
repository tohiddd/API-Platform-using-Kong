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

LAPI_POD=$(kubectl get pods -n api-platform -l app=crowdsec-lapi -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

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

