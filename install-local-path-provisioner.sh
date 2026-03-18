#!/bin/bash

# Local-Path Provisioner Installation & Setup Script
# Installs Rancher local-path provisioner and sets it as default storage class
# Perfect for lab environments without CSI drivers

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Local-Path Provisioner Installation & Setup       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Check Prerequisites
# ============================================================================
echo -e "${YELLOW}[1/4] Checking prerequisites...${NC}"
echo ""

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl found${NC}"

CLUSTER_NAME=$(kubectl config current-context)
echo -e "${GREEN}✓ Connected to cluster: $CLUSTER_NAME${NC}"
echo ""

# ============================================================================
# Check if local-path provisioner already exists
# ============================================================================
echo -e "${YELLOW}[2/4] Checking for existing local-path provisioner...${NC}"
echo ""

if kubectl get storageclass local-path &>/dev/null; then
    echo -e "${GREEN}✓ Local-path provisioner already exists${NC}"
    LOCAL_PATH_EXISTS=true
else
    echo -e "${YELLOW}⚠ Local-path provisioner not found. Installing...${NC}"
    LOCAL_PATH_EXISTS=false
fi

# ============================================================================
# Install Local-Path Provisioner if not exists
# ============================================================================
if [ "$LOCAL_PATH_EXISTS" = false ]; then
    echo -e "${YELLOW}[3/4] Installing Rancher Local-Path Provisioner...${NC}"
    echo ""
    
    echo "Applying local-path provisioner manifest..."
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
    
    echo ""
    echo -e "${YELLOW}Waiting for local-path-provisioner to be ready...${NC}"
    kubectl wait --for=condition=ready pod \
        -l app=local-path-provisioner \
        -n local-path-storage \
        --timeout=120s || true
    
    sleep 3
    
    echo -e "${GREEN}✓ Local-path provisioner installed${NC}"
    echo ""
else
    echo -e "${YELLOW}[3/4] Skipping installation (already exists)...${NC}"
    echo ""
fi

# ============================================================================
# Check current storage classes
# ============================================================================
echo -e "${YELLOW}[4/4] Setting local-path as default storage class...${NC}"
echo ""

echo "Current storage classes:"
kubectl get storageclass
echo ""

# ============================================================================
# Get current default storage class
# ============================================================================
CURRENT_DEFAULT=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null || echo "")

if [ -n "$CURRENT_DEFAULT" ]; then
    echo -e "${YELLOW}Current default: $CURRENT_DEFAULT${NC}"
    
    if [ "$CURRENT_DEFAULT" != "local-path" ]; then
        echo ""
        echo -e "${YELLOW}Removing default annotation from: $CURRENT_DEFAULT${NC}"
        kubectl patch storageclass "$CURRENT_DEFAULT" \
            -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
        echo -e "${GREEN}✓ Removed${NC}"
    fi
else
    echo -e "${YELLOW}No default storage class found${NC}"
fi

echo ""
echo -e "${YELLOW}Setting local-path as default storage class...${NC}"
kubectl patch storageclass local-path \
    -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo -e "${GREEN}✓ local-path set as default${NC}"
echo ""

# ============================================================================
# Verify installation
# ============================================================================
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Verification                                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Storage Classes:${NC}"
kubectl get storageclass
echo ""

echo -e "${YELLOW}Local-Path Provisioner Pods:${NC}"
kubectl get pods -n local-path-storage -o wide
echo ""

echo -e "${YELLOW}Local-Path Provisioner Status:${NC}"
kubectl describe storageclass local-path
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Installation Complete!                           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo -e "1. Install Prometheus & Grafana:"
echo -e "   ${GREEN}chmod +x install-helm-prometheus-grafana.sh${NC}"
echo -e "   ${GREEN}./install-helm-prometheus-grafana.sh${NC}"
echo ""
echo -e "2. The installation will automatically use local-path for storage"
echo ""
echo -e "3. Verify PVCs are bound:"
echo -e "   ${GREEN}kubectl get pvc -n monitoring${NC}"
echo ""
echo -e "4. Access monitoring stack:"
echo -e "   ${GREEN}kubectl port-forward -n monitoring svc/grafana 3000:80${NC}"
echo ""

echo -e "${YELLOW}📝 Local-Path Notes:${NC}"
echo -e "  • Data stored at: /var/lib/rancher/local-path-provisioner/"
echo -e "  • Works on any Kubernetes cluster"
echo -e "  • No CSI driver required"
echo -e "  • Suitable for lab, dev, and single-node clusters"
echo -e "  • Not recommended for production multi-node clusters"
echo ""

echo -e "${GREEN}✓ Ready to install Prometheus & Grafana!${NC}"
echo ""
