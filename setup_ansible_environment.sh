#!/bin/bash
# Ansible SSH Connection Optimization Environment Setup
# Source this script before running Ansible deployments for maximum connection stability
# Usage: source ./setup_ansible_environment.sh

echo "🔧 Setting up Ansible environment for optimal SSH connection stability..."

# Core Ansible SSH Configuration
export ANSIBLE_SSH_RETRIES=5
export ANSIBLE_TIMEOUT=60
export ANSIBLE_COMMAND_TIMEOUT=60
export ANSIBLE_CONNECT_TIMEOUT=30
export ANSIBLE_SSH_CONTROL_PATH_DIR="/tmp/.ansible-cp"
export ANSIBLE_SSH_PIPELINING=True
export ANSIBLE_PARAMIKO_LOOK_FOR_KEYS=False
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_GATHERING_TIMEOUT=60
export ANSIBLE_FACT_CACHING_TIMEOUT=86400

# Connection resilience settings
export ANSIBLE_SSH_ARGS="-o ControlMaster=auto -o ControlPersist=300s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes -o Compression=yes -o ConnectionAttempts=3"

# Performance optimization for poor connections
export ANSIBLE_FORKS=5  # Reduce for very poor connections
export ANSIBLE_POLL_INTERVAL=2
export ANSIBLE_GATHERING=smart
export ANSIBLE_FACT_CACHING=memory

# Retry and recovery settings
export ANSIBLE_RETRY_FILES_ENABLED=True
export ANSIBLE_RETRY_FILES_SAVE_PATH="./.retry"

# Debugging and output
export ANSIBLE_STDOUT_CALLBACK=yaml
export ANSIBLE_BIN_ANSIBLE_CALLBACKS=True

# Ensure control path directory exists
mkdir -p /tmp/.ansible-cp

echo "✅ Ansible environment optimized for SSH connection resilience!"
echo ""
echo "🚀 Enhanced settings applied:"
echo "   - SSH retries: 5 attempts"
echo "   - Connection timeout: 30 seconds"
echo "   - Command timeout: 60 seconds" 
echo "   - SSH keepalive: every 60 seconds"
echo "   - Connection multiplexing: 5 minutes"
echo "   - Parallel forks: 5 (reduced for stability)"
echo "   - Retry files: enabled"
echo ""
echo "📋 Quick commands:"
echo "   Test connections: ./test_ssh_connections.sh"
echo "   Run deployment: ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml"
echo "   Retry failed hosts: ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml --limit @playbooks/playbook.retry"
echo "   Verbose troubleshooting: ansible-playbook -vvv -i inventories/hosts.ini playbooks/playbook.yml"
echo ""
echo "💡 For extremely poor connections, reduce forks further:"
echo "   export ANSIBLE_FORKS=1"
