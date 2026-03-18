<div align="center">

# 🚀 Prometheus & Grafana - Kubernetes Helm Deployment

[![Prometheus](https://img.shields.io/badge/Prometheus-2.47.0-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)](https://prometheus.io)
[![Grafana](https://img.shields.io/badge/Grafana-Latest-F2CC0C?style=for-the-badge&logo=grafana&logoColor=black)](https://grafana.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.19+-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![Helm](https://img.shields.io/badge/Helm-3.x-0F1419?style=for-the-badge&logo=helm&logoColor=1f90f0)](https://helm.sh)

---

### 📊 Complete Monitoring for Kubernetes

</div>

## ⚡ Quick Start

```bash
# Lab/On-Premises
chmod +x install.sh
./install.sh helm-values-lab.yaml

# Production
./install.sh helm-values.yaml

# Development
./install.sh helm-values-dev.yaml
```

## 📦 Files

| File | Purpose |
|------|---------|
| **install.sh** | 🚀 Smart installation (auto-detects environment, installs storage if needed) |
| **helm-values.yaml** | ⚙️ Production (50GiB, 7-day retention) |
| **helm-values-lab.yaml** | 🔬 Lab/On-Premises (10GiB, local-path) |
| **helm-values-dev.yaml** | 🧪 Development (5GiB) |
| **helm-manage.sh** | 🛠️ CLI for status, logs, passwords |

## 🌐 Access Services

### Lab Environment (NodePort - Direct Access)
```bash
# Get node IP
kubectl get nodes -o jsonpath='{.items[0].status.addresses[*].address}'

# Access directly (no port-forward needed!)
http://<NODE_IP>:30300   # Grafana (admin/admin123)
http://<NODE_IP>:30090   # Prometheus
http://<NODE_IP>:30093   # AlertManager
```

### Port-Forward Method (Development/Production)
```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# AlertManager
kubectl port-forward -n monitoring svc/alertmanager-operated 9093:9093
```

## 🛠️ Management Commands

```bash
./helm-manage.sh status
./helm-manage.sh pods
./helm-manage.sh logs <pod-name>
./helm-manage.sh update-password mynewpass
```

## 📊 Components

- **Prometheus**: Metrics collection & storage (StatefulSet)
- **Grafana**: Dashboards (Deployment)
- **AlertManager**: Alert routing (StatefulSet)
- **Node Exporter**: Host metrics (DaemonSet)
- **Kube-State-Metrics**: Kubernetes metrics (Deployment)
- **Prometheus Operator**: CRD management (Deployment)

## 🔧 Environments

### Lab / On-Premises
```bash
./install.sh helm-values-lab.yaml
```
✓ Installs local-path provisioner  
✓ 10GiB storage  
✓ **NodePort exposure** (Grafana:30300, Prometheus:30090, AlertManager:30093)

### AWS EKS / GCP GKE / Azure AKS
```bash
./install.sh helm-values.yaml
```
✓ Uses cloud provider storage  
✓ 50GiB, 7-day retention

### Development
```bash
./install.sh helm-values-dev.yaml
```
✓ Minimal resources  
✓ 5GiB storage

## ❌ Troubleshooting

**PVC stuck in Pending?**
```bash
kubectl get storageclass
kubectl get pods -n local-path-storage
kubectl describe pvc -n monitoring
```

## 👤 Credentials

- **Grafana**: admin / admin123
- ⚠️ Change password in production!

---

**Repo**: [Narendra-Geddam/monitoring](https://github.com/Narendra-Geddam/monitoring)
