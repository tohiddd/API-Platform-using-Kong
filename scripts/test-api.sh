#!/bin/bash
# =============================================================================
# API Platform Test Script
# =============================================================================
#
# Usage: ./scripts/test-api.sh [KONG_URL]
#
# Example:
#   ./scripts/test-api.sh http://localhost:8000
#   ./scripts/test-api.sh $(minikube service kong-kong-proxy -n api-platform --url)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KONG_URL=${1:-"http://localhost:8000"}

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}   API Platform Test Suite${NC}"
echo -e "${BLUE}=============================================${NC}"
echo -e "Kong URL: ${YELLOW}$KONG_URL${NC}\n"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function
test_endpoint() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local expected_status="$4"
    local data="$5"
    local headers="$6"
    
    echo -e "${BLUE}Testing: ${NC}$name"
    
    if [ "$method" == "POST" ]; then
        response=$(curl -s -w "\n%{http_code}" -X POST "$KONG_URL$endpoint" \
            -H "Content-Type: application/json" \
            ${headers:+-H "$headers"} \
            -d "$data")
    else
        response=$(curl -s -w "\n%{http_code}" "$KONG_URL$endpoint" \
            ${headers:+-H "$headers"})
    fi
    
    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$status_code" == "$expected_status" ]; then
        echo -e "  ${GREEN}✓ PASSED${NC} (Status: $status_code)"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}✗ FAILED${NC} (Expected: $expected_status, Got: $status_code)"
        echo -e "  Response: $body"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# =============================================================================
# Public Endpoint Tests
# =============================================================================
echo -e "${YELLOW}=== Public Endpoints ===${NC}\n"

# Health Check
test_endpoint "Health Check" "GET" "/health" "200"

# Root Endpoint
test_endpoint "Root Endpoint" "GET" "/" "200"

# Verify without token (should return 400)
test_endpoint "Verify (no token)" "GET" "/verify" "400"

# =============================================================================
# Authentication Tests
# =============================================================================
echo -e "${YELLOW}=== Authentication ===${NC}\n"

# Valid Login
echo -e "${BLUE}Testing: ${NC}Valid Login"
login_response=$(curl -s -X POST "$KONG_URL/login" \
    -H "Content-Type: application/json" \
    -d '{"username": "admin", "password": "admin123"}')
TOKEN=$(echo "$login_response" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
    echo -e "  ${GREEN}✓ PASSED${NC} (Token received)"
    echo -e "  Token: ${TOKEN:0:50}..."
    ((TESTS_PASSED++))
else
    echo -e "  ${RED}✗ FAILED${NC} (No token received)"
    echo -e "  Response: $login_response"
    ((TESTS_FAILED++))
fi
echo ""

# Invalid Login
test_endpoint "Invalid Login" "POST" "/login" "401" \
    '{"username": "admin", "password": "wrongpassword"}'

# Missing Credentials
test_endpoint "Missing Credentials" "POST" "/login" "400" \
    '{}'

# =============================================================================
# Token Verification
# =============================================================================
echo -e "${YELLOW}=== Token Verification ===${NC}\n"

if [ -n "$TOKEN" ]; then
    # Valid Token Verification
    test_endpoint "Verify Valid Token" "GET" "/verify?token=$TOKEN" "200"
fi

# Invalid Token Verification
test_endpoint "Verify Invalid Token" "GET" "/verify?token=invalid.token.here" "401"

# =============================================================================
# Protected Endpoints
# =============================================================================
echo -e "${YELLOW}=== Protected Endpoints ===${NC}\n"

# Get Users without token
test_endpoint "Get Users (no auth)" "GET" "/users" "401"

# Get Users with valid token
if [ -n "$TOKEN" ]; then
    test_endpoint "Get Users (authenticated)" "GET" "/users" "200" "" "Authorization: Bearer $TOKEN"
fi

# Get Users with invalid token
test_endpoint "Get Users (invalid token)" "GET" "/users" "401" "" "Authorization: Bearer invalid.token.here"

# =============================================================================
# Rate Limiting Test
# =============================================================================
echo -e "${YELLOW}=== Rate Limiting ===${NC}\n"

echo -e "${BLUE}Testing: ${NC}Rate Limiting (sending 15 rapid requests)"
rate_limited=false
for i in {1..15}; do
    status=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_URL/health")
    if [ "$status" == "429" ]; then
        rate_limited=true
        echo -e "  Request $i: ${YELLOW}$status (Rate Limited)${NC}"
    else
        echo -e "  Request $i: $status"
    fi
done

if [ "$rate_limited" = true ]; then
    echo -e "\n  ${GREEN}✓ Rate limiting is working${NC}"
    ((TESTS_PASSED++))
else
    echo -e "\n  ${YELLOW}⚠ Rate limiting may not be configured (no 429 responses)${NC}"
fi
echo ""

# =============================================================================
# Custom Headers Test
# =============================================================================
echo -e "${YELLOW}=== Custom Headers ===${NC}\n"

echo -e "${BLUE}Testing: ${NC}Response Headers"
headers=$(curl -s -I "$KONG_URL/health" 2>/dev/null)

check_header() {
    local header_name="$1"
    if echo "$headers" | grep -qi "$header_name"; then
        echo -e "  ${GREEN}✓${NC} $header_name present"
    else
        echo -e "  ${YELLOW}⚠${NC} $header_name not found"
    fi
}

check_header "X-Request-ID"
check_header "X-Response-Time"
check_header "X-RateLimit"
echo ""

# =============================================================================
# Summary
# =============================================================================
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}   Test Summary${NC}"
echo -e "${BLUE}=============================================${NC}"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${BLUE}=============================================${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed.${NC}"
    exit 1
fi

