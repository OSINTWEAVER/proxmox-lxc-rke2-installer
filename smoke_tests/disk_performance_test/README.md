# Disk Performance Smoke Test (FIO Benchmarks)

This test validates disk I/O performance across your Kubernetes cluster worker nodes using FIO (Flexible I/O Tester) with benchmarks similar to CrystalDiskMark.

## What This Test Does

✅ **Sequential Performance** - Large block sequential read/write speeds (MB/s)  
✅ **Random IOPS** - 4K random read/write operations per second  
✅ **Mixed Workloads** - Real-world 70% read / 30% write scenarios  
✅ **Latency Measurements** - Storage response times under load  
✅ **Cross-Node Comparison** - Performance differences between worker nodes  
✅ **Web Dashboard** - Real-time results display and monitoring  

## Test Components

- **`fio-benchmark-test.yaml`** - Complete Kubernetes deployment including:
  - DaemonSet for FIO pods on hardcoded worker nodes (worker-node-1, worker-node-2)
  - Web dashboard with customizable test sizes
  - ConfigMaps with FIO test scripts and HTML interface
  - NodePort service for external access
- **`deploy-fio-benchmark.sh`** - Deployment script with auto-teardown detection
- **`cleanup-fio-benchmark.sh`** - Dedicated cleanup script for safe removal

## Benchmark Tests (CrystalDiskMark Equivalent)

| Test | Description | CrystalDiskMark Equivalent |
|------|-------------|---------------------------|
| Sequential Read | 1MB blocks, queue depth 8 | SEQ1M Q8T1 Read |
| Sequential Write | 1MB blocks, queue depth 8 | SEQ1M Q8T1 Write |
| Random Read 4K | 4K blocks, queue depth 32, 16 jobs | RND4K Q32T16 Read |
| Random Write 4K | 4K blocks, queue depth 32, 16 jobs | RND4K Q32T16 Write |
| Mixed Random 4K | 4K blocks, 70% read / 30% write | RND4K Q1T1 Mixed |

## Prerequisites

- Kubernetes cluster with worker nodes
- Worker nodes with hostnames `worker-node-1` and `worker-node-2` (or customize in configuration)
- kubectl access to the cluster
- Worker node IPs: `10.14.100.2` and `10.14.100.3` (default, customizable)

## Configuration

### **Customizing Node IPs and Hostnames**

By default, this test targets:
- **worker-node-1** at IP `10.14.100.2`
- **worker-node-2** at IP `10.14.100.3`

To customize for your environment:

#### **1. Update Deploy Script (`deploy-fio-benchmark.sh`, line 47)**
```bash
# Change these to your actual worker node IPs
NODE_IPS="YOUR_NODE_1_IP YOUR_NODE_2_IP"
```

#### **2. Update YAML Configuration (`fio-benchmark-test.yaml`)**

**JavaScript Section (~line 340):**
```javascript
let clusterNodes = [
    {
        name: 'your-node-1-name',
        ip: 'YOUR_NODE_1_IP',
        type: 'Worker Node',
        storage: 'Local Storage',
        podName: 'fio-benchmark-worker-1'
    },
    {
        name: 'your-node-2-name',
        ip: 'YOUR_NODE_2_IP',
        type: 'Worker Node',
        storage: 'Local Storage',
        podName: 'fio-benchmark-worker-2'
    }
];
```

**DaemonSet Section (~line 1220):**
```yaml
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: kubernetes.io/hostname
        operator: In
        values:
        - your-actual-hostname-1
        - your-actual-hostname-2
```

#### **3. Find Your Node Information**
```bash
# Get node hostnames and IPs
kubectl get nodes -o wide
```

## How to Run

### Method 1: Quick Deployment

```bash
# Navigate to the test directory
cd smoke_tests/disk_performance_test

# Deploy the benchmark infrastructure
./deploy-fio-benchmark.sh
```

### Method 2: Manual Deployment

```bash
# Apply the Kubernetes configuration
kubectl apply -f fio-benchmark-test.yaml

# Check deployment status
kubectl get pods,svc,ds -l app=fio-benchmark
```

## Access the Dashboard

Once deployed, access the FIO benchmark dashboard at:

- **Direct Node Access**: 
  - http://10.14.100.2:30081 (or your first worker node IP)
  - http://10.14.100.3:30081 (or your second worker node IP)

- **Domain Access** (add to `/etc/hosts`):
  ```
  10.14.100.2 fio-benchmark.local disk-test.local
  10.14.100.3 fio-benchmark.local disk-test.local
  ```
  Then access: http://fio-benchmark.local:30081

## Running Benchmarks

### Option 1: Web Dashboard (Recommended)
1. Open the web dashboard
2. **Select test size**: Choose from dropdown (0.5GB default) or enter custom size
   - 0.5GB: Fast testing (2-3 minutes per test)
   - 1GB: Standard testing (3-5 minutes per test)  
   - 2GB+: Thorough testing (5+ minutes per test)
   - Custom: Enter any size like "3G" or "1.5G"
3. Click "🚀 Start All Benchmarks"
4. Monitor real-time progress and logs
5. View comparative results across GPU nodes

### Option 2: Manual Execution with Custom Sizes
```bash
# Get FIO pod names
kubectl get pods -l app=fio-benchmark

# Run with default size (0.5GB)
kubectl exec -it <pod-name> -- /tmp/run-benchmarks.sh

# Run with custom size
kubectl exec -it <pod-name> -- /tmp/run-benchmarks.sh --size 2G

# Run with custom size and runtime
kubectl exec -it <pod-name> -- /tmp/run-benchmarks.sh --size 1G --runtime 60

# Run on all worker nodes with custom size
for pod in $(kubectl get pods -l app=fio-benchmark -o name); do
  echo "Running 2GB benchmark on $pod..."
  kubectl exec $pod -- /tmp/run-benchmarks.sh --size 2G
done
```

## Expected Performance Ranges

### High-End NVMe SSD (Expected for GPU nodes):
- **Sequential Read**: 3,000-7,000 MB/s
- **Sequential Write**: 2,500-6,500 MB/s  
- **Random Read 4K**: 300,000-600,000 IOPS
- **Random Write 4K**: 250,000-550,000 IOPS
- **Latency**: < 1ms typical

### Performance Indicators:
- ✅ **Excellent**: > 5,000 MB/s sequential, > 500K IOPS random
- ✅ **Good**: > 3,000 MB/s sequential, > 300K IOPS random
- ⚠️ **Fair**: > 1,000 MB/s sequential, > 100K IOPS random
- ❌ **Poor**: < 1,000 MB/s sequential, < 100K IOPS random

## Dashboard Features

### 🎯 Interactive Controls
- Start/stop benchmarks across all nodes
- **Customizable test sizes**: 0.5GB (default), 1GB, 2GB, 4GB, 8GB, or custom
- Real-time progress monitoring
- Automatic result refresh

### 📊 Performance Metrics
- Bandwidth (MB/s) for sequential tests
- IOPS for random access tests
- Latency measurements (milliseconds)
- Cross-node performance comparison

### 📋 Real-time Logging
- Live benchmark execution logs
- Test progress indicators with size information
- Error detection and reporting

## Troubleshooting

### Pods Not Starting
```bash
kubectl describe pods -l app=fio-benchmark
kubectl logs -l app=fio-benchmark
```

### Node Selector Issues
Check node labels and hostnames:
```bash
kubectl get nodes --show-labels
kubectl get nodes -o wide
```

If your nodes have different hostnames, update the DaemonSet nodeAffinity in the YAML file.

### Permission Errors
Ensure FIO has access to test directory:
```bash
kubectl exec -it <pod-name> -- ls -la /tmp/
```

### Low Performance Results
- Check for other I/O intensive workloads
- Verify storage type (NVMe vs SATA)
- Monitor CPU usage during tests
- Check for storage throttling

## Viewing Results

### Web Dashboard
Results automatically display in the browser with:
- Graphical performance comparisons
- Historical test data
- Node-by-node breakdowns

### Raw JSON Results
```bash
kubectl exec <pod-name> -- cat /tmp/fio-test/summary_report.json
```

### Specific Test Results
```bash
kubectl exec <pod-name> -- cat /tmp/fio-test/sequential_read_results.json
```

## Cleanup

### Option 1: Using Cleanup Script (Recommended)
```bash
./cleanup-fio-benchmark.sh
```

### Option 2: Manual Cleanup
```bash
kubectl delete -f fio-benchmark-test.yaml
```

## Performance Validation Checklist

- [ ] Sequential read > 3,000 MB/s on both worker nodes
- [ ] Sequential write > 2,500 MB/s on both worker nodes
- [ ] Random read 4K > 300,000 IOPS on both worker nodes
- [ ] Random write 4K > 250,000 IOPS on both worker nodes
- [ ] Latency < 1ms for most operations
- [ ] Consistent performance between worker nodes
- [ ] No errors in benchmark logs
- [ ] Web dashboard accessible and functional

## What This Validates

✅ **Storage Performance** - Confirms high-speed storage for containerized workloads  
✅ **I/O Subsystem** - Validates kernel I/O stack performance  
✅ **Container Storage** - Tests containerized storage access  
✅ **Node Consistency** - Ensures uniform performance across worker nodes  
✅ **Resource Isolation** - Verifies storage resources don't interfere  

This test ensures your worker nodes have the high-performance storage required for demanding workloads! 🚀
