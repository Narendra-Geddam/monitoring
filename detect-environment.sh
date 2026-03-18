#!/bin/bash

# Environment Detection Script for Prometheus & Grafana Helm Installation
# Detects cluster type and configures appropriate storage class

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Kubernetes Environment Detection & Setup          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Detect Kubernetes Environment
# ============================================================================
echo -e "${YELLOW}Detecting Kubernetes environment...${NC}"
echo ""

CLUSTER_INFO=$(kubectl cluster-info)
NODES=$(kubectl get nodes -o jsonpath='{.items[*].spec.providerID}' 2>/dev/null || echo "")
STORAGE_CLASSES=$(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

# Detect cloud provider
if echo "$CLUSTER_INFO" | grep -q -i "eks"; then
    DETECTED_ENV="AWS EKS"
    CLOUD_PROVIDER="AWS"
elif echo "$CLUSTER_INFO" | grep -q -i "gke"; then
    DETECTED_ENV="Google GKE"
    CLOUD_PROVIDER="GCP"
elif echo "$CLUSTER_INFO" | grep -q -i "aks"; then
    DETECTED_ENV="Azure AKS"
    CLOUD_PROVIDER="Azure"
elif echo "$NODES" | grep -q "aws"; then
    DETECTED_ENV="AWS EKS"
    CLOUD_PROVIDER="AWS"
elif echo "$NODES" | grep -q "gce"; then
    DETECTED_ENV="Google GKE"
    CLOUD_PROVIDER="GCP"
elif echo "$NODES" | grep -q "azure"; then
    DETECTED_ENV="Azure AKS"
    CLOUD_PROVIDER="Azure"
else
    DETECTED_ENV="Local/On-Premises/Lab"
    CLOUD_PROVIDER="LOCAL"
fi

echo -e "${GREEN}✓ Detected Environment: $DETECTED_ENV${NC}"
echo ""

# ============================================================================
# Show Available Storage Classes
# ============================================================================
echo -e "${YELLOW}Available Storage Classes:${NC}"
if [ -z "$STORAGE_CLASSES" ]; then
    echo -e "${RED}✗ No storage classes found${NC}"
    echo ""
    STORAGE_CLASSES="none"
else
    echo -e "${GREEN}✓ Found: $STORAGE_CLASSES${NC}"
    kubectl get storageclass
    echo ""
fi

# ============================================================================
# Interactive Environment Selection
# ============================================================================
echo -e "${YELLOW}Select your environment:${NC}"
echo ""
echo "1) AWS EKS (uses EBS volumes)"
echo "2) Google GKE (uses GCP Persistent Disks)"
echo "3) Azure AKS (uses Azure Disks)"
echo "4) Lab/Local Kubernetes (no CSI driver)"
echo "5) Minikube/Docker Desktop"
echo ""
read -p "Enter choice [1-5] or press Enter for auto-detected ($DETECTED_ENV): " ENV_CHOICE

if [ -z "$ENV_CHOICE" ]; then
    case "$DETECTED_ENV" in
        "AWS EKS") ENV_CHOICE=1 ;;
        "Google GKE") ENV_CHOICE=2 ;;
        "Azure AKS") ENV_CHOICE=3 ;;
        "Local/On-Premises/Lab") ENV_CHOICE=4 ;;
        *) ENV_CHOICE=4 ;;
    esac
fi

echo ""
echo -e "${YELLOW}Storage Configuration Options:${NC}"
echo ""
echo "A) Persistent Volume (recommended for persistent data)"
echo "B) EmptyDir (data lost on pod restart - dev/test only)"
echo "C) No storage (metrics not persisted - testing only)"
echo ""
read -p "Enter choice [A/B/C], default is A: " STORAGE_CHOICE

if [ -z "$STORAGE_CHOICE" ]; then
    STORAGE_CHOICE="A"
fi

STORAGE_CHOICE=$(echo $STORAGE_CHOICE | tr '[:lower:]' '[:upper:]')

# ============================================================================
# Configure based on selections
# ============================================================================
echo ""
echo -e "${BLUE}Generating configuration...${NC}"
echo ""

case $ENV_CHOICE in
    1)
        echo -e "${GREEN}✓ Configuring for AWS EKS${NC}"
        STORAGE_CLASS="gp3"  # or "gp2", "io1", "io2"
        STORAGE_SIZE="50Gi"
        STORAGE_TYPE="EBS"
        ;;
    2)
        echo -e "${GREEN}✓ Configuring for Google GKE${NC}"
        STORAGE_CLASS="standard"  # or "premium-rwo", "balanced-rwo"
        STORAGE_SIZE="50Gi"
        STORAGE_TYPE="GCE_PD"
        ;;
    3)
        echo -e "${GREEN}✓ Configuring for Azure AKS${NC}"
        STORAGE_CLASS="managed-premium"  # or "managed", "managed-csi"
        STORAGE_SIZE="50Gi"
        STORAGE_TYPE="AZURE_DISK"
        ;;
    4)
        echo -e "${GREEN}✓ Configuring for Lab/Local Kubernetes${NC}"
        
        # Check for local-path provisioner
        if kubectl get storageclass local-path &>/dev/null; then
            STORAGE_CLASS="local-path"
            echo -e "${GREEN}✓ Found local-path provisioner${NC}"
        elif kubectl get storageclass hostpath &>/dev/null; then
            STORAGE_CLASS="hostpath"
            echo -e "${GREEN}✓ Found hostpath provisioner${NC}"
        else
            echo -e "${YELLOW}⚠ No local provisioner found. Installing local-path provisioner...${NC}"
            kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
            sleep 5
            STORAGE_CLASS="local-path"
        fi
        
        STORAGE_SIZE="20Gi"
        STORAGE_TYPE="LOCAL_PATH"
        ;;
    5)
        echo -e "${GREEN}✓ Configuring for Minikube/Docker Desktop${NC}"
        STORAGE_CLASS="standard"
        STORAGE_SIZE="10Gi"
        STORAGE_TYPE="DOCKER_LOCAL"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# ============================================================================
# Generate values file based on storage choice
# ============================================================================
VALUES_FILE="helm-values-${STORAGE_TYPE,,}.yaml"

echo ""
echo -e "${YELLOW}Generating values file: $VALUES_FILE${NC}"

case $STORAGE_CHOICE in
    A)
        echo -e "${GREEN}✓ Using Persistent Volumes${NC}"
        
        cat > "$VALUES_FILE" <<EOF
# Helm values for $STORAGE_TYPE
# Storage: Persistent Volume

prometheus:
  enabled: true
  prometheusSpec:
    retention: 7d
    retentionSize: "50Gi"
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 1000m
        memory: 4Gi
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: "$STORAGE_CLASS"
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: $STORAGE_SIZE
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false

grafana:
  enabled: true
  adminPassword: admin123
  persistence:
    enabled: true
    storageClassName: "$STORAGE_CLASS"
    size: 10Gi
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

alertmanager:
  enabled: true
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: "$STORAGE_CLASS"
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 5Gi

nodeExporter:
  enabled: true

kubeStateMetrics:
  enabled: true

prometheusOperator:
  enabled: true
  manageCrds: true

defaultRules:
  create: true
EOF
        ;;
    
    B)
        echo -e "${GREEN}✓ Using EmptyDir (data not persisted)${NC}"
        
        cat > "$VALUES_FILE" <<EOF
# Helm values for $STORAGE_TYPE
# Storage: EmptyDir - WARNING: Data lost on pod restart!

prometheus:
  enabled: true
  prometheusSpec:
    retention: 2d
    resources:
      requests:
        cpu: 250m
        memory: 1Gi
      limits:
        cpu: 500m
        memory: 2Gi
    emptyDir:
      sizeLimit: 20Gi
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false

grafana:
  enabled: true
  adminPassword: admin123
  persistence:
    enabled: false
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 250m
      memory: 256Mi

alertmanager:
  enabled: true
  alertmanagerSpec:
    storage:
      emptyDir:
        sizeLimit: 5Gi

nodeExporter:
  enabled: true

kubeStateMetrics:
  enabled: true

prometheusOperator:
  enabled: true
  manageCrds: true

defaultRules:
  create: true
EOF
        ;;
    
    C)
        echo -e "${GREEN}✓ Using no storage (metrics not persisted)${NC}"
        
        cat > "$VALUES_FILE" <<EOF
# Helm values for $STORAGE_TYPE
# Storage: NONE - WARNING: Data lost immediately!

prometheus:
  enabled: true
  prometheusSpec:
    retention: 1d
    resources:
      requests:
        cpu: 100m
        memory: 512Mi
      limits:
        cpu: 250m
        memory: 1Gi
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false

grafana:
  enabled: true
  adminPassword: admin123
  persistence:
    enabled: false
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 250m
      memory: 256Mi

alertmanager:
  enabled: false

nodeExporter:
  enabled: true

kubeStateMetrics:
  enabled: true

prometheusOperator:
  enabled: true
  manageCrds: true

defaultRules:
  create: false
EOF
        ;;
    
    *)
        echo -e "${RED}Invalid storage choice${NC}"
        exit 1
        ;;
esac

# ============================================================================
# Display configuration summary
# ============================================================================
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Configuration Summary                             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Environment:${NC}"
echo -e "  Type: $DETECTED_ENV"
echo -e "  Storage Class: ${STORAGE_CLASS:-N/A}"
echo -e "  Storage Type: $STORAGE_TYPE"
echo ""
echo -e "${YELLOW}Storage Configuration:${NC}"
case $STORAGE_CHOICE in
    A) echo -e "  Mode: Persistent Volume (data persisted)" ;;
    B) echo -e "  Mode: EmptyDir (data lost on restart)" ;;
    C) echo -e "  Mode: None (no persistence)" ;;
esac
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Review values file: ${GREEN}cat $VALUES_FILE${NC}"
echo -e "  2. Start installation: ${GREEN}./install-helm-prometheus-grafana.sh $VALUES_FILE${NC}"
echo ""
echo -e "${GREEN}✓ Configuration file created: $VALUES_FILE${NC}"
echo ""

# ============================================================================
# Auto-start installation
# ============================================================================
echo -e "${YELLOW}🚀 Ready to install Prometheus & Grafana?${NC}"
read -p "Start installation now? (y/n) [default: y]: " -r AUTO_INSTALL
AUTO_INSTALL=${AUTO_INSTALL:-y}

if [[ "$AUTO_INSTALL" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}Starting Helm installation...${NC}"
    echo ""
    
    if [ ! -f "install-helm-prometheus-grafana.sh" ]; then
        echo -e "${RED}✗ install-helm-prometheus-grafana.sh not found${NC}"
        echo -e "${YELLOW}Make sure you're in the project directory${NC}"
        exit 1
    fi
    
    chmod +x install-helm-prometheus-grafana.sh
    ./install-helm-prometheus-grafana.sh "$VALUES_FILE"
else
    echo ""
    echo -e "${YELLOW}Installation skipped. To proceed manually, run:${NC}"
    echo -e "  ${GREEN}./install-helm-prometheus-grafana.sh $VALUES_FILE${NC}"
    echo ""
fi
