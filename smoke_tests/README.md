# RKE2 Smoke Tests

This directory contains smoke tests to validate your RKE2 cluster functionality after deployment.

## Available Tests

### 1. [Webapp Deployment Test](./webapp_deployment_test/)
**Purpose**: Validates core Kubernetes functionality  
**Tests**: Pod scheduling, service networking, container runtime, DNS, load balancing  
**Time**: ~2-3 minutes  
**Access**: Interactive web interface  

```bash
cd webapp_deployment_test
# Follow README.md instructions
```

### 2. [Disk Performance Test](./disk_performance_test/)
**Purpose**: Validates storage I/O performance on worker nodes  
**Tests**: Sequential R/W, Random 4K IOPS, mixed workloads, latency  
**Time**: ~5-10 minutes per node  
**Access**: Web dashboard with real-time results  
**Configuration**: Hardcoded for specific node IPs (customizable)

```bash
cd disk_performance_test
./deploy-fio-benchmark.sh
```

#### **Customizing Node IPs**
To target different nodes, edit these files:

**1. Update `deploy-fio-benchmark.sh`** (line 47):
```bash
# Change these IPs to your worker node IPs
NODE_IPS="10.14.100.2 10.14.100.3"
```

**2. Update `fio-benchmark-test.yaml`** (JavaScript section, around line 340):
```javascript
let clusterNodes = [
    {
        name: 'worker-node-1',
        ip: '10.14.100.2',  // Your first worker node IP
        type: 'Worker Node',
        storage: 'Local Storage',
        podName: 'fio-benchmark-worker-1'
    },
    {
        name: 'worker-node-2', 
        ip: '10.14.100.3',  // Your second worker node IP
        type: 'Worker Node',
        storage: 'Local Storage',
        podName: 'fio-benchmark-worker-2'
    }
];
```

**3. Update DaemonSet Target Nodes** (YAML section, around line 1220):
```yaml
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: kubernetes.io/hostname
        operator: In
        values:
        - worker-node-1  # Your actual node hostnames
        - worker-node-2  # Your actual node hostnames
```

#### **Adding More Nodes**
To test additional nodes:
1. Add IPs to `NODE_IPS` in deploy script
2. Add node objects to `clusterNodes` array in YAML
3. Add hostnames to DaemonSet `values` list
4. Ensure node names match actual Kubernetes node hostnames

#### **Test Features**
- 🎯 **CrystalDiskMark-style benchmarks**: Sequential, Random 4K, Mixed workloads
- 📊 **Real-time dashboard**: Live results with performance comparisons  
- ⚙️ **Configurable test sizes**: 0.5GB (fast) to 8GB+ (thorough)
- 🔄 **Multiple test runs**: Compare performance across runs
- 📋 **Detailed metrics**: Bandwidth (MB/s), IOPS, Latency measurements

## Test Categories

### 🚀 **Core Functionality Tests**
- Webapp Deployment Test ✅
- Disk Performance Test ✅
- *More tests coming soon...*

### 🔒 **Security Tests** 
- *Coming soon...*

### 🌐 **Network Tests**
- *Coming soon...*

### 📊 **Performance Tests**
- **Disk Performance Test** ✅ - CrystalDiskMark-style I/O benchmarks with web dashboard
- *CPU Performance Test - Coming soon...*
- *Network Performance Test - Coming soon...*
- *Memory Performance Test - Coming soon...*

## Detailed Usage: Disk Performance Test

### **Prerequisites**
- RKE2 cluster with worker nodes
- `kubectl` configured with cluster access
- Worker nodes with sufficient disk space (minimum 2GB recommended)

### **Quick Start**
```bash
cd smoke_tests/disk_performance_test
./deploy-fio-benchmark.sh
```

### **Configuration Steps**

#### **1. Identify Your Worker Node IPs**
```bash
kubectl get nodes -o wide
# Note the INTERNAL-IP addresses of your worker nodes
```

#### **2. Update Node Configuration**
Edit the following files to match your environment:

**File: `deploy-fio-benchmark.sh`**  
Line 47: Update with your worker node IPs
```bash
NODE_IPS="YOUR_NODE_1_IP YOUR_NODE_2_IP"
```

**File: `fio-benchmark-test.yaml`**  
JavaScript section (~line 340): Update cluster nodes array
```javascript
let clusterNodes = [
    {
        name: 'your-node-1-name',
        ip: 'YOUR_NODE_1_IP',
        type: 'Worker Node',
        storage: 'Local Storage',
        podName: 'fio-benchmark-worker-1'
    }
    // Add more nodes as needed
];
```

DaemonSet section (~line 1220): Update node selector
```yaml
values:
- your-actual-node-hostname-1
- your-actual-node-hostname-2
```

#### **3. Deploy and Access**
```bash
# Deploy the benchmark infrastructure
./deploy-fio-benchmark.sh

# Access dashboard (URLs will be shown in output)
# Example: http://10.14.100.2:30080
```

### **Customization Options**

#### **Test Size Configuration**
- **Fast Tests**: 0.5GB (30-60 seconds per node)
- **Standard Tests**: 1-2GB (2-4 minutes per node)  
- **Thorough Tests**: 4-8GB (5-10 minutes per node)
- **Stress Tests**: 16GB+ (15+ minutes per node)

#### **Node Selection Strategies**
- **Specific Nodes**: Target exact worker nodes by hostname
- **All Workers**: Remove hostname restriction to test all workers
- **Subset Testing**: Select representative nodes for large clusters

### **Benchmark Types Explained**
1. **Sequential Read** (1MB blocks): Large file read performance
2. **Sequential Write** (1MB blocks): Large file write performance  
3. **Random Read 4K**: Database read workload simulation
4. **Random Write 4K**: Database write workload simulation
5. **Mixed Random 4K**: Real-world mixed workload (70% read, 30% write)

### **Interpreting Results**
- **Sequential**: Higher MB/s = Better for large files, streaming
- **Random IOPS**: Higher values = Better for databases, applications
- **Latency**: Lower ms = More responsive storage
- **Comparison**: Compare results across nodes to identify performance differences

### **Troubleshooting**
```bash
# Check pod status
kubectl get pods -l app=fio-benchmark

# View pod logs
kubectl logs -l app=fio-benchmark

# Manual benchmark execution
kubectl exec -it <pod-name> -- /tmp/run-benchmarks.sh

# Cleanup
kubectl delete -f fio-benchmark-test.yaml
```

---

## Running All Tests

```bash
# Navigate to each test directory and run individual tests
# A test runner script will be added later
```

## Test Results

After running tests, you should see:
- ✅ **PASS**: All components working correctly
- ⚠️ **WARN**: Minor issues that don't affect functionality  
- ❌ **FAIL**: Critical issues requiring attention

## Contributing New Tests

When adding new smoke tests:

1. Create a new directory under `smoke_tests/`
2. Include a comprehensive `README.md`
3. Provide cleanup instructions
4. Add entry to this main README
5. Test on a fresh cluster deployment

## Quick Health Check

For a rapid cluster health validation, start with:
1. **Webapp Deployment Test** - Validates core functionality
2. **Disk Performance Test** - Validates storage performance
3. *Additional tests as they become available*

## Quick Reference Commands

### **Disk Performance Test**
```bash
# Deploy
cd smoke_tests/disk_performance_test && ./deploy-fio-benchmark.sh

# Check status  
kubectl get pods,svc,ds -l app=fio-benchmark

# Manual run
kubectl exec -it $(kubectl get pods -l app=fio-benchmark -o name | head -1) -- /tmp/run-benchmarks.sh

# Cleanup
kubectl delete -f fio-benchmark-test.yaml
```

### **Webapp Test**
```bash
# Deploy
cd smoke_tests/webapp_deployment_test && ./deploy-test-webapp.sh

# Check status
kubectl get pods,svc -l app=test-webapp

# Cleanup  
kubectl delete -f test-webapp.yaml
```

---

These smoke tests ensure your RKE2 cluster is production-ready! 🎯
