#!/bin/bash
# Kaggle Environment Diagnostics Script
# Run this BEFORE the main setup to identify potential issues

echo "🔍 KAGGLE ENVIRONMENT DIAGNOSTICS"
echo "================================="
echo "Timestamp: $(date)"
echo ""

# Basic system info
echo "🖥️  SYSTEM INFORMATION:"
echo "   OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')"
echo "   Kernel: $(uname -r)"
echo "   Architecture: $(uname -m)"
echo "   Hostname: $(hostname)"
echo "   Current user: $(whoami)"
echo "   Home directory: $HOME"
echo "   Current directory: $(pwd)"
echo ""

# Resource check
echo "💾 RESOURCE STATUS:"
echo "   Memory:"
free -h
echo ""
echo "   Disk space:"
df -h
echo ""
echo "   CPU info:"
nproc && echo "CPU cores available"
echo ""

# Network diagnostics
echo "🌐 NETWORK DIAGNOSTICS:"
echo "   Internet connectivity:"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "   ✅ Can reach internet (8.8.8.8)"
else
    echo "   ❌ Cannot reach internet"
fi

echo "   Ubuntu repositories:"
if curl -Is --connect-timeout 10 http://archive.ubuntu.com >/dev/null 2>&1; then
    echo "   ✅ Ubuntu repos accessible"
else
    echo "   ❌ Ubuntu repos not accessible or slow"
fi

echo "   DNS resolution:"
if nslookup google.com >/dev/null 2>&1; then
    echo "   ✅ DNS working"
else
    echo "   ❌ DNS issues detected"
fi
echo ""

# Package manager status
echo "📦 PACKAGE MANAGER STATUS:"
echo "   APT lock status:"
if fuser /var/lib/apt/lists/lock >/dev/null 2>&1; then
    echo "   ⚠️  APT is locked by another process"
    echo "   Processes using APT:"
    fuser -v /var/lib/apt/lists/lock 2>&1 || echo "   Could not identify process"
else
    echo "   ✅ APT is available"
fi

echo "   APT processes:"
apt_processes=$(ps aux | grep -E "(apt|dpkg)" | grep -v grep)
if [ -n "$apt_processes" ]; then
    echo "   ⚠️  Found running package manager processes:"
    echo "$apt_processes"
else
    echo "   ✅ No blocking package manager processes"
fi

echo "   Package cache status:"
cache_files=$(ls /var/lib/apt/lists/ 2>/dev/null | wc -l)
echo "   Cache files: $cache_files"
if [ "$cache_files" -lt 10 ]; then
    echo "   ⚠️  Package cache appears empty or minimal"
else
    echo "   ✅ Package cache appears populated"
fi
echo ""

# Permissions check
echo "🔐 PERMISSIONS CHECK:"
echo "   Root access:"
if [ "$EUID" -eq 0 ]; then
    echo "   ✅ Running as root"
else
    echo "   ❌ Not running as root (may cause issues)"
fi

echo "   Write permissions:"
test_dirs=("/kaggle/working" "/tmp" "/var/log")
for dir in "${test_dirs[@]}"; do
    if [ -w "$dir" ]; then
        echo "   ✅ Can write to $dir"
    else
        echo "   ❌ Cannot write to $dir"
    fi
done
echo ""

# Python environment
echo "🐍 PYTHON ENVIRONMENT:"
if which python3 >/dev/null; then
    echo "   ✅ Python3: $(python3 --version)"
    echo "   Python3 path: $(which python3)"
else
    echo "   ❌ Python3 not found"
fi

if which pip3 >/dev/null; then
    echo "   ✅ Pip3: $(pip3 --version 2>&1 | head -1)"
    echo "   Pip3 path: $(which pip3)"
else
    echo "   ❌ Pip3 not found"
fi

echo "   Python packages installed:"
pip3 list 2>/dev/null | wc -l && echo "packages" || echo "Could not count packages"
echo ""

# Kaggle-specific checks
echo "🎯 KAGGLE-SPECIFIC CHECKS:"
echo "   Kaggle environment:"
if [ -d "/kaggle" ]; then
    echo "   ✅ Running in Kaggle environment"
    echo "   Kaggle directories:"
    ls -la /kaggle/ 2>/dev/null | head -10
else
    echo "   ❌ Not in Kaggle environment"
fi

echo "   GPU availability:"
if which nvidia-smi >/dev/null 2>&1; then
    echo "   ✅ NVIDIA drivers available"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "   GPU query failed"
else
    echo "   ❌ No GPU/NVIDIA drivers"
fi

echo "   Input datasets:"
if [ -d "/kaggle/input" ]; then
    input_count=$(ls /kaggle/input 2>/dev/null | wc -l)
    echo "   📂 Found $input_count input datasets"
    if [ "$input_count" -gt 0 ]; then
        echo "   Dataset names:"
        ls /kaggle/input 2>/dev/null | head -5
    fi
else
    echo "   📂 No input datasets directory"
fi
echo ""

# Common issues check
echo "🚨 COMMON ISSUES CHECK:"
issues_found=0

# Check for space issues
available_space=$(df /kaggle/working 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
if [ "$available_space" -lt 1000000 ]; then  # Less than ~1GB
    echo "   ⚠️  Low disk space detected"
    ((issues_found++))
fi

# Check for memory issues
available_memory=$(free | grep '^Mem:' | awk '{print $7}' || echo "0")
if [ "$available_memory" -lt 1000000 ]; then  # Less than ~1GB
    echo "   ⚠️  Low available memory"
    ((issues_found++))
fi

# Check for long-running processes that might interfere
long_processes=$(ps aux | awk '$10 > 60 {print $11}' | grep -E "(apt|dpkg|pip|curl|wget)" | head -3)
if [ -n "$long_processes" ]; then
    echo "   ⚠️  Long-running processes detected:"
    echo "$long_processes"
    ((issues_found++))
fi

if [ "$issues_found" -eq 0 ]; then
    echo "   ✅ No obvious issues detected"
fi
echo ""

# Recommendations
echo "💡 RECOMMENDATIONS:"
if [ "$issues_found" -gt 0 ]; then
    echo "   🚨 Issues detected - setup may fail or be slow"
    echo "   • Wait a few minutes and try again"
    echo "   • Restart the Kaggle kernel"
    echo "   • Check internet connection"
else
    echo "   ✅ System looks good for setup"
    echo "   • You can proceed with the main setup script"
fi

echo ""
echo "🔧 SUGGESTED NEXT STEPS:"
echo "   1. If issues found: restart kernel and run diagnostics again"
echo "   2. If all good: proceed with main setup script"
echo "   3. If setup fails: compare before/after diagnostics"
echo ""

# Timing test
echo "⏱️  TIMING TEST:"
echo "   Testing package manager response time..."
start_time=$(date +%s)
apt-cache search test >/dev/null 2>&1
end_time=$(date +%s)
duration=$((end_time - start_time))
echo "   APT response time: ${duration}s"

if [ "$duration" -gt 30 ]; then
    echo "   ⚠️  Slow package manager - setup will take longer"
else
    echo "   ✅ Package manager responding normally"
fi

echo ""
echo "🎯 DIAGNOSTICS COMPLETE"
echo "======================="
echo "Save this output to compare with post-setup results"
