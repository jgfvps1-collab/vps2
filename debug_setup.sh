#!/bin/bash
# Debug Version - Kaggle VPS Control Panel Setup Script
# Enhanced with detailed logging and error handling

# Remove 'set -e' to prevent script from exiting on errors
# set -e  # Commented out for debugging

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Enhanced logging functions
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a /kaggle/working/setup_debug.log
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $1" | tee -a /kaggle/working/setup_debug.log
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1" | tee -a /kaggle/working/setup_debug.log
}

debug() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] DEBUG:${NC} $1" | tee -a /kaggle/working/setup_debug.log
}

# Function to run commands with detailed debugging
run_command() {
    local cmd="$1"
    local description="$2"
    local timeout="${3:-300}"  # Default 5 minute timeout
    
    debug "About to run: $cmd"
    log "🔄 $description..."
    
    # Show command being executed
    echo -e "${CYAN}Command: ${NC}$cmd"
    
    # Run command with timeout and capture both stdout and stderr
    if timeout "$timeout" bash -c "$cmd" 2>&1 | tee -a /kaggle/working/setup_debug.log; then
        local exit_code=${PIPESTATUS[0]}
        if [ $exit_code -eq 0 ]; then
            log "✅ $description completed successfully"
            return 0
        else
            error "$description failed with exit code: $exit_code"
            return $exit_code
        fi
    else
        local timeout_code=$?
        if [ $timeout_code -eq 124 ]; then
            error "$description timed out after $timeout seconds"
        else
            error "$description failed with timeout command exit code: $timeout_code"
        fi
        return $timeout_code
    fi
}

# Function to check system resources
check_resources() {
    debug "Checking system resources..."
    echo "💾 Available disk space:"
    df -h | grep -E "(Filesystem|/kaggle)" || df -h
    echo ""
    echo "🧠 Memory status:"
    free -h || echo "Could not get memory info"
    echo ""
    echo "🔄 Process status:"
    ps aux | head -10 || echo "Could not get process info"
    echo ""
}

# Function to check network connectivity
check_network() {
    debug "Checking network connectivity..."
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log "✅ Network connectivity OK"
    else
        warn "Network connectivity issues detected"
    fi
    
    if curl -Is http://archive.ubuntu.com >/dev/null 2>&1; then
        log "✅ Ubuntu repositories accessible"
    else
        warn "Ubuntu repositories may be slow/inaccessible"
    fi
}

# Set environment variables
export USER=root
export HOME=/root
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

debug "Environment variables set: USER=$USER, HOME=$HOME"

# Start debug log
echo "🐛 DEBUG MODE ENABLED - Full logging to /kaggle/working/setup_debug.log"
echo "================================================================" > /kaggle/working/setup_debug.log
echo "Kaggle VPS Setup Debug Log - $(date)" >> /kaggle/working/setup_debug.log
echo "================================================================" >> /kaggle/working/setup_debug.log

log "🎯 Kaggle VPS Control Panel - DEBUG SETUP"
log "============================================="

# Step 0: Initial system check
log "🔍 Initial system diagnostics..."
check_resources
check_network

# Check if we're actually in Kaggle
if [ -d "/kaggle" ]; then
    log "✅ Detected Kaggle environment"
    debug "Kaggle input directories: $(ls -la /kaggle/ 2>/dev/null || echo 'Could not list /kaggle')"
else
    warn "Not running in Kaggle environment - some features may not work"
fi

# Step 1: Create directory structure with error checking
log "📁 Creating directory structure..."
directories=("/kaggle/working/backups" "/kaggle/working/logs" "/kaggle/working/scripts" "/kaggle/working/config" "/kaggle/working/projects" "~/.vnc")

for dir in "${directories[@]}"; do
    debug "Creating directory: $dir"
    if mkdir -p "$dir" 2>/dev/null; then
        debug "✅ Created: $dir"
    else
        error "❌ Failed to create: $dir"
        ls -la "$(dirname "$dir")" 2>/dev/null || echo "Could not list parent directory"
    fi
done

# Step 2: Package installation with detailed debugging
log "📦 Starting package installation with detailed debugging..."

# First, let's see what we're starting with
debug "Current system state:"
debug "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"' 2>/dev/null || echo 'Unknown')"
debug "Kernel: $(uname -r 2>/dev/null || echo 'Unknown')"
debug "Architecture: $(uname -m 2>/dev/null || echo 'Unknown')"
debug "Current user: $(whoami 2>/dev/null || echo 'Unknown')"
debug "Current directory: $(pwd 2>/dev/null || echo 'Unknown')"

# Check initial package manager state
debug "Package manager status:"
debug "dpkg status: $(dpkg --get-selections | wc -l 2>/dev/null || echo 'Unknown') packages"
debug "apt processes: $(ps aux | grep apt | grep -v grep || echo 'None')"

# Kill any existing package manager processes
debug "Checking for running package managers..."
if pgrep apt > /dev/null; then
    warn "Found running apt processes - attempting to clean up"
    pkill -f apt || true
    sleep 5
fi

# Wait for any package manager locks to clear
debug "Waiting for package manager locks..."
for i in {1..10}; do
    if fuser /var/lib/apt/lists/lock >/dev/null 2>&1; then
        debug "Waiting for apt lock to clear... attempt $i/10"
        sleep 10
    else
        debug "No apt lock detected"
        break
    fi
done

# Update package lists with maximum debugging
log "🔄 Updating package lists (this is often where it hangs)..."
debug "About to run: apt-get update"

# Try different approaches to apt update
if ! run_command "apt-get update -o Debug::Acquire::http=true -o Debug::Acquire::https=true" "APT update with debug" 600; then
    warn "Detailed apt update failed, trying basic update..."
    if ! run_command "apt-get update" "Basic APT update" 300; then
        error "All apt update attempts failed"
        debug "Checking apt sources:"
        cat /etc/apt/sources.list 2>/dev/null || echo "Could not read sources.list"
        debug "Checking apt logs:"
        tail -20 /var/log/apt/history.log 2>/dev/null || echo "No apt history log"
        
        # Continue anyway - maybe cached packages will work
        warn "Continuing with potentially stale package cache..."
    fi
fi

# Show what packages are available
debug "Available package info after update:"
debug "Package cache size: $(ls -la /var/lib/apt/lists/ | wc -l 2>/dev/null || echo 'Unknown')"
debug "Sample packages: $(apt-cache search curl | head -3 2>/dev/null || echo 'Could not search packages')"

# Install packages one by one with debugging
log "📦 Installing essential packages individually..."

essential_packages=(
    "curl"
    "wget" 
    "git"
    "vim"
    "nano"
    "htop"
    "tree"
    "python3-pip"
    "tmux"
    "screen"
    "zip"
    "unzip"
    "build-essential"
)

for package in "${essential_packages[@]}"; do
    debug "Installing package: $package"
    
    # Check if package is already installed
    if dpkg -l | grep -q "^ii  $package "; then
        debug "✅ $package already installed"
        continue
    fi
    
    # Check if package exists in repositories
    if ! apt-cache show "$package" >/dev/null 2>&1; then
        warn "Package $package not found in repositories"
        continue
    fi
    
    # Install the package
    if run_command "apt-get install -y -q $package" "Installing $package" 180; then
        debug "✅ $package installed successfully"
    else
        error "❌ Failed to install $package"
        # Show detailed error info
        debug "Checking if $package is partially installed:"
        dpkg -l | grep "$package" || echo "Not found in dpkg list"
        
        # Try to fix broken packages
        debug "Attempting to fix broken packages..."
        run_command "apt-get install -f -y" "Fix broken packages" 120
    fi
done

# Check what we successfully installed
log "🔍 Package installation summary:"
installed_count=0
for package in "${essential_packages[@]}"; do
    if which "$package" >/dev/null 2>&1 || dpkg -l | grep -q "^ii  $package "; then
        debug "✅ $package: Available"
        ((installed_count++))
    else
        debug "❌ $package: Missing"
    fi
done

log "📊 Successfully installed: $installed_count/${#essential_packages[@]} essential packages"

# Continue with VNC packages if essential packages mostly succeeded
if [ $installed_count -gt 8 ]; then
    log "📦 Installing VNC and desktop packages..."
    
    vnc_packages=(
        "tightvncserver"
        "xfce4"
        "xfce4-goodies"
        "firefox"
    )
    
    for package in "${vnc_packages[@]}"; do
        if run_command "apt-get install -y -q $package" "Installing VNC package: $package" 300; then
            debug "✅ $package installed"
        else
            warn "❌ Failed to install $package - VNC may have issues"
        fi
    done
else
    error "Too many essential packages failed - skipping VNC installation"
fi

# Install web services
log "📦 Installing web services..."
web_packages=("novnc" "websockify")

for package in "${web_packages[@]}"; do
    run_command "apt-get install -y -q $package" "Installing web package: $package" 180
done

# Check final package state
log "📊 Final package installation status:"
debug "Total installed packages: $(dpkg --get-selections | grep -c install 2>/dev/null || echo 'Unknown')"
debug "Package manager processes: $(ps aux | grep apt | grep -v grep || echo 'None')"

# Step 3: Python packages with debugging
log "🐍 Installing Python packages with debugging..."

# Check Python status first
debug "Python environment:"
debug "Python version: $(python3 --version 2>&1 || echo 'Python3 not found')"
debug "Pip version: $(pip3 --version 2>&1 || echo 'Pip not found')"
debug "Python path: $(which python3 2>/dev/null || echo 'Not found')"

if which pip3 >/dev/null 2>&1; then
    # Upgrade pip first
    if run_command "pip3 install --upgrade pip" "Upgrading pip" 120; then
        debug "Pip upgraded successfully"
    else
        warn "Pip upgrade failed - continuing with existing version"
    fi
    
    # Install Python packages
    python_packages=("flask" "flask-cors" "psutil" "requests")
    
    for package in "${python_packages[@]}"; do
        if run_command "pip3 install $package" "Installing Python package: $package" 120; then
            debug "✅ $package installed"
        else
            warn "❌ Failed to install $package"
        fi
    done
else
    error "Pip not available - skipping Python packages"
fi

# Continue with the rest of the setup...
log "🎨 Creating control panel (simplified for debugging)..."

# Create a minimal control panel for testing
cat > /kaggle/working/control_panel.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Kaggle VPS Debug</title></head>
<body style="font-family: Arial; padding: 20px; background: #f0f0f0;">
    <h1>🐛 Kaggle VPS Debug Panel</h1>
    <p><strong>Status:</strong> Setup script reached control panel creation!</p>
    <div style="background: white; padding: 15px; border-radius: 5px; margin: 10px 0;">
        <h3>🔍 Debug Information</h3>
        <p>Setup time: <span id="time"></span></p>
        <p>This means the package installation phase completed!</p>
    </div>
    <script>
        document.getElementById('time').innerText = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

log "✅ Basic control panel created"

# Create minimal backend
log "🐍 Creating minimal backend for testing..."

cat > /kaggle/working/test_backend.py << 'EOF'
#!/usr/bin/env python3
try:
    from flask import Flask, send_file
    app = Flask(__name__)
    
    @app.route('/')
    def index():
        return send_file('control_panel.html')
    
    if __name__ == '__main__':
        print("🚀 Starting test backend on port 5000")
        app.run(host='0.0.0.0', port=5000, debug=True)
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Flask not properly installed")
except Exception as e:
    print(f"❌ Error: {e}")
EOF

log "✅ Test backend created"

# Final debug summary
log "🔍 Setup Debug Summary:"
log "================================"

# Show what we accomplished
debug "Files created:"
ls -la /kaggle/working/ 2>/dev/null || echo "Could not list working directory"

debug "System status:"
check_resources

# Show debug log location
log "📋 Full debug log saved to: /kaggle/working/setup_debug.log"
log "📊 View with: cat /kaggle/working/setup_debug.log"

# Test if we can start the backend
log "🧪 Testing backend startup..."
cd /kaggle/working 2>/dev/null || log "Could not change to working directory"

if which python3 >/dev/null && [ -f "test_backend.py" ]; then
    log "🚀 Starting test backend (will run for 30 seconds for testing)..."
    timeout 30 python3 test_backend.py &
    backend_pid=$!
    
    sleep 5
    if kill -0 $backend_pid 2>/dev/null; then
        log "✅ Backend started successfully!"
        log "🌐 Test URL: http://localhost:5000"
        
        # Test if it responds
        if curl -s http://localhost:5000 >/dev/null 2>&1; then
            log "✅ Backend is responding to requests"
        else
            warn "Backend started but not responding to HTTP requests"
        fi
    else
        warn "Backend failed to start or crashed"
    fi
else
    error "Cannot test backend - missing Python3 or test file"
fi

log "🎯 DEBUG SETUP COMPLETE!"
log "========================"
log "📋 Check /kaggle/working/setup_debug.log for detailed information"
log "🔧 If setup failed, the log will show exactly where and why"

# Keep debug info accessible
echo ""
echo "🐛 DEBUG COMMANDS:"
echo "   cat /kaggle/working/setup_debug.log    # Full debug log"
echo "   tail -50 /kaggle/working/setup_debug.log  # Last 50 lines"
echo "   ls -la /kaggle/working/                # Created files"
echo "   df -h                                  # Disk usage"
echo "   ps aux | grep python                  # Python processes"
echo ""
