<div align="center">

# 🚀 Prometheus & Grafana - Kubernetes Helm Deployment

[![Prometheus](https://img.shields.io/badge/Prometheus-2.47.0-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)](https://prometheus.io)
[![Grafana](https://img.shields.io/badge/Grafana-Latest-F2CC0C?style=for-the-badge&logo=grafana&logoColor=black)](https://grafana.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.19+-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![Helm](https://img.shields.io/badge/Helm-3.x-0F1419?style=for-the-badge&logo=helm&logoColor=1f90f0)](https://helm.sh)

[![GitHub](https://img.shields.io/badge/GitHub-Narendra--Geddam%2Fmonitoring-181717?style=for-the-badge&logo=github)](https://github.com/Narendra-Geddam/monitoring)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)](#)

---

### 📊 Complete Monitoring Stack for Kubernetes Clusters

</div>

<br>

## 📋 Table of Contents

- [🎯 Overview](#overview)
- [✨ Features](#features)  
- [📦 Files Included](#files-included)
- [🌍 Environment-Specific Setup](#environment-specific-setup)
- [🚀 Quick Start](#quick-start)
- [⚙️ Configuration](#configuration)
- [🔧 Management](#management)
- [📚 Documentation](#documentation)

<br>

## 🌍 Environment-Specific Setup

### 1️⃣ Auto-Detect Your Cluster

Run the environment detection script to automatically identify your cluster type and configure storage. The script will even prompt to start the installation immediately:

```bash
chmod +x detect-environment.sh
./detect-environment.sh
```

**What happens:**
- ✓ Auto-detects cluster type (EKS/GKE/AKS/Lab/Minikube)
- ✓ Discovers available storage classes
- ✓ Installs local-path provisioner if needed (lab environments)
- ✓ Generates environment-specific values file
- ✓ Optionally starts installation automatically

**When prompted:** Just press `Enter` or type `y` to start installation!

### Alternative: Manual Installation

### 2️⃣ Lab & On-Premises (No CSI)

For clusters **without CSI drivers** (typical in lab/on-premises):

```bash
# Install local-path provisioner
chmod +x install-local-path-provisioner.sh
./install-local-path-provisioner.sh

# Install monitoring with lab configuration
./install-helm-prometheus-grafana.sh helm-values-lab-local-path.yaml
```

**Storage:** Local-path provisioner  
**Location:** `/var/lib/rancher/local-path-provisioner/`  
**Best for:** Lab, single-node, on-premises clusters

### 3️⃣ AWS EKS

```bash
# Install with EKS configuration (uses gp3 EBS volumes)
./install-helm-prometheus-grafana.sh helm-values-aws-eks.yaml
```

**Storage:** AWS EBS gp3 (dynamic provisioning)  
**Best for:** AWS EKS production clusters

### 4️⃣ Quick Dev/Test

```bash
# Install with EmptyDir storage (fast, non-persistent)
./install-helm-prometheus-grafana.sh helm-values-emptydir-dev.yaml
```

**Storage:** EmptyDir (in-memory)  
**⚠️ Note:** Data lost on pod restart  
**Best for:** Quick testing, development

<br>

## 🚀 Quick Start

- [🎯 Overview](#overview)
- [✨ Features](#features)  
- [📦 Files Included](#files-included)
- [🚀 Quick Start](#quick-start)
- [⚙️ Configuration](#configuration)
- [🔧 Management](#management)
- [📚 Documentation](#documentation)

<br>

## 🎯 Overview

This repository provides an **automated, production-ready deployment** of **Prometheus** and **Grafana** on Kubernetes using **Helm charts**. Perfect for comprehensive monitoring and observability across your entire infrastructure.

**Includes:** Prometheus, Grafana, AlertManager, Node Exporter, and Kube-State-Metrics

<br>

## ✨ Features

- ✅ **Automated One-Command Setup** - Intelligent prerequisite checking
- ✅ **Production Ready** - High availability configuration included
- ✅ **Easy Management** - CLI tool for common operations
- ✅ **Security First** - RBAC, TLS/SSL support built-in
- ✅ **Full Stack Monitoring** - Kubernetes, nodes, pods, custom metrics
- ✅ **Scalable** - Multi-replica support, load balancing

<br>

## 📦 Files Included

| File | Purpose |
|------|---------|
| `install-local-path-provisioner.sh` | 🔧 Lab: Install local-path provisioner & set as default |
| `install-helm-prometheus-grafana.sh` | 🚀 Main automated installation script |
| `detect-environment.sh` | 🔍 Auto-detect cluster type and configure storage |
| `helm-values.yaml` | ⚙️ Production-grade configuration |
| `helm-values-lab-local-path.yaml` | 📂 Lab environment (local-path storage) |
| `helm-values-aws-eks.yaml` | ☁️ AWS EKS configuration (EBS gp3) |
| `helm-values-emptydir-dev.yaml` | 🚀 Quick dev/test (EmptyDir, non-persistent) |
| `helm-values-quickstart.yaml` | ⚡ Quick start with reduced resources |
| `helm-manage.sh` | 🛠️ Management and troubleshooting CLI |
| `HELM-PRODUCTION-GUIDE.md` | 📚 Comprehensive production guide |
| `TROUBLESHOOTING-PVC.md` | 🔍 PVC binding troubleshooting guide |

## Quick Start

### Prerequisites

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify connection
kubectl cluster-info
```

### Installation

**Option 1: Auto-detect environment** (Recommended)
```bash
chmod +x detect-environment.sh
./detect-environment.sh
./install-helm-prometheus-grafana.sh
```

**Option 2: Manual environment selection**
```bash
# Lab/On-premises (requires local-path provisioner)
chmod +x install-local-path-provisioner.sh
./install-local-path-provisioner.sh
./install-helm-prometheus-grafana.sh

# Or specify a values file directly
./install-helm-prometheus-grafana.sh helm-values-lab-local-path.yaml
./install-helm-prometheus-grafana.sh helm-values-aws-eks.yaml
./install-helm-prometheus-grafana.sh helm-values-quickstart.yaml
```

The script will:
1. ✓ Check kubectl and helm installation
2. ✓ Add Prometheus and Grafana Helm repositories
3. ✓ Create monitoring namespace
4. ✓ Install kube-prometheus-stack chart
5. ✓ Wait for deployments to be ready
6. ✓ Display access and credential information

## 🔍 Troubleshooting

### PVC Binding Issues

If you see: `PersistentVolumeClaim not ready. status: Pending`

**For Lab Environments:**
```bash
# Install local-path provisioner
./install-local-path-provisioner.sh

# Then redeploy
helm uninstall prometheus -n monitoring
./install-helm-prometheus-grafana.sh helm-values-lab-local-path.yaml
```

**For other issues**, see [TROUBLESHOOTING-PVC.md](TROUBLESHOOTING-PVC.md)

## Access Services

### Port-Forward (Development)

```bash
# Prometheus (9090)
kubectl port-forward -n monitoring svc/prometheus-kube-prom-prometheus 9090:9090

# Grafana (3000)
kubectl port-forward -n monitoring svc/grafana 3000:80

# AlertManager (9093)
kubectl port-forward -n monitoring svc/prometheus-kube-prom-alertmanager 9093:9093
```

Then access:
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin123)
- **AlertManager**: http://localhost:9093

### LoadBalancer (Production)

Edit `helm-values.yaml` to use LoadBalancer service type:

```yaml
prometheus:
  service:
    type: LoadBalancer
    
grafana:
  service:
    type: LoadBalancer
```

Then upgrade:
```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring -f helm-values.yaml
```

## Configuration

### Production Setup

Use `helm-values.yaml` with:
- 50Gi storage for Prometheus
- 7-day retention policy
- Full alerting rules
- Production resource limits

### Development Setup

Use `helm-values-quickstart.yaml` with:
- 10Gi storage for Prometheus
- 3-day retention policy
- Reduced resources
- Minimal rules

## Management

### Using helm-manage.sh

```bash
# View status
./helm-manage.sh status

# List all pods
./helm-manage.sh pods

# View logs
./helm-manage.sh logs prometheus

# Update Grafana password
./helm-manage.sh update-password mynewpassword

# Backup configuration
./helm-manage.sh backup

# Scale deployments
./helm-manage.sh scale 3

# Get help
./helm-manage.sh help
```

### Common Helm Commands

```bash
# View release status
helm status prometheus -n monitoring

# See current values
helm values prometheus -n monitoring

# View release history
helm history prometheus -n monitoring

# Upgrade with new values
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring -f helm-values.yaml

# Rollback to previous version
helm rollback prometheus 1 -n monitoring

# Uninstall release
helm uninstall prometheus -n monitoring
```

## Monitoring and Troubleshooting

```bash
# Check pod status
kubectl get pods -n monitoring

# View pod logs
kubectl logs -n monitoring <pod-name>

# Describe pod
kubectl describe pod -n monitoring <pod-name>

# Check PVC status
kubectl get pvc -n monitoring

# View events
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# Resource usage
kubectl top pods -n monitoring
```

## What Gets Installed

- **Prometheus**: Metrics collection and storage (StatefulSet)
- **Grafana**: Visualization and dashboarding (Deployment)
- **AlertManager**: Alert handling and routing (StatefulSet)
- **Node Exporter**: Host metrics collection (DaemonSet)
- **Kube-State-Metrics**: Kubernetes object metrics (Deployment)
- **Prometheus Operator**: CRD-based configuration (Deployment)

## Credentials

Default Grafana credentials:
- **Username**: admin
- **Password**: admin123

⚠️ Change password immediately in production:
```bash
./helm-manage.sh update-password "strong-secure-password"
```

## 📚 Documentation

### Core Documentation
- **[HELM-PRODUCTION-GUIDE.md](HELM-PRODUCTION-GUIDE.md)** - Enterprise deployment, scaling, HA, security, backup
- **[TROUBLESHOOTING-PVC.md](TROUBLESHOOTING-PVC.md)** - PVC binding issues and solutions for all environments

### Helper Scripts
- **`detect-environment.sh`** - Auto-detects your cluster and generates appropriate config
- **`helm-manage.sh`** - CLI tool for common operations (status, logs, scaling, backups)
- **`install-local-path-provisioner.sh`** - Sets up storage for lab environments

### Configuration Files by Environment
- `helm-values.yaml` - Production (50Gi storage, 7-day retention)
- `helm-values-lab-local-path.yaml` - Lab/On-premises (local-path provisioner)
- `helm-values-aws-eks.yaml` - AWS EKS (EBS gp3 volumes)
- `helm-values-quickstart.yaml` - Development (10Gi storage, reduced resources)
- `helm-values-emptydir-dev.yaml` - Quick testing (non-persistent in-memory)

## Support & Best Practices

- **Lab Environments**: Run `install-local-path-provisioner.sh` first, then install with `helm-values-lab-local-path.yaml`
- **Production**: Use `helm-values.yaml` with LoadBalancer or Ingress for external access
- **Storage Issues**: Refer to [TROUBLESHOOTING-PVC.md](TROUBLESHOOTING-PVC.md) for detailed diagnostics
- **Monitor Health**: Use `./helm-manage.sh status` to check deployment status

## Cleanup Scan Notes

