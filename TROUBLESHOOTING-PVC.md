# Troubleshooting PVC (Persistent Volume Claim) Issues

## Common PVC Problems and Solutions

### Problem 1: PVC Status = "Pending"

```
resource PersistentVolumeClaim/monitoring/prometheus-grafana not ready
status: InProgress, message: PVC is not Bound
phase: Pending
```

**Cause:** No storage class available or storage provisioner not configured

**Solution:**

```bash
# Check available storage classes
kubectl get storageclass

# Check PVC status details
kubectl describe pvc prometheus-grafana -n monitoring

# Check for errors in provisioner
kubectl describe pv
```

**Fix Options:**

#### Option A: Lab Environment (Recommended)
Use local-path provisioner (no CSI needed):

```bash
# Install local-path provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Use values file for lab
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring -f helm-values-lab-local-path.yaml
```

#### Option B: AWS EKS
Use EBS dynamic provisioning:

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring -f helm-values-aws-eks.yaml
```

#### Option C: Temporary Testing (EmptyDir)
Data will be lost on pod restart:

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring -f helm-values-emptydir-dev.yaml
```

---

### Problem 2: PVC Stuck in "Pending" - No Provisioner

Lab environment without any storage provisioner:

```bash
# Install Rancher Local Path Provisioner (works in any K8s cluster)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Verify installation
kubectl get storageclass

# Expected output:
# NAME         PROVISIONER             RECLAIM POLICY   STATUS
# local-path   rancher.io/local-path   Delete           Available

# Update Helm installation with correct storage class
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=local-path \
  --set grafana.persistence.storageClassName=local-path \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName=local-path
```

---

### Problem 3: Pod CrashLoopBackOff Due to PVC

```
Pod prometheus-grafana is not ready: CrashLoopBackOff
```

Check logs:

```bash
kubectl logs -n monitoring prometheus-grafana-0 -f
```

**Solution:**
Ensure PVC is bound before pod becomes ready:

```bash
# Check PVC status
kubectl get pvc -n monitoring

# Wait for all PVCs to be "Bound"
kubectl wait --for=condition=Bound pvc --all -n monitoring --timeout=300s
```

---

### Problem 4: Different Environments Need Different Storage Classes

| Environment | Storage Class | Use Case |
|-------------|---------------|----------|
| **Lab/Local K8s** | `local-path` | On-premises, no CSI |
| **AWS EKS** | `gp3` or `gp2` | AWS-managed K8s |
| **Google GKE** | `standard` or `premium-rwo` | Google-managed K8s |
| **Azure AKS** | `managed-premium` | Azure-managed K8s |
| **Minikube** | `standard` | Local development |
| **Docker Desktop** | `hostpath` | Local development |
| **Testing** | `emptyDir` | Temporary, non-persistent |

---

## Environment Detection

Run the automated environment detection script:

```bash
chmod +x detect-environment.sh
./detect-environment.sh
```

This will:
1. Detect your Kubernetes environment
2. Check available storage classes
3. Ask you to configure storage options
4. Generate appropriate values file

---

## Quick Fixes by Environment

### For Lab Environments

```bash
# 1. Install local-path provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# 2. Use lab values file
chmod +x install-helm-prometheus-grafana.sh
# Edit script: sed -i 's/helm-values.yaml/helm-values-lab-local-path.yaml/g' install-helm-prometheus-grafana.sh

./install-helm-prometheus-grafana.sh
```

### For AWS EKS

```bash
# Use EKS values file directly
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f helm-values-aws-eks.yaml \
  --wait
```

### For Quick Testing (Data Will Be Lost)

```bash
# Use emptyDir values (no persistent storage)
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f helm-values-emptydir-dev.yaml \
  --wait \
  --timeout 5m
```

---

## Verify Storage Configuration

After installation, verify storage is working:

```bash
# Check PersistentVolumeClaims
kubectl get pvc -n monitoring
# Expected: All PVCs should be "Bound"

# Check PersistentVolumes
kubectl get pv
# Expected: PVs should be "Bound"

# Check storage class
kubectl get storageclass
# Expected: At least one default storage class

# Check pod storage mounting
kubectl describe pod -n monitoring prometheus-kube-prom-prometheus-0
# Look for: Mounts section showing volumes mounted to /prometheus
```

---

## Storage Type Comparison

### Persistent Volume (Recommended)

✅ Data persists across pod restarts
✅ Suitable for production
❌ Requires storage provisioning
❌ Higher cost
**Use for:** Production, persistent metrics

### EmptyDir

✅ Fast, no provisioning needed
✅ Good for testing
❌ Data lost on pod restart
❌ Not suitable for production
**Use for:** Development, testing

### No Storage

✅ Minimal resource usage
✅ Fast startup
❌ No data persistence
❌ Very limited metrics history
**Use for:** Quick testing only

---

## Checking Storage Class Details

```bash
# See all available storage classes
kubectl get storageclass

# Check details of specific storage class
kubectl get storageclass gp3 -o yaml

# Check if default storage class exists
kubectl get storageclass --sort-by=.metadata.annotations

# Switch default storage class
kubectl patch storageclass <name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---

## If Installation Still Fails

1. **Check cluster resources:**
   ```bash
   kubectl describe nodes
   # Check available CPU and memory
   ```

2. **Check PVC details:**
   ```bash
   kubectl describe pvc -n monitoring
   # Look for events explaining why it's not binding
   ```

3. **Check provisioner logs:**
   ```bash
   # For local-path provisioner
   kubectl logs -n local-path-storage -l app=local-path-provisioner

   # Or for other provisioners in their namespace
   ```

4. **Try reducing resource requirements:**
   - Edit the values file and reduce CPU/memory requests
   - Reduce storage size for initial testing

5. **Uninstall and retry:**
   ```bash
   helm uninstall prometheus -n monitoring
   kubectl delete pvc --all -n monitoring
   # Make configuration changes
   helm install prometheus ... -f corrected-values.yaml
   ```

---

## Support

For persistent issues:
- Review provisioner logs
- Check node capacity
- Verify storage backend availability
- Use `helm-manage.sh status` for quick diagnostics
