# Helm Deployment - Production Best Practices

## Overview

This guide covers production-grade deployment of Prometheus and Grafana on Kubernetes using Helm with the `kube-prometheus-stack` chart.

## Prerequisites

```bash
# Kubernetes cluster (1.19+)
kubectl version

# Helm 3.x
helm version

# kubectl connectivity
kubectl cluster-info
```

## Installation

### Step 1: Add Helm Repositories
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### Step 2: Create Namespace
```bash
kubectl create namespace monitoring
kubectl label namespace monitoring name=monitoring
```

### Step 3: Review and Customize Values

Edit `helm-values.yaml` to match your environment:
- Storage class and sizes
- Resource requests/limits
- Retention policies
- External access configuration

### Step 4: Install

```bash
# Dry-run to verify
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values helm-values.yaml \
  --dry-run --debug

# Actual installation
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values helm-values.yaml \
  --wait --timeout 5m
```

## Production Configuration

### 1. Storage Class

Ensure proper storage class for Prometheus persistent volume:

```yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: "fast-ssd"  # Use your storage class
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 100Gi  # Adjust based on metrics volume
```

Common storage classes:
- `fast-ssd`: SSD-backed for high performance
- `standard`: Regular storage
- `local-path`: Local node storage

### 2. Resource Allocation

Size based on cluster and metric volume:

**Small Cluster (5 nodes)**
```yaml
prometheus:
  prometheusSpec:
    resources:
      requests: {cpu: 500m, memory: 2Gi}
      limits: {cpu: 1000m, memory: 4Gi}
```

**Medium Cluster (10-20 nodes)**
```yaml
prometheus:
  prometheusSpec:
    resources:
      requests: {cpu: 1000m, memory: 4Gi}
      limits: {cpu: 2000m, memory: 8Gi}
```

**Large Cluster (50+ nodes)**
```yaml
prometheus:
  prometheusSpec:
    resources:
      requests: {cpu: 2000m, memory: 8Gi}
      limits: {cpu: 4000m, memory: 16Gi}
```

### 3. Data Retention

Balance between storage cost and data availability:

```yaml
prometheus:
  prometheusSpec:
    retention: 30d              # Keep 30 days of data
    retentionSize: "100Gi"      # OR enforce storage limit
    # Use either retention OR retentionSize, not both
```

### 4. Alert Rules

Enable only necessary alert rules:

```yaml
defaultRules:
  rules:
    # Enable based on your needs
    k8s: true                   # Kubernetes cluster alerts
    kubelet: true               # Kubelet alerts
    kubeStateMetrics: true      # Kube-state-metrics alerts
    node: true                  # Node alerts
    prometheus: true            # Prometheus itself
    alertmanager: true          # AlertManager alerts
    
    # Disable if not needed
    etcd: false                 # Only if using etcd
```

### 5. Service Monitoring

Enable service discovery for automatic scraping:

```yaml
prometheus:
  prometheusSpec:
    # Discover ALL ServiceMonitor resources
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorNamespaceSelector: {}
    
    # Or use labels for selective discovery
    serviceMonitorSelector:
      matchLabels:
        prometheus: enabled
```

Usage in your namespaces:
```bash
kubectl label namespace myapp prometheus=enabled
```

## Security Best Practices

### 1. Change Default Credentials

```bash
# Generate secure password
PASSWORD=$(openssl rand -base64 32)
echo $PASSWORD

# Update in values.yaml or directly
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set grafana.adminPassword="$PASSWORD"
```

### 2. RBAC

Ensure proper RBAC is in place (included in chart):

```bash
# Verify ServiceAccount
kubectl get sa -n monitoring

# Verify ClusterRole
kubectl get clusterrole | grep prometheus
```

### 3. Network Policies

Restrict access to monitoring services:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-access
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app: grafana
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - protocol: TCP
          port: 3000
```

### 4. TLS/SSL

For external access, use TLS:

```yaml
grafana:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    hosts:
      - grafana.example.com
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.example.com

prometheus:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    hosts:
      - prometheus.example.com
    tls:
      - secretName: prometheus-tls
        hosts:
          - prometheus.example.com
```

## Monitoring the Monitor

### 1. Self-Monitoring

Prometheus monitors itself by default (job_name: 'prometheus')

### 2. Check Prometheus Health

```bash
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Visit http://localhost:9090/targets
```

### 3. Alert Rules Status

```bash
# Check for rule evaluation errors
kubectl logs -n monitoring prometheus-server-0 | grep -i error
```

## Scaling and High Availability

### 1. Multiple Prometheus Replicas

```yaml
prometheus:
  prometheusSpec:
    replicas: 2  # Or more for HA
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - prometheus
              topologyKey: kubernetes.io/hostname
```

### 2. Grafana High Availability

```yaml
grafana:
  replicas: 2
  persistence:
    enabled: true
    size: 10Gi  # Shared storage recommended
```

### 3. AlertManager Clustering

```yaml
alertmanager:
  alertmanagerSpec:
    replicas: 3
    storage:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 10Gi
```

## Backup and Recovery

### 1. Backup Prometheus Data

```bash
# Kubectl snapshot
kubectl exec -n monitoring prometheus-server-0 -- \
  sh -c 'tar czf - /prometheus' > prometheus-backup.tar.gz

# Or use S3 backup
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: prometheus-backup
  namespace: monitoring
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: curlimages/curl
            command:
              - sh
              - -c
              - |
                curl -s http://prometheus-server:80/api/v1/query?query=up | \
                aws s3 cp - s3://my-bucket/prometheus-backup-\$(date +%s).json
          restartPolicy: OnFailure
EOF
```

### 2. Backup Grafana

```bash
# Export dashboards
kubectl exec -n monitoring grafana-0 -- \
  grafana-cli admin export-dashboard

# Or backup database
kubectl get pvc -n monitoring grafana -o yaml > grafana-pvc-backup.yaml
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n monitoring
kubectl describe pod -n monitoring <pod-name>
kubectl logs -n monitoring <pod-name>
```

### Check PVC Status
```bash
kubectl get pvc -n monitoring
kubectl describe pvc -n monitoring prometheus-server
```

### View Events
```bash
kubectl get events -n monitoring --sort-by='.lastTimestamp'
```

### Check Resource Usage
```bash
kubectl top pods -n monitoring
kubectl top nodes
```

### Verify Configuration
```bash
# Check Prometheus config
kubectl exec -n monitoring prometheus-server-0 -- \
  prometheus --config.file=/etc/prometheus/prometheus.yml --validate-only

# Check scrape targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Visit http://localhost:9090/targets
```

## Upgrades

### Check Available Versions
```bash
helm search repo prometheus-community/kube-prometheus-stack --versions
```

### Upgrade Safely

```bash
# Backup current values
helm get values prometheus -n monitoring > values-backup.yaml

# Test upgrade
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring -f helm-values.yaml --dry-run --debug

# Perform upgrade
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring -f helm-values.yaml --wait

# Verify
kubectl rollout status statefulset/prometheus-server -n monitoring
```

### Rollback If Needed
```bash
helm rollback prometheus <revision> -n monitoring
```

## Maintenance

### Regular Tasks

- **Daily**: Check pod status and logs
- **Weekly**: Review alert rules and dashboards
- **Monthly**: Check storage usage and retention policies
- **Quarterly**: Upgrade components and review security

### Cleanup

```bash
# Remove unused pods
kubectl delete pod -n monitoring <pod-name>

# Clean up old PVCs
kubectl delete pvc -n monitoring <claim-name>

# Uninstall completely
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring
```

## Additional Resources

- [kube-prometheus-stack Documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Documentation](https://prometheus.io/docs)
- [Grafana Documentation](https://grafana.com/docs)
- [Kubernetes Monitoring Best Practices](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/)
