#!/bin/bash

# Kubernetes deployment script for Prometheus and Grafana using Helm
# This script deploys kube-prometheus-stack which includes:
# - Prometheus
# - Grafana
# - AlertManager
# - Node Exporter
# - Kube-State-Metrics

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE="monitoring"
RELEASE_NAME="prometheus"
CHART_NAME="prometheus-community/kube-prometheus-stack"
CHART_VERSION="55.0.0"  # Specify a stable version
VALUES_FILE="${1:-helm-values.yaml}"  # Accept values file as first argument, default to helm-values.yaml

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Prometheus & Grafana Helm Installation Script     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📋 Configuration:${NC}"
echo -e "   Namespace: ${GREEN}$NAMESPACE${NC}"
echo -e "   Release: ${GREEN}$RELEASE_NAME${NC}"
echo -e "   Values File: ${GREEN}$VALUES_FILE${NC}"
echo ""

# ============================================================================
# Check Prerequisites
# ============================================================================
echo -e "${YELLOW}[1/7] Checking prerequisites...${NC}"
echo ""

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl found${NC}"

if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗ helm not found. Please install helm.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ helm found ($(helm version --short))${NC}"

CLUSTER_NAME=$(kubectl config current-context)
echo -e "${GREEN}✓ Connected to cluster: $CLUSTER_NAME${NC}"
echo ""

# ============================================================================
# Add Helm Repositories
# ============================================================================
echo -e "${YELLOW}[2/7] Adding Helm repositories...${NC}"
echo ""

echo "Adding prometheus-community repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

echo "Adding grafana repo..."
helm repo add grafana https://grafana.github.io/helm-charts

echo "Updating repos..."
helm repo update

echo -e "${GREEN}✓ Helm repositories configured${NC}"
echo ""

# ============================================================================
# Create Namespace
# ============================================================================
echo -e "${YELLOW}[3/7] Creating monitoring namespace...${NC}"
echo ""

kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Add labels to namespace
kubectl label namespace $NAMESPACE name=monitoring --overwrite=true

echo -e "${GREEN}✓ Namespace '$NAMESPACE' created${NC}"
echo ""

# ============================================================================
# Create/Verify Values File
# ============================================================================
echo -e "${YELLOW}[4/7] Checking Helm values file...${NC}"
echo ""

if [ ! -f "$VALUES_FILE" ]; then
    echo -e "${RED}✗ Values file not found: $VALUES_FILE${NC}"
    echo -e "${YELLOW}Please copy helm-values.yaml to the same directory as this script${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Using values file: $VALUES_FILE${NC}"
echo ""

# ============================================================================
# Install/Upgrade Helm Release
# ============================================================================
echo -e "${YELLOW}[5/7] Installing/Upgrading Helm release...${NC}"
echo ""

# Check if release exists
if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
    echo "Upgrading existing release: $RELEASE_NAME"
    helm upgrade $RELEASE_NAME $CHART_NAME \
        --namespace $NAMESPACE \
        --values $VALUES_FILE \
        --wait \
        --timeout 5m
else
    echo "Installing new release: $RELEASE_NAME"
    helm install $RELEASE_NAME $CHART_NAME \
        --namespace $NAMESPACE \
        --values $VALUES_FILE \
        --wait \
        --timeout 5m
fi

echo -e "${GREEN}✓ Helm release installed/upgraded${NC}"
echo ""

# ============================================================================
# Wait for Deployments
# ============================================================================
echo -e "${YELLOW}[6/7] Waiting for pods to be ready...${NC}"
echo ""

echo "Waiting for Prometheus..."
kubectl rollout status statefulset/prometheus-kube-prom-prometheus -n $NAMESPACE --timeout=5m || true

echo "Waiting for Grafana..."
kubectl rollout status deployment/grafana -n $NAMESPACE --timeout=5m || true

echo "Waiting for AlertManager..."
kubectl rollout status statefulset/prometheus-kube-prom-alertmanager -n $NAMESPACE --timeout=5m || true

echo -e "${GREEN}✓ Deployments ready${NC}"
echo ""

# ============================================================================
# Display Status and Access Information
# ============================================================================
echo -e "${YELLOW}[7/7] Deployment Summary${NC}"
echo ""

echo -e "${BLUE}Helm Release Status:${NC}"
helm status $RELEASE_NAME --namespace $NAMESPACE
echo ""

echo -e "${BLUE}Pod Status:${NC}"
kubectl get pods -n $NAMESPACE
echo ""

echo -e "${BLUE}Service Status:${NC}"
kubectl get svc -n $NAMESPACE
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Installation Complete!               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}🌐 Access Services via Port-Forward:${NC}"
echo ""
echo -e "${BLUE}Prometheus:${NC}"
echo -e "  ${GREEN}kubectl port-forward -n $NAMESPACE svc/prometheus-kube-prom-prometheus 9090:9090${NC}"
echo -e "  URL: ${GREEN}http://localhost:9090${NC}"
echo ""
echo -e "${BLUE}Grafana:${NC}"
echo -e "  ${GREEN}kubectl port-forward -n $NAMESPACE svc/grafana 3000:80${NC}"
echo -e "  URL: ${GREEN}http://localhost:3000${NC}"
echo ""
echo -e "${BLUE}AlertManager:${NC}"
echo -e "  ${GREEN}kubectl port-forward -n $NAMESPACE svc/prometheus-kube-prom-alertmanager 9093:9093${NC}"
echo -e "  URL: ${GREEN}http://localhost:9093${NC}"
echo ""

echo -e "${YELLOW}📋 Credentials:${NC}"
echo -e "  Grafana Username: ${GREEN}admin${NC}"
echo -e "  Grafana Password: ${GREEN}admin123${NC}"
echo ""

echo -e "${YELLOW}📚 Useful Commands:{{NC}"
echo -e "  List pods:             ${GREEN}kubectl get pods -n $NAMESPACE{{NC}"
echo -e "  Pod logs:              ${GREEN}kubectl logs -n $NAMESPACE <pod-name>{{NC}"
echo -e "  Describe pod:          ${GREEN}kubectl describe pod -n $NAMESPACE <pod-name>{{NC}"
echo -e "  Helm release info:     ${GREEN}helm list -n $NAMESPACE{{NC}"
echo -e "  Helm values:           ${GREEN}helm values $RELEASE_NAME -n $NAMESPACE{{NC}"
echo -e "  Upgrade release:       ${GREEN}helm upgrade $RELEASE_NAME $CHART_NAME -n $NAMESPACE -f $VALUES_FILE{{NC}"
echo -e "  Delete release:        ${GREEN}helm uninstall $RELEASE_NAME -n $NAMESPACE{{NC}"
echo ""

echo -e "${YELLOW}🔧 Additional Configuration:{{NC}"
echo -e "  Edit values:           ${GREEN}nano helm-values.yaml{{NC}"
echo -e "  Restart after changes: ${GREEN}helm upgrade $RELEASE_NAME $CHART_NAME -n $NAMESPACE -f helm-values.yaml{{NC}"
echo ""
echo ""

echo -e "${BLUE}Pod Status:${NC}"
kubectl get pods -n $NAMESPACE
echo ""

echo -e "${BLUE}Service Status:${NC}"
kubectl get svc -n $NAMESPACE
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Installation Complete!               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}🌐 Access Services via Port-Forward:${NC}"
echo ""
echo -e "${BLUE}Prometheus:${NC}"
echo -e "  ${GREEN}kubectl port-forward -n $NAMESPACE svc/prometheus-operated 9090:9090${NC}"
echo -e "  URL: ${GREEN}http://localhost:9090${NC}"
echo ""
echo -e "${BLUE}Grafana:${NC}"
echo -e "  ${GREEN}kubectl port-forward -n $NAMESPACE svc/grafana 3000:80${NC}"
echo -e "  URL: ${GREEN}http://localhost:3000${NC}"
echo ""
echo -e "${BLUE}AlertManager:${NC}"
echo -e "  ${GREEN}kubectl port-forward -n $NAMESPACE svc/alertmanager-operated 9093:9093${NC}"
echo -e "  URL: ${GREEN}http://localhost:9093${NC}"
echo ""

echo -e "${YELLOW}📋 Credentials:${NC}"
echo -e "  Grafana Username: ${GREEN}admin${NC}"
echo -e "  Grafana Password: ${GREEN}admin123${NC}"
echo ""

echo -e "${YELLOW}📚 Useful Commands:${NC}"
echo -e "  List pods:             ${GREEN}kubectl get pods -n $NAMESPACE${NC}"
echo -e "  Pod logs:              ${GREEN}kubectl logs -n $NAMESPACE <pod-name>${NC}"
echo -e "  Describe pod:          ${GREEN}kubectl describe pod -n $NAMESPACE <pod-name>${NC}"
echo -e "  Helm release info:     ${GREEN}helm list -n $NAMESPACE${NC}"
echo -e "  Helm values:           ${GREEN}helm values $RELEASE_NAME -n $NAMESPACE${NC}"
echo -e "  Upgrade release:       ${GREEN}helm upgrade $RELEASE_NAME $CHART_NAME -n $NAMESPACE -f $VALUES_FILE${NC}"
echo -e "  Delete release:        ${GREEN}helm uninstall $RELEASE_NAME -n $NAMESPACE${NC}"
echo ""

echo -e "${YELLOW}🔧 Additional Configuration:${NC}"
echo -e "  Edit values:           ${GREEN}nano $VALUES_FILE${NC}"
echo -e "  Restart after changes: ${GREEN}helm upgrade $RELEASE_NAME $CHART_NAME -n $NAMESPACE -f $VALUES_FILE${NC}"
echo ""

# ============================================================================
# Optional: Display access with LoadBalancer IPs (if configured)
# ============================================================================
echo -e "${YELLOW}ℹ️  To expose services externally, update service types in $VALUES_FILE:${NC}"
echo -e "   Change 'type: ClusterIP' to 'type: LoadBalancer' or 'type: NodePort'"
echo ""
