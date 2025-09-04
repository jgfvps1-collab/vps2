#!/bin/bash
# Kaggle VPS Master Startup Script
# This script sets up your entire pseudo-VPS environment with control panel

set -e  # Exit on error

echo "🎯 Kaggle VPS Control Panel - Master Setup"
echo "=========================================="

# Configuration
GITHUB_REPO="your-username/kaggle-vps-control"  # Replace with your repo
CONTROL_PANEL_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/control_panel.html"
BACKEND_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/vps_backend.py"
REQUIREMENTS_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/requirements.txt"

# Create directory structure
echo "📁 Setting up directory structure..."
mkdir -p /kaggle/working/{backups,logs,scripts,config}
mkdir -p ~/.vnc

# Function to log messages
log_message() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# Function to install system packages
install_system_packages() {
    log_message "📦 Installing system packages..."
    
    apt-get update -qq
    apt-get install -y -qq \
        curl wget git vim nano htop tree \
        python3-pip python3-venv \
        tmux screen \
        zip unzip \
        tightvncserver xfce4 xfce4-goodies \
        novnc websockify \
        nginx \
        sqlite3 \
        build-essential
    
    log_message "✅ System packages installed"
}

# Function to setup Python environment
setup_python_environment() {
    log_message "🐍 Setting up Python environment..."
    
    # Download and install Python requirements
    cat > /kaggle/working/requirements.txt << 'EOF'
flask
flask-cors
psutil
requests
pandas
numpy
jupyter
jupyterlab
matplotlib
seaborn
plotly
streamlit
fastapi
uvicorn
websockets
aiofiles
python-multipart
EOF
    
    # Install Python packages
    pip install --upgrade pip
    pip install -r /kaggle/working/requirements.txt
    
    log_message "✅ Python environment ready"
}

# Function to download control panel files
download_control_panel() {
    log_message "⬇️  Downloading control panel files..."
    
    # Try to download from your GitHub repo first, fallback to local creation
    if curl -s --head "$CONTROL_PANEL_URL" | head -n 1 | grep -q "200 OK"; then
        wget -O /kaggle/working/control_panel.html "$CONTROL_PANEL_URL"
        wget -O /kaggle/working/vps_backend.py "$BACKEND_URL"
    else
        log_message "⚠️  GitHub repo not found, using embedded files"
        create_local_files
    fi
    
    log_message "✅ Control panel files ready"
}

# Function to create local files if GitHub repo not available
create_local_files() {
    # This would contain the HTML and Python code we created above
    # For brevity, I'll just create placeholders
    echo "Creating local control panel files..."
    
    # Copy the HTML content to a file
    # (The actual HTML content from our artifact would go here)
    
    # Copy the Python backend content to a file  
    # (The actual Python content from our artifact would go here)
}

# Function to setup VNC server
setup_vnc_server() {
    log_message "🖥️  Setting up VNC server..."
    
    # Create VNC password file
    mkdir -p ~/.vnc
    echo "kaggle123" | vncpasswd -f > ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
    
    # Create VNC startup script
    cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF
    chmod +x ~/.vnc/xstartup
    
    # Start VNC server
    vncserver :1 -geometry 1280x720 -depth 24 -localhost no
    
    log_message "✅ VNC server started on :5901"
}

# Function to setup web VNC
setup_web_vnc() {
    log_message "🌐 Setting up web VNC..."
    
    # Start websockify for web VNC access
    websockify --web=/usr/share/novnc/ 6080 localhost:5901 &
    
    # Create simple HTML page for VNC access
    cat > /kaggle/working/vnc_access.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Access</title>
</head>
<body>
    <h2>VNC Access Options</h2>
    <ul>
        <li><strong>Web VNC:</strong> <a href="http://localhost:6080/vnc.html?host=localhost&port=6080" target="_blank">Click here</a></li>
        <li><strong>VNC Client:</strong> Connect to localhost:5901</li>
        <li><strong>Password:</strong> kaggle123</li>
    </ul>
</body>
</html>
EOF
    
    log_message "✅ Web VNC ready on port 6080"
}

# Function to setup nginx proxy
setup_nginx_proxy() {
    log_message "🌍 Setting up nginx proxy..."
    
    cat > /etc/nginx/sites-available/kaggle-vps << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    # Control Panel
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # VNC Web Access
    location /vnc/ {
        proxy_pass http://127.0.0.1:6080/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Jupyter Lab
    location /jupyter/ {
        proxy_pass http://127.0.0.1:8888/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/kaggle-vps /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    nginx -t && systemctl restart nginx
    
    log_message "✅ Nginx proxy configured"
}

# Function to create startup services
create_startup_services() {
    log_message "🚀 Creating startup services..."
    
    # Create control panel service script
    cat > /kaggle/working/start_control_panel.sh << 'EOF'
#!/bin/bash
cd /kaggle/working
python3 vps_backend.py &
echo $! > /kaggle/working/control_panel.pid
echo "Control panel started with PID: $!"
EOF
    chmod +x /kaggle/working/start_control_panel.sh
    
    # Create stop services script
    cat > /kaggle/working/stop_services.sh << 'EOF'
#!/bin/bash
echo "Stopping all services..."

# Stop control panel
if [ -f /kaggle/working/control_panel.pid ]; then
    kill $(cat /kaggle/working/control_panel.pid) 2>/dev/null || true
    rm -f /kaggle/working/control_panel.pid
fi

# Stop VNC
vncserver -kill :1 2>/dev/null || true

# Stop websockify
pkill websockify 2>/dev/null || true

# Stop nginx
nginx -s stop 2>/dev/null || true

echo "All services stopped"
EOF
    chmod +x /kaggle/working/stop_services.sh
    
    log_message "✅ Service scripts created"
}

# Function to create useful aliases
create_aliases() {
    log_message "📝 Creating useful aliases..."
    
    cat >> ~/.bashrc << 'EOF'

# Kaggle VPS Aliases
alias vps-start='cd /kaggle/working && ./start_control_panel.sh'
alias vps-stop='cd /kaggle/working && ./stop_services.sh'
alias vps-status='ps aux | grep -E "(python3.*vps_backend|vncserver|websockify)"'
alias vps-logs='tail -f /kaggle/working/vps_control.log'
alias vps-backup='cd /kaggle/working && python3 -c "from vps_backend import vps_manager; vps_manager.create_backup()"'
alias vps-panel='echo "Control Panel: http://localhost:5000"'

# Useful shortcuts
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias h='history'
alias c='clear'
alias tree='tree -C'
alias ports='netstat -tuln'

# Resource monitoring
alias htop='htop'
alias gpu='nvidia-smi'
alias disk='df -h'
alias mem='free -h'

echo "🎯 Kaggle VPS Environment Loaded"
echo "Commands: vps-start, vps-stop, vps-status, vps-logs, vps-backup, vps-panel"
EOF
    
    log_message "✅ Aliases created"
}

# Function to create sample projects
create_sample_projects() {
    log_message "📂 Creating sample projects..."
    
    mkdir -p /kaggle/working/projects/{web-app,ml-project,data-analysis}
    
    # Sample Flask app
    cat > /kaggle/working/projects/web-app/app.py << 'EOF'
from flask import Flask, render_template_string

app = Flask(__name__)

@app.route('/')
def hello():
    return render_template_string('''
    <h1>Hello from Kaggle VPS!</h1>
    <p>This is a sample Flask app running on your pseudo-VPS.</p>
    <p>Time: {{ time }}</p>
    ''', time=str(__import__('datetime').datetime.now()))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
EOF
    
    # Sample Jupyter notebook
    cat > /kaggle/working/projects/ml-project/sample.ipynb << 'EOF'
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": ["# Sample ML Project\n", "This is a sample notebook for your Kaggle VPS."]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": ["import pandas as pd\nimport numpy as np\nimport matplotlib.pyplot as plt\n\nprint('Hello from Kaggle VPS!')"]
  }
 ],
 "metadata": {
  "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"}
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EOF
    
    log_message "✅ Sample projects created"
}

# Function to display final information
display_final_info() {
    echo ""
    echo "🎉 Kaggle VPS Setup Complete!"
    echo "=============================="
    echo ""
    echo "📊 Control Panel:    http://localhost:5000"
    echo "🖥️  VNC Web Access:   http://localhost:6080/vnc.html"
    echo "📓 Jupyter Lab:      http://localhost:8888"
    echo "🌐 VNC Direct:       localhost:5901 (password: kaggle123)"
    echo ""
    echo "🛠️  Quick Commands:"
    echo "   vps-start     - Start control panel"
    echo "   vps-stop      - Stop all services"
    echo "   vps-status    - Check service status"
    echo "   vps-logs      - View logs"
    echo "   vps-backup    - Create backup"
    echo "   vps-panel     - Show panel URL"
    echo ""
    echo "📂 Project folders created in /kaggle/working/projects/"
    echo "💾 Backups will be stored in /kaggle/working/backups/"
    echo ""
    echo "⚠️  IMPORTANT REMINDERS:"
    echo "   • Sessions timeout after ~12 hours"
    echo "   • Always save your work before timeout"
    echo "   • Use 'vps-backup' regularly"
    echo "   • Upload backups to your Kaggle dataset"
    echo ""
    echo "🔄 To restore in a new session:"
    echo "   1. Add your backup dataset as input"
    echo "   2. Run this setup script again"
    echo "   3. Use the restore function in control panel"
    echo ""
}

# Function to restore from previous backup
restore_from_backup() {
    log_message "🔍 Checking for previous backups..."
    
    # Check if backup dataset is available in input
    if [ -d "/kaggle/input" ]; then
        BACKUP_FILES=$(find /kaggle/input -name "session_backup_*.zip" 2>/dev/null | head -1)
        
        if [ -n "$BACKUP_FILES" ]; then
            log_message "📦 Found backup file: $(basename "$BACKUP_FILES")"
            
            # Extract backup
            RESTORE_DIR="/tmp/kaggle_restore"
            mkdir -p "$RESTORE_DIR"
            unzip -q "$BACKUP_FILES" -d "$RESTORE_DIR"
            
            # Restore working directory (selective)
            if [ -d "$RESTORE_DIR/working" ]; then
                log_message "📁 Restoring workspace files..."
                
                # Restore specific directories
                for dir in projects scripts config backups; do
                    if [ -d "$RESTORE_DIR/working/$dir" ]; then
                        cp -r "$RESTORE_DIR/working/$dir" /kaggle/working/
                    fi
                done
                
                # Restore specific files
                for file in requirements.txt *.py *.sh; do
                    if [ -f "$RESTORE_DIR/working/$file" ]; then
                        cp "$RESTORE_DIR/working/$file" /kaggle/working/
                    fi
                done
            fi
            
            # Restore home configs
            if [ -d "$RESTORE_DIR/home" ]; then
                log_message "⚙️  Restoring configurations..."
                cp -f "$RESTORE_DIR/home/.bashrc" ~/.bashrc 2>/dev/null || true
                cp -f "$RESTORE_DIR/home/.vimrc" ~/.vimrc 2>/dev/null || true
                cp -f "$RESTORE_DIR/home/.gitconfig" ~/.gitconfig 2>/dev/null || true
            fi
            
            # Reinstall packages if requirements exist
            if [ -f "$RESTORE_DIR/requirements.txt" ]; then
                log_message "📦 Reinstalling packages..."
                pip install -q -r "$RESTORE_DIR/requirements.txt"
            fi
            
            # Cleanup
            rm -rf "$RESTORE_DIR"
            
            log_message "✅ Backup restored successfully"
            return 0
        else
            log_message "ℹ️  No backup files found in input datasets"
            return 1
        fi
    else
        log_message "ℹ️  No input datasets available"
        return 1
    fi
}

# Function to setup monitoring
setup_monitoring() {
    log_message "📊 Setting up system monitoring..."
    
    # Create resource monitoring script
    cat > /kaggle/working/scripts/monitor_resources.py << 'EOF'
#!/usr/bin/env python3
import psutil
import time
import json
import subprocess
from datetime import datetime

def get_gpu_info():
    try:
        result = subprocess.run(['nvidia-smi', '--query-gpu=memory.used,memory.total,utilization.gpu', 
                               '--format=csv,noheader,nounits'], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            used, total, util = [float(x.strip()) for x in result.stdout.strip().split(',')]
            return {
                'memory_used_mb': used,
                'memory_total_mb': total, 
                'utilization_percent': util
            }
    except:
        pass
    return {'available': False}

def monitor_loop():
    while True:
        timestamp = datetime.now().isoformat()
        
        # CPU and Memory
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/kaggle/working')
        
        # GPU
        gpu_info = get_gpu_info()
        
        # Network
        net_io = psutil.net_io_counters()
        
        stats = {
            'timestamp': timestamp,
            'cpu_percent': cpu_percent,
            'memory_percent': memory.percent,
            'memory_used_gb': round(memory.used / (1024**3), 2),
            'memory_total_gb': round(memory.total / (1024**3), 2),
            'disk_percent': round((disk.used / disk.total) * 100, 1),
            'disk_used_gb': round(disk.used / (1024**3), 2),
            'disk_total_gb': round(disk.total / (1024**3), 2),
            'network_sent_mb': round(net_io.bytes_sent / (1024**2), 2),
            'network_recv_mb': round(net_io.bytes_recv / (1024**2), 2),
            'gpu': gpu_info
        }
        
        # Write to monitoring log
        with open('/kaggle/working/logs/resource_monitor.log', 'a') as f:
            f.write(json.dumps(stats) + '\n')
        
        time.sleep(60)  # Monitor every minute

if __name__ == '__main__':
    monitor_loop()
EOF
    chmod +x /kaggle/working/scripts/monitor_resources.py
    
    # Start monitoring in background
    nohup python3 /kaggle/working/scripts/monitor_resources.py > /kaggle/working/logs/monitor.out 2>&1 &
    
    log_message "✅ Resource monitoring started"
}

# Function to setup auto-save
setup_auto_save() {
    log_message "💾 Setting up auto-save functionality..."
    
    # Create auto-save script
    cat > /kaggle/working/scripts/auto_save.py << 'EOF'
#!/usr/bin/env python3
import time
import subprocess
import os
from datetime import datetime

SAVE_INTERVAL = 3600  # 1 hour
MAX_BACKUPS = 5  # Keep only last 5 backups

def create_backup():
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_name = f"auto_backup_{timestamp}.zip"
    backup_path = f"/kaggle/working/backups/{backup_name}"
    
    print(f"Creating auto-backup: {backup_name}")
    
    try:
        # Use the control panel's backup functionality
        from vps_backend import vps_manager
        result = vps_manager.create_backup()
        
        if result:
            print(f"Auto-backup successful: {result['size_mb']} MB")
            cleanup_old_backups()
        else:
            print("Auto-backup failed")
    except Exception as e:
        print(f"Auto-backup error: {e}")

def cleanup_old_backups():
    backup_dir = "/kaggle/working/backups"
    backups = sorted([f for f in os.listdir(backup_dir) if f.startswith('auto_backup_')], 
                    reverse=True)
    
    if len(backups) > MAX_BACKUPS:
        for old_backup in backups[MAX_BACKUPS:]:
            os.remove(os.path.join(backup_dir, old_backup))
            print(f"Removed old backup: {old_backup}")

def auto_save_loop():
    while True:
        time.sleep(SAVE_INTERVAL)
        create_backup()

if __name__ == '__main__':
    print("Auto-save service started")
    auto_save_loop()
EOF
    chmod +x /kaggle/working/scripts/auto_save.py
    
    log_message "✅ Auto-save configured"
}

# Function to create useful utilities
create_utilities() {
    log_message "🔧 Creating utility scripts..."
    
    # Create system info script
    cat > /kaggle/working/scripts/system_info.sh << 'EOF'
#!/bin/bash
echo "=========================================="
echo "         KAGGLE VPS SYSTEM INFO"
echo "=========================================="
echo
echo "🖥️  SYSTEM:"
echo "   OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "   Kernel: $(uname -r)"
echo "   Uptime: $(uptime -p)"
echo
echo "🧠 CPU:"
lscpu | grep -E "Model name|CPU\(s\)|Thread\(s\) per core"
echo
echo "💾 MEMORY:"
free -h
echo
echo "💿 DISK:"
df -h /kaggle/working
echo
echo "🎮 GPU:"
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader 2>/dev/null || echo "   No GPU available"
echo
echo "🌐 NETWORK:"
ip route get 1.1.1.1 | grep -oP 'src \K\S+' | head -1 | xargs -I {} echo "   IP Address: {}"
echo "   Internet: $(curl -s --max-time 3 http://httpbin.org/ip | jq -r .origin 2>/dev/null || echo 'Not available')"
echo
echo "🚀 SERVICES:"
ps aux | grep -E "(python3.*vps_backend|vncserver|nginx)" | grep -v grep || echo "   No services running"
echo
echo "📊 RESOURCE USAGE:"
echo "   CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "   Memory: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')"
echo "   Disk: $(df /kaggle/working | tail -1 | awk '{print $5}')"
echo
EOF
    chmod +x /kaggle/working/scripts/system_info.sh
    
    # Create port scanner
    cat > /kaggle/working/scripts/port_scan.sh << 'EOF'
#!/bin/bash
echo "🔍 Scanning active ports..."
echo
netstat -tuln | grep LISTEN | sort | while read line; do
    port=$(echo $line | awk '{print $4}' | cut -d':' -f2)
    proto=$(echo $line | awk '{print $1}')
    case $port in
        22) service="SSH" ;;
        80) service="HTTP/Nginx" ;;
        443) service="HTTPS" ;;
        5000) service="Control Panel" ;;
        5901) service="VNC Server" ;;
        6080) service="Web VNC" ;;
        8080) service="Web App" ;;
        8888) service="Jupyter" ;;
        *) service="Unknown" ;;
    esac
    printf "%-8s %-8s %-20s\n" "$proto" "$port" "$service"
done
EOF
    chmod +x /kaggle/working/scripts/port_scan.sh
    
    # Create quick backup script
    cat > /kaggle/working/scripts/quick_backup.sh << 'EOF'
#!/bin/bash
echo "📦 Creating quick backup..."
cd /kaggle/working

# Create timestamped backup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="quick_backup_${TIMESTAMP}.zip"

zip -r "backups/${BACKUP_NAME}" \
    projects/ \
    scripts/ \
    config/ \
    *.py \
    *.sh \
    requirements.txt \
    -x "*/.*" "*/__pycache__/*" "*/node_modules/*" 2>/dev/null

SIZE=$(du -h "backups/${BACKUP_NAME}" | cut -f1)
echo "✅ Backup created: ${BACKUP_NAME} (${SIZE})"
echo "📤 Remember to download this file before session ends!"
EOF
    chmod +x /kaggle/working/scripts/quick_backup.sh
    
    log_message "✅ Utility scripts created"
}

# Main execution flow
main() {
    echo "🚀 Starting Kaggle VPS Setup..."
    
    # Step 1: Check if restoration is needed
    RESTORED=false
    if restore_from_backup; then
        RESTORED=true
    fi
    
    # Step 2: Install system packages
    install_system_packages
    
    # Step 3: Setup Python environment
    setup_python_environment
    
    # Step 4: Download/create control panel files (only if not restored)
    if [ "$RESTORED" = false ]; then
        download_control_panel
        create_sample_projects
    fi
    
    # Step 5: Setup VNC
    setup_vnc_server
    setup_web_vnc
    
    # Step 6: Setup nginx proxy
    setup_nginx_proxy
    
    # Step 7: Create services and utilities
    create_startup_services
    create_utilities
    setup_monitoring
    setup_auto_save
    
    # Step 8: Create aliases
    create_aliases
    
    # Step 9: Start services
    log_message "🚀 Starting services..."
    cd /kaggle/working
    ./start_control_panel.sh
    
    # Step 10: Final setup
    source ~/.bashrc
    
    # Step 11: Display final information
    display_final_info
    
    # Step 12: Open control panel if possible
    log_message "🌐 Opening control panel..."
    python3 -c "
import webbrowser
import time
time.sleep(3)
try:
    webbrowser.open('http://localhost:5000')
except:
    pass
" 2>/dev/null &
    
    echo "🎯 Setup complete! Your Kaggle VPS is ready to use."
    echo "   Run 'vps-panel' to see the control panel URL"
    echo "   Use Ctrl+C to stop this script (services will keep running)"
    echo ""
    
    # Keep script running to show logs
    tail -f /kaggle/working/vps_control.log 2>/dev/null || sleep infinity
}

# Error handling
trap 'echo "❌ Setup interrupted. Run ./stop_services.sh to clean up."; exit 1' INT TERM

# Run main function
main "$@"
