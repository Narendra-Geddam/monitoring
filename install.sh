#!/bin/bash

# Prometheus & Grafana - Complete Installation Script
# Intelligently detects environment, installs local-path provisioner if needed,
# and deploys kube-prometheus-stack with appropriate configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Configuration
# ============================================================================
NAMESPACE="monitoring"
RELEASE_NAME="prometheus"
CHART_NAME="prometheus-community/kube-prometheus-stack"
CHART_VERSION="55.0.0"
VALUES_FILE="${1}"  # Accept values file as argument

# ============================================================================
# Helper Functions
# ============================================================================
show_banner() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Prometheus & Grafana - Kubernetes Installation   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_section() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}✗ $1 not found. Please install $1.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ $1 found${NC}"
}

# ============================================================================
# Main Installation
# ============================================================================

show_banner

# Step 1: Check Prerequisites
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"
check_command "kubectl"
check_command "helm"
CLUSTER_NAME=$(kubectl config current-context)
echo -e "${GREEN}✓ Connected to cluster: $CLUSTER_NAME${NC}"
echo ""

# Step 2: Detect Environment & Configure Storage
echo -e "${YELLOW}[2/6] Detecting Kubernetes environment...${NC}"

CLUSTER_INFO=$(kubectl cluster-info)
NODES=$(kubectl get nodes -o jsonpath='{.items[*].spec.providerID}' 2>/dev/null || echo "")
STORAGE_CLASSES=$(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

# Auto-detect environment
if echo "$CLUSTER_INFO" | grep -q -i "eks"; then
    DETECTED_ENV="AWS EKS"
elif echo "$CLUSTER_INFO" | grep -q -i "gke"; then
    DETECTED_ENV="Google GKE"
elif echo "$CLUSTER_INFO" | grep -q -i "aks"; then
    DETECTED_ENV="Azure AKS"
elif echo "$NODES" | grep -q "aws"; then
    DETECTED_ENV="AWS EKS"
elif echo "$NODES" | grep -q "gce"; then
    DETECTED_ENV="Google GKE"
elif echo "$NODES" | grep -q "azure"; then
    DETECTED_ENV="Azure AKS"
else
    DETECTED_ENV="Lab/On-Premises"
fi

echo -e "${GREEN}✓ Detected: $DETECTED_ENV${NC}"
echo ""

# Step 3: Handle Local-Path for Lab Environments
if [ "$DETECTED_ENV" = "Lab/On-Premises" ]; then
    echo -e "${YELLOW}[3/6] Setting up storage for lab environment...${NC}"
    
    if ! kubectl get storageclass local-path &>/dev/null; then
        echo -e "${YELLOW}⚠  local-path provisioner not found. Installing...${NC}"
        
        kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
        
        echo -e "${YELLOW}Waiting for local-path-provisioner to be ready...${NC}"
        kubectl wait --for=condition=ready pod \
            -l app=local-path-provisioner \
            -n local-path-storage \
            --timeout=120s || true
        
        sleep 2
        
        # Set as default
        kubectl patch storageclass local-path \
            -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
        
        echo -e "${GREEN}✓ local-path provisioner installed and set as default${NC}"
    else
        echo -e "${GREEN}✓ local-path provisioner already available${NC}"
    fi
fi
echo ""

# Step 4: Determine Values File
echo -e "${YELLOW}[4/6] Configuring Helm values...${NC}"

if [ -z "$VALUES_FILE" ]; then
    # Auto-select values file based on environment
    case "$DETECTED_ENV" in
        "AWS EKS"*)
            VALUES_FILE="helm-values.yaml"
            echo -e "${GREEN}✓ Using production config (EKS)${NC}"
            ;;
        "Google GKE"*)
            VALUES_FILE="helm-values.yaml"
            echo -e "${GREEN}✓ Using production config (GKE)${NC}"
            ;;
        "Azure AKS"*)
            VALUES_FILE="helm-values.yaml"
            echo -e "${GREEN}✓ Using production config (AKS)${NC}"
            ;;
        "Lab/On-Premises")
            VALUES_FILE="helm-values-lab.yaml"
            echo -e "${GREEN}✓ Using lab config (local-path)${NC}"
            ;;
        *)
            VALUES_FILE="helm-values.yaml"
            echo -e "${GREEN}✓ Using default config${NC}"
            ;;
    esac
elif [ ! -f "$VALUES_FILE" ]; then
    echo -e "${RED}✗ Values file not found: $VALUES_FILE${NC}"
    echo -e "${YELLOW}Available files:${NC}"
    ls -1 helm-values*.yaml 2>/dev/null || echo "None found"
    exit 1
fi

echo -e "${YELLOW}Using: $VALUES_FILE${NC}"
echo ""

# Step 5: Add Helm Repositories & Install
echo -e "${YELLOW}[5/6] Installing Helm chart...${NC}"

echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts &>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts &>/dev/null || true
helm repo update &>/dev/null

echo "Creating monitoring namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
kubectl label namespace $NAMESPACE name=monitoring --overwrite=true &>/dev/null

# Install or upgrade
if helm list -n $NAMESPACE 2>/dev/null | grep -q $RELEASE_NAME; then
    echo "Upgrading release: $RELEASE_NAME"
    helm upgrade $RELEASE_NAME $CHART_NAME \
        --namespace $NAMESPACE \
        --values $VALUES_FILE \
        --wait \
        --timeout 5m
else
    echo "Installing release: $RELEASE_NAME"
    helm install $RELEASE_NAME $CHART_NAME \
        --namespace $NAMESPACE \
        --values $VALUES_FILE \
        --wait \
        --timeout 5m
fi

echo -e "${GREEN}✓ Helm installation complete${NC}"
echo ""

# Step 6: Wait & Verify
echo -e "${YELLOW}[6/6] Verifying deployment...${NC}"

echo "Waiting for pods to be ready..."
kubectl rollout status statefulset/prometheus-kube-prom-prometheus -n $NAMESPACE --timeout=5m || true
kubectl rollout status deployment/grafana -n $NAMESPACE --timeout=5m || true

echo ""
show_section "Installation Complete"

echo -e "${BLUE}📊 Helm Release:${NC}"
helm status $RELEASE_NAME -n $NAMESPACE | head -20
echo ""

echo -e "${BLUE}📦 Pods:${NC}"
kubectl get pods -n $NAMESPACE
echo ""

echo -e "${BLUE}💾 PVC Status:${NC}"
kubectl get pvc -n $NAMESPACE || echo "No PVCs found"
echo ""

echo ""
show_section "Access Services"

# Check if lab environment (NodePort configured)
if [ "$VALUES_FILE" = "helm-values-lab.yaml" ]; then
    echo -e "${GREEN}🚀 Lab Environment - NodePort Access (No Port-Forward Needed!)${NC}"
    echo ""
    
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
    if [ -z "$NODE_IP" ]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    fi
    
    echo -e "${YELLOW}Node IP: ${GREEN}$NODE_IP${NC}"
    echo ""
    
    echo -e "${YELLOW}Prometheus:${NC}"
    echo -e "  URL: ${GREEN}http://$NODE_IP:30090${NC}"
    echo ""
    
    echo -e "${YELLOW}Grafana:${NC}"
    echo -e "  URL: ${GREEN}http://$NODE_IP:30300${NC}"
    echo -e "  Username: ${GREEN}admin${NC}"
    echo -e "  Password: ${GREEN}admin123${NC}"
    echo ""
    
    echo -e "${YELLOW}AlertManager:${NC}"
    echo -e "  URL: ${GREEN}http://$NODE_IP:30093${NC}"
    echo ""
else
    echo -e "${GREEN}🌐 Port-Forwarding Method:${NC}"
    echo ""
    echo -e "${YELLOW}Prometheus:${NC}"
    echo -e "  ${GREEN}kubectl port-forward -n $NAMESPACE svc/prometheus-operated 9090:9090${NC}"
    echo -e "  URL: ${GREEN}http://localhost:9090${NC}"
    echo ""
    
    echo -e "${YELLOW}Grafana:${NC}"
    echo -e "  ${GREEN}kubectl port-forward -n $NAMESPACE svc/grafana 3000:80${NC}"
    echo -e "  URL: ${GREEN}http://localhost:3000${NC}"
    echo -e "  Username: ${GREEN}admin${NC}"
    echo -e "  Password: ${GREEN}admin123${NC}"
    echo ""
    
    echo -e "${YELLOW}AlertManager:${NC}"
    echo -e "  ${GREEN}kubectl port-forward -n $NAMESPACE svc/alertmanager-operated 9093:9093${NC}"
    echo -e "  URL: ${GREEN}http://localhost:9093${NC}"
    echo ""
fi

echo -e "${YELLOW}📚 Useful Commands:${NC}"
echo -e "  Status:           ${GREEN}./helm-manage.sh status${NC}"
echo -e "  View pods:        ${GREEN}./helm-manage.sh pods${NC}"
echo -e "  View logs:        ${GREEN}./helm-manage.sh logs <pod-name>${NC}"
echo -e "  Update password:  ${GREEN}./helm-manage.sh update-password mypassword${NC}"
echo -e "  Help:             ${GREEN}./helm-manage.sh help${NC}"
echo ""

echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
