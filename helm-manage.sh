#!/bin/bash

# Helm Management Script - Common operations for Prometheus/Grafana stack
# Provides simple commands for daily management tasks

set -e

NAMESPACE="monitoring"
RELEASE_NAME="prometheus"
CHART_NAME="prometheus-community/kube-prometheus-stack"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Help Menu
# ============================================================================
show_help() {
    cat << EOF
${BLUE}Prometheus & Grafana Helm Management${NC}

Usage: ./helm-manage.sh <command> [options]

${GREEN}Commands:${NC}
  status              - Show release status
  pods                - List all monitoring pods
  logs <pod>          - Show logs for a pod (partial match)
  port-forward        - Show port-forward commands
  scale <replicas>    - Scale prometheus/grafana
  update-password     - Update Grafana admin password
  backup              - Backup current values
  restart             - Restart all pods
  describe            - Describe all resources
  helm-values         - Show current Helm values
  uninstall           - Remove the Helm release
  help                - Show this help menu

${GREEN}Examples:${NC}
  ./helm-manage.sh status
  ./helm-manage.sh logs prometheus
  ./helm-manage.sh port-forward
  ./helm-manage.sh update-password mynewpassword
  ./helm-manage.sh scale 3

EOF
}

# ============================================================================
# Show Status
# ============================================================================
status_cmd() {
    echo -e "${BLUE}=== Helm Release Status ===${NC}"
    helm status $RELEASE_NAME -n $NAMESPACE
    echo ""
    echo -e "${BLUE}=== Pod Status ===${NC}"
    kubectl get pods -n $NAMESPACE
}

# ============================================================================
# List Pods
# ============================================================================
pods_cmd() {
    echo -e "${BLUE}=== All Pods in $NAMESPACE ===${NC}"
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    echo -e "${BLUE}=== Pod Resources ===${NC}"
    kubectl top pod -n $NAMESPACE 2>/dev/null || echo "Metrics not available (install metrics-server)"
}

# ============================================================================
# Show Logs
# ============================================================================
logs_cmd() {
    POD_SEARCH=$1
    if [ -z "$POD_SEARCH" ]; then
        echo -e "${RED}Please specify a pod name (partial match OK)${NC}"
        echo "Available pods:"
        kubectl get pods -n $NAMESPACE -o name | sed 's/pod\///'
        exit 1
    fi
    
    POD=$(kubectl get pods -n $NAMESPACE -o name | grep $POD_SEARCH | head -n1 | sed 's/pod\///')
    if [ -z "$POD" ]; then
        echo -e "${RED}Pod not found matching: $POD_SEARCH${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}=== Logs for $POD ===${NC}"
    kubectl logs -n $NAMESPACE $POD --tail=100 -f
}

# ============================================================================
# Port Forward Instructions
# ============================================================================
portforward_cmd() {
    echo -e "${GREEN}${BLUE}=== Port Forward Commands ===${NC}"
    echo ""
    echo -e "${YELLOW}Prometheus (9090):${NC}"
    echo -e "  ${GREEN}kubectl port-forward -n $NAMESPACE svc/prometheus-operated 9090:9090${NC}"
    echo ""
    echo -e "${YELLOW}Grafana (3000):${NC}"
    echo -e "  ${GREEN}kubectl port-forward -n $NAMESPACE svc/grafana 3000:80${NC}"
    echo ""
    echo -e "${YELLOW}AlertManager (9093):${NC}"
    echo -e "  ${GREEN}kubectl port-forward -n $NAMESPACE svc/alertmanager-operated 9093:9093${NC}"
    echo ""
    echo -e "${GREEN}Note:${NC} Run each command in a separate terminal and keep them running"
}

# ============================================================================
# Update Grafana Password
# ============================================================================
update_password_cmd() {
    NEW_PASSWORD=$1
    if [ -z "$NEW_PASSWORD" ]; then
        read -sp "Enter new Grafana password: " NEW_PASSWORD
        echo ""
        read -sp "Confirm password: " CONFIRM_PASSWORD
        echo ""
        if [ "$NEW_PASSWORD" != "$CONFIRM_PASSWORD" ]; then
            echo -e "${RED}Passwords do not match${NC}"
            exit 1
        fi
    fi
    
    echo -e "${YELLOW}Updating Grafana admin password...${NC}"
    kubectl set env -n $NAMESPACE deployment/grafana GF_SECURITY_ADMIN_PASSWORD="$NEW_PASSWORD"
    kubectl rollout restart deployment/grafana -n $NAMESPACE
    kubectl rollout status deployment/grafana -n $NAMESPACE --timeout=2m
    echo -e "${GREEN}✓ Password updated${NC}"
}

# ============================================================================
# Backup Values
# ============================================================================
backup_cmd() {
    BACKUP_FILE="helm-values-backup-$(date +%Y%m%d-%H%M%S).yaml"
    echo -e "${YELLOW}Backing up current Helm values to $BACKUP_FILE${NC}"
    helm values $RELEASE_NAME -n $NAMESPACE > $BACKUP_FILE
    echo -e "${GREEN}✓ Backup saved: $BACKUP_FILE${NC}"
}

# ============================================================================
# Restart Pods
# ============================================================================
restart_cmd() {
    echo -e "${YELLOW}Restarting all monitoring pods...${NC}"
    kubectl rollout restart statefulset/prometheus-server -n $NAMESPACE
    kubectl rollout restart deployment/grafana -n $NAMESPACE
    kubectl rollout restart statefulset/alertmanager-main -n $NAMESPACE
    
    echo -e "${YELLOW}Waiting for rollout to complete...${NC}"
    kubectl rollout status statefulset/prometheus-server -n $NAMESPACE --timeout=5m
    kubectl rollout status deployment/grafana -n $NAMESPACE --timeout=5m
    echo -e "${GREEN}✓ All pods restarted${NC}"
}

# ============================================================================
# Describe Resources
# ============================================================================
describe_cmd() {
    echo -e "${BLUE}=== Deployments ===${NC}"
    kubectl describe deployment -n $NAMESPACE
    echo ""
    echo -e "${BLUE}=== StatefulSets ===${NC}"
    kubectl describe statefulset -n $NAMESPACE
    echo ""
    echo -e "${BLUE}=== Services ===${NC}"
    kubectl describe svc -n $NAMESPACE
}

# ============================================================================
# Show Helm Values
# ============================================================================
helm_values_cmd() {
    echo -e "${BLUE}=== Current Helm Values ===${NC}"
    helm values $RELEASE_NAME -n $NAMESPACE | head -100
    echo ""
    echo -e "${YELLOW}To see all values: helm values $RELEASE_NAME -n $NAMESPACE | less${NC}"
}

# ============================================================================
# Scale Deployment
# ============================================================================
scale_cmd() {
    REPLICAS=$1
    if [ -z "$REPLICAS" ]; then
        echo -e "${RED}Please specify number of replicas${NC}"
        exit 1
    fi
    
    if ! [[ "$REPLICAS" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Replicas must be a number${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Scaling deployments to $REPLICAS replicas...${NC}"
    kubectl scale deployment/grafana -n $NAMESPACE --replicas=$REPLICAS
    echo -e "${GREEN}✓ Scaled${NC}"
}

# ============================================================================
# Uninstall Release
# ============================================================================
uninstall_cmd() {
    echo -e "${RED}⚠️  WARNING: This will delete the Helm release and all resources${NC}"
    read -p "Type 'yes' to confirm uninstall: " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo "Cancelled"
        exit 0
    fi
    
    echo -e "${YELLOW}Uninstalling Helm release: $RELEASE_NAME${NC}"
    helm uninstall $RELEASE_NAME -n $NAMESPACE
    echo -e "${GREEN}✓ Release uninstalled${NC}"
}

# ============================================================================
# Main Script
# ============================================================================

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

COMMAND=$1
shift

case $COMMAND in
    status)
        status_cmd
        ;;
    pods)
        pods_cmd
        ;;
    logs)
        logs_cmd $@
        ;;
    port-forward)
        portforward_cmd
        ;;
    update-password)
        update_password_cmd $@
        ;;
    backup)
        backup_cmd
        ;;
    restart)
        restart_cmd
        ;;
    describe)
        describe_cmd
        ;;
    helm-values)
        helm_values_cmd
        ;;
    scale)
        scale_cmd $@
        ;;
    uninstall)
        uninstall_cmd
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac
