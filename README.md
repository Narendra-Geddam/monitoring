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

## 🚀 Quick Start

```bash
chmod +x install-helm-prometheus-grafana.sh
./install-helm-prometheus-grafana.sh
```

## 🌐 Access Services

**Via Port-Forward:**
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prom-prometheus 9090:9090
kubectl port-forward -n monitoring svc/grafana 3000:80
```

- 📊 Prometheus: http://localhost:9090
- 📈 Grafana: http://localhost:3000 (admin/admin123)
- 🔔 AlertManager: http://localhost:9093

## 📦 Files Included

| File | Purpose |
|------|---------|
| `install-helm-prometheus-grafana.sh` | Installation script |
| `helm-values.yaml` | Production configuration |
| `helm-values-quickstart.yaml` | Development configuration |
| `helm-manage.sh` | Management commands |
| `HELM-PRODUCTION-GUIDE.md` | Production guide |
| `README.backup.md` | Backup documentation |

## ⚙️ Configuration

**Production:** Use `helm-values.yaml` (50Gi storage, 7-day retention)
**Development:** Use `helm-values-quickstart.yaml` (10Gi storage, 3-day retention)

## 🛠️ Management

```bash
./helm-manage.sh status         # View status
./helm-manage.sh pods           # List pods
./helm-manage.sh logs prometheus # View logs
./helm-manage.sh update-password "new-pass" # Change password
./helm-manage.sh help           # Full help
```

## 🏗️ Components

- ✅ Prometheus (StatefulSet)
- ✅ Grafana (Deployment)
- ✅ AlertManager (StatefulSet)
- ✅ Node Exporter (DaemonSet)
- ✅ Kube-State-Metrics (Deployment)
- ✅ Prometheus Operator (Deployment)

## 🔐 Security

Default Grafana: `admin / admin123`

**Change password immediately:**
```bash
./helm-manage.sh update-password "strong-secure-password"
```

## 📚 Documentation

See `HELM-PRODUCTION-GUIDE.md` for:
- Production best practices
- Scaling & high availability
- Security hardening
- Backup & recovery

## 🆘 Troubleshooting

```bash
kubectl logs -n monitoring <pod-name>
kubectl describe pod -n monitoring <pod-name>
kubectl get pvc -n monitoring
```

---

<div align="center">

### 🌟 Made with ❤️ for Kubernetes

**⭐ Star this repository if it helped you!**

[GitHub](https://github.com/Narendra-Geddam/monitoring) | [Production Guide](HELM-PRODUCTION-GUIDE.md)

</div>
