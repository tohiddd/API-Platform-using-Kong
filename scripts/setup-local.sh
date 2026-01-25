#!/bin/bash
# =============================================================================
# Local Development Setup Script
# =============================================================================
#
# This script sets up the API Platform on a local Kubernetes cluster.
#
# Prerequisites:
#   - Docker
#   - kubectl
#   - Helm 3
#   - Minikube or Kind
#
# Usage:
#   ./scripts/setup-local.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}   API Platform Local Setup${NC}"
echo -e "${BLUE}=============================================${NC}\n"

# Check prerequisites
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        exit 1
    else
        echo -e "${GREEN}✓${NC} $1 is installed"
    fi
}

echo -e "${YELLOW}Checking prerequisites...${NC}"
check_command docker
check_command kubectl
check_command helm
echo ""

# Check if cluster is running
echo -e "${YELLOW}Checking Kubernetes cluster...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}No Kubernetes cluster found. Starting Minikube...${NC}"
    
    if command -v minikube &> /dev/null; then
        minikube start --memory=4096 --cpus=2
    else
        echo -e "${RED}Please start a Kubernetes cluster (Minikube, Kind, or Docker Desktop)${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} Kubernetes cluster is running"
fi
echo ""

# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"

# Use Minikube's Docker daemon if available
if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    echo "Using Minikube's Docker daemon"
    eval $(minikube docker-env)
fi

docker build -t user-service:latest ./microservice
echo -e "${GREEN}✓${NC} Docker image built"
echo ""

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace api-platform --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓${NC} Namespace created"
echo ""

# Add Helm repos
echo -e "${YELLOW}Adding Helm repositories...${NC}"
helm repo add kong https://charts.konghq.com
helm repo update
echo -e "${GREEN}✓${NC} Helm repos updated"
echo ""

# Install User Service
echo -e "${YELLOW}Installing User Service...${NC}"
helm upgrade --install user-service ./helm/user-service \
    -n api-platform \
    --set image.pullPolicy=IfNotPresent \
    --set persistence.enabled=false \
    --wait
echo -e "${GREEN}✓${NC} User Service installed"
echo ""

# Install Kong
echo -e "${YELLOW}Installing Kong Gateway...${NC}"
helm upgrade --install kong kong/kong \
    -n api-platform \
    --set env.database=off \
    --set proxy.type=NodePort \
    --set admin.enabled=true \
    --set admin.type=ClusterIP \
    --set ingressController.enabled=false \
    --wait
echo -e "${GREEN}✓${NC} Kong Gateway installed"
echo ""

# Wait for pods
echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=user-service -n api-platform --timeout=120s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong -n api-platform --timeout=120s
echo -e "${GREEN}✓${NC} All pods are ready"
echo ""

# Get Kong URL
echo -e "${YELLOW}Getting Kong URL...${NC}"
if command -v minikube &> /dev/null; then
    KONG_URL=$(minikube service kong-kong-proxy -n api-platform --url 2>/dev/null | head -1)
else
    KONG_PORT=$(kubectl get svc kong-kong-proxy -n api-platform -o jsonpath='{.spec.ports[0].nodePort}')
    KONG_URL="http://localhost:$KONG_PORT"
fi
echo ""

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}   Setup Complete!${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""
echo -e "Kong Gateway URL: ${GREEN}$KONG_URL${NC}"
echo ""
echo -e "Test commands:"
echo -e "  ${YELLOW}curl $KONG_URL/health${NC}"
echo -e "  ${YELLOW}curl -X POST $KONG_URL/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin123\"}'${NC}"
echo ""
echo -e "Run full test suite:"
echo -e "  ${YELLOW}./scripts/test-api.sh $KONG_URL${NC}"
echo ""
echo -e "View pods:"
echo -e "  ${YELLOW}kubectl get pods -n api-platform${NC}"
echo ""

