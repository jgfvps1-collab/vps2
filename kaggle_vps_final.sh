#!/bin/bash
# Final Working Kaggle VPS Implementation
# This creates a fully functional VPS with proper Kaggle integration

set -e
export DEBIAN_FRONTEND=noninteractive
export USER=root
export HOME=/root

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

log "🎯 Final Kaggle VPS Setup - Complete Implementation"
log "=================================================="

# Create directories
log "📁 Creating directory structure..."
mkdir -p /kaggle/working/{backups,logs,scripts,projects,web}

# Install essential packages
log "📦 Installing packages (streamlined)..."
apt-get update -qq
apt-get install -y -qq curl wget git vim htop tree python3-pip zip unzip build-essential

# Install Python packages
log "🐍 Installing Python packages..."
pip3 install flask flask-cors psutil requests zipfile36

# Create the main VPS backend with API
log "🔧 Creating VPS backend with full API..."
cat > /kaggle/working/vps_server.py << 'BACKEND_EOF'
#!/usr/bin/env python3
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import os, subprocess, json, zipfile, psutil
from datetime import datetime
import threading, time

app = Flask(__name__)
CORS(app)

class KaggleVPS:
    def __init__(self):
        self.start_time = datetime.now()
        self.status = "running"
        os.chdir('/kaggle/working')
    
    def get_system_info(self):
        try:
            return {
                'cpu_percent': round(psutil.cpu_percent(interval=1), 1),
                'memory_percent': round(psutil.virtual_memory().percent, 1),
                'memory_used_gb': round(psutil.virtual_memory().used / (1024**3), 1),
                'memory_total_gb': round(psutil.virtual_memory().total / (1024**3), 1),
                'disk_percent': round(psutil.disk_usage('/kaggle/working').percent, 1),
                'disk_used_gb': round(psutil.disk_usage('/kaggle/working').used / (1024**3), 1),
                'disk_total_gb': round(psutil.disk_usage('/kaggle/working').total / (1024**3), 1),
                'uptime_minutes': round((datetime.now() - self.start_time).total_seconds() / 60, 1),
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            return {'error': str(e)}
    
    def create_backup(self):
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_name = f"kaggle_vps_backup_{timestamp}.zip"
            backup_path = f"/kaggle/working/backups/{backup_name}"
            
            with zipfile.ZipFile(backup_path, 'w', zipfile.ZIP_DEFLATED) as zf:
                # Backup key files
                for root, dirs, files in os.walk('/kaggle/working'):
                    # Skip backup and log directories
                    dirs[:] = [d for d in dirs if d not in ['backups', '__pycache__']]
                    
                    for file in files:
                        if not file.endswith(('.log', '.pyc', '.tmp')) and not file.startswith('.'):
                            file_path = os.path.join(root, file)
                            arc_name = os.path.relpath(file_path, '/kaggle/working')
                            zf.write(file_path, arc_name)
            
            size_mb = round(os.path.getsize(backup_path) / (1024 * 1024), 1)
            return {
                'success': True,
                'backup_name': backup_name,
                'size_mb': size_mb,
                'path': backup_path,
                'message': f'Backup created: {backup_name} ({size_mb} MB)'
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def run_command(self, command):
        try:
            result = subprocess.run(command, shell=True, capture_output=True, 
                                  text=True, timeout=30)
            return {
                'success': result.returncode == 0,
                'stdout': result.stdout,
                'stderr': result.stderr,
                'return_code': result.returncode
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

# Initialize VPS
vps = KaggleVPS()

# Web Interface Routes
@app.route('/')
def index():
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kaggle VPS Control Panel</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh; color: #333; padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { 
            background: rgba(255,255,255,0.95); padding: 30px; border-radius: 15px; 
            margin-bottom: 20px; text-align: center; 
            box-shadow: 0 8px 32px rgba(0,0,0,0.1); backdrop-filter: blur(10px);
        }
        .header h1 { color: #2c3e50; font-size: 2.5em; margin-bottom: 10px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .panel { 
            background: rgba(255,255,255,0.95); padding: 25px; border-radius: 15px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1); backdrop-filter: blur(10px);
        }
        .panel h2 { color: #2c3e50; margin-bottom: 20px; font-size: 1.4em; }
        .btn { 
            background: linear-gradient(145deg, #3498db, #2980b9); color: white; border: none;
            padding: 12px 20px; border-radius: 8px; cursor: pointer; font-size: 14px;
            font-weight: bold; margin: 5px; transition: all 0.3s ease;
        }
        .btn:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(52,152,219,0.4); }
        .btn.success { background: linear-gradient(145deg, #27ae60, #219a52); }
        .btn.warning { background: linear-gradient(145deg, #f39c12, #e67e22); }
        .btn.danger { background: linear-gradient(145deg, #e74c3c, #c0392b); }
        .output { 
            background: #2c3e50; color: #ecf0f1; padding: 20px; border-radius: 10px;
            font-family: 'Courier New', monospace; font-size: 13px; line-height: 1.4;
            max-height: 300px; overflow-y: auto; margin: 15px 0;
        }
        .metric { 
            display: flex; justify-content: space-between; margin: 10px 0;
            padding: 8px; background: #f8f9fa; border-radius: 5px;
        }
        .status-online { color: #27ae60; font-weight: bold; }
        .status-warning { color: #f39c12; font-weight: bold; }
        .status-error { color: #e74c3c; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎮 Kaggle VPS Control Panel</h1>
            <p>Your pseudo-VPS is running on Kaggle's infrastructure</p>
            <div id="status-bar">
                <span class="status-online">● Online</span> | 
                <span>Uptime: <span id="uptime">0 min</span></span> |
                <span>Last Update: <span id="last-update">Never</span></span>
            </div>
        </div>
        
        <div class="grid">
            <div class="panel">
                <h2>📊 System Resources</h2>
                <div id="resources">
                    <div class="metric"><span>CPU Usage:</span><span id="cpu">0%</span></div>
                    <div class="metric"><span>Memory:</span><span id="memory">0 GB / 0 GB</span></div>
                    <div class="metric"><span>Disk:</span><span id="disk">0 GB / 0 GB</span></div>
                </div>
                <button class="btn" onclick="updateResources()">🔄 Refresh</button>
                <button class="btn warning" onclick="getSystemInfo()">📋 Detailed Info</button>
            </div>
            
            <div class="panel">
                <h2>💾 Backup Management</h2>
                <button class="btn success" onclick="createBackup()">📥 Create Backup</button>
                <button class="btn" onclick="listBackups()">📋 List Backups</button>
                <button class="btn warning" onclick="downloadBackup()">⬇️ Download Latest</button>
                <div id="backup-status" class="output" style="max-height: 150px;">
                    Click "Create Backup" to save your current work
                </div>
            </div>
            
            <div class="panel">
                <h2>🔧 System Control</h2>
                <button class="btn" onclick="runCommand('ps aux | head -10')">👁️ Processes</button>
                <button class="btn" onclick="runCommand('df -h')">💿 Disk Usage</button>
                <button class="btn" onclick="runCommand('free -h')">🧠 Memory Info</button>
                <button class="btn warning" onclick="runCommand('nvidia-smi')">🎮 GPU Status</button>
                
                <h3 style="margin-top: 20px;">Custom Command:</h3>
                <input type="text" id="custom-command" placeholder="Enter command..." 
                       style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 5px; margin: 5px 0;">
                <button class="btn" onclick="runCustomCommand()">▶️ Execute</button>
            </div>
        </div>
        
        <div class="panel">
            <h2>📺 Command Output</h2>
            <div id="output" class="output">
                Welcome to Kaggle VPS Control Panel!<br>
                Your virtual private server is ready to use.<br>
                <span class="status-online">● All systems operational</span>
            </div>
        </div>
    </div>

    <script>
        let updateInterval;
        
        function log(message, type = 'info') {
            const output = document.getElementById('output');
            const timestamp = new Date().toLocaleTimeString();
            const colors = { info: '#3498db', success: '#27ae60', warning: '#f39c12', error: '#e74c3c' };
            output.innerHTML += `<br><span style="color: ${colors[type]}">[${timestamp}] ${message}</span>`;
            output.scrollTop = output.scrollHeight;
        }
        
        async function apiCall(endpoint, method = 'GET', data = null) {
            try {
                const options = { method };
                if (data) {
                    options.headers = { 'Content-Type': 'application/json' };
                    options.body = JSON.stringify(data);
                }
                
                const response = await fetch(`/api/${endpoint}`, options);
                return await response.json();
            } catch (error) {
                log(`API Error: ${error.message}`, 'error');
                return { error: error.message };
            }
        }
        
        async function updateResources() {
            const data = await apiCall('system');
            if (data.error) {
                log(`Failed to get system info: ${data.error}`, 'error');
                return;
            }
            
            document.getElementById('cpu').textContent = `${data.cpu_percent}%`;
            document.getElementById('memory').textContent = `${data.memory_used_gb} GB / ${data.memory_total_gb} GB`;
            document.getElementById('disk').textContent = `${data.disk_used_gb} GB / ${data.disk_total_gb} GB`;
            document.getElementById('uptime').textContent = `${data.uptime_minutes} min`;
            document.getElementById('last-update').textContent = new Date().toLocaleTimeString();
            
            log(`System updated - CPU: ${data.cpu_percent}%, Memory: ${data.memory_percent}%`, 'success');
        }
        
        async function getSystemInfo() {
            const data = await apiCall('system');
            log('=== SYSTEM INFORMATION ===', 'info');
            log(`CPU Usage: ${data.cpu_percent}%`, 'info');
            log(`Memory: ${data.memory_used_gb}GB / ${data.memory_total_gb}GB (${data.memory_percent}%)`, 'info');
            log(`Disk: ${data.disk_used_gb}GB / ${data.disk_total_gb}GB (${data.disk_percent}%)`, 'info');
            log(`Uptime: ${data.uptime_minutes} minutes`, 'info');
        }
        
        async function createBackup() {
            log('Creating backup...', 'info');
            const data = await apiCall('backup', 'POST');
            
            if (data.success) {
                log(`✅ ${data.message}`, 'success');
                document.getElementById('backup-status').innerHTML = `
                    <strong>Latest Backup:</strong><br>
                    📁 ${data.backup_name}<br>
                    💾 Size: ${data.size_mb} MB<br>
                    📍 Location: ${data.path}
                `;
            } else {
                log(`❌ Backup failed: ${data.error}`, 'error');
            }
        }
        
        async function listBackups() {
            const data = await apiCall('command', 'POST', { command: 'ls -la /kaggle/working/backups/*.zip' });
            log('=== BACKUP FILES ===', 'info');
            if (data.success) {
                log(data.stdout || 'No backup files found', 'info');
            } else {
                log('No backups found or error accessing backup directory', 'warning');
            }
        }
        
        function downloadBackup() {
            log('To download backups:', 'info');
            log('1. Go to /kaggle/working/backups/', 'info');
            log('2. Right-click on backup files', 'info');
            log('3. Select "Download" or copy to your dataset', 'info');
        }
        
        async function runCommand(command) {
            log(`> ${command}`, 'info');
            const data = await apiCall('command', 'POST', { command });
            
            if (data.success) {
                log(data.stdout, 'success');
                if (data.stderr) log(`stderr: ${data.stderr}`, 'warning');
            } else {
                log(`Command failed: ${data.error || data.stderr}`, 'error');
            }
        }
        
        function runCustomCommand() {
            const command = document.getElementById('custom-command').value;
            if (command.trim()) {
                runCommand(command);
                document.getElementById('custom-command').value = '';
            }
        }
        
        // Event listeners
        document.getElementById('custom-command').addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                runCustomCommand();
            }
        });
        
        // Auto-update resources
        updateResources();
        updateInterval = setInterval(updateResources, 30000);
        
        // Initial messages
        log('Kaggle VPS Control Panel initialized', 'success');
        log('System monitoring active', 'info');
    </script>
</body>
</html>
    '''

# API Routes
@app.route('/api/system')
def api_system():
    return jsonify(vps.get_system_info())

@app.route('/api/backup', methods=['POST'])
def api_backup():
    return jsonify(vps.create_backup())

@app.route('/api/command', methods=['POST'])
def api_command():
    data = request.get_json()
    command = data.get('command', '')
    return jsonify(vps.run_command(command))

@app.route('/files/<path:filename>')
def serve_files(filename):
    return send_from_directory('/kaggle/working', filename)

if __name__ == '__main__':
    import socket
    notebook_host = socket.gethostname()
    port = 8080
    proxy_url = f"https://{notebook_host}-{port}.proxy.kaggle.net/"
    
    print("🚀 Kaggle VPS Control Panel Starting...")
    print(f"🌍 Web Interface: {proxy_url}")
    print(f"🔧 API Endpoints: {proxy_url}api/system")
    print(f"📁 File Access: {proxy_url}files/")
    print("=" * 50)
    
    app.run(host='0.0.0.0', port=port, debug=False, threaded=True)
BACKEND_EOF

log "✅ VPS backend created"

# Create project examples
log "📂 Creating sample projects..."

# Sample Python script
cat > /kaggle/working/projects/sample_analysis.py << 'ANALYSIS_EOF'
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

print("🔬 Kaggle VPS - Sample Data Analysis")
print("=" * 40)

# Generate sample data
data = pd.DataFrame({
    'category': np.random.choice(['A', 'B', 'C'], 1000),
    'value': np.random.randn(1000) * 100 + 500,
    'date': pd.date_range('2024-01-01', periods=1000, freq='H')
})

print(f"📊 Generated dataset with {len(data)} rows")
print(f"📈 Value range: {data['value'].min():.1f} to {data['value'].max():.1f}")
print(f"📅 Date range: {data['date'].min()} to {data['date'].max()}")

# Basic analysis
summary = data.groupby('category')['value'].agg(['mean', 'std', 'count'])
print("\n📋 Summary by category:")
print(summary)

# Save results
data.to_csv('/kaggle/working/sample_data.csv', index=False)
print("\n💾 Data saved to: /kaggle/working/sample_data.csv")
print("✅ Analysis complete!")
ANALYSIS_EOF

# Sample web app
cat > /kaggle/working/projects/simple_webapp.py << 'WEBAPP_EOF'
from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return '''
    <h1>🚀 Kaggle VPS Web App</h1>
    <p>This is running on your pseudo-VPS!</p>
    <p><a href="/status">Check Status</a></p>
    '''

@app.route('/status')
def status():
    import datetime, psutil
    return f'''
    <h2>📊 VPS Status</h2>
    <p><strong>Time:</strong> {datetime.datetime.now()}</p>
    <p><strong>CPU:</strong> {psutil.cpu_percent()}%</p>
    <p><strong>Memory:</strong> {psutil.virtual_memory().percent}%</p>
    <p><a href="/">← Back</a></p>
    '''

if __name__ == '__main__':
    print("🌐 Starting web app on port 9000...")
    app.run(host='0.0.0.0', port=9000, debug=True)
WEBAPP_EOF

# Create utility scripts
log "🔧 Creating utility scripts..."

cat > /kaggle/working/scripts/quick_commands.sh << 'COMMANDS_EOF'
#!/bin/bash
echo "🎯 Kaggle VPS Quick Commands"
echo "============================="
echo

echo "📊 System Status:"
echo "CPU Cores: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h /kaggle/working | tail -1 | awk '{print $2}')"
echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'Not available')"
echo

echo "🔍 Running Processes:"
ps aux | grep -E "(python3|flask)" | grep -v grep | head -5

echo
echo "📁 Project Files:"
find /kaggle/working/projects -name "*.py" -exec basename {} \; 2>/dev/null

echo
echo "💾 Backup Files:"
ls -la /kaggle/working/backups/ 2>/dev/null | tail -5

echo
echo "✅ Quick status check complete!"
COMMANDS_EOF

chmod +x /kaggle/working/scripts/quick_commands.sh

# Create aliases
log "📝 Setting up aliases..."
cat >> ~/.bashrc << 'ALIASES_EOF'

# Kaggle VPS Aliases
alias vps='echo "🎮 Kaggle VPS Commands:"; echo "  vps-start    - Start control panel"; echo "  vps-status   - System status"; echo "  vps-backup   - Create backup"; echo "  vps-logs     - View logs"'
alias vps-start='cd /kaggle/working && python3 vps_server.py &'
alias vps-status='/kaggle/working/scripts/quick_commands.sh'
alias vps-backup='cd /kaggle/working && curl -X POST http://localhost:8080/api/backup'
alias vps-logs='tail -20 /kaggle/working/logs/*.log 2>/dev/null || echo "No logs yet"'

# Shortcuts
alias ll='ls -la'
alias ..='cd ..'
alias gpu='nvidia-smi'
alias resources='echo "=== RESOURCES ===" && free -h && df -h && nvidia-smi --query-gpu=memory.used,memory.total --format=csv'

echo "🎯 Kaggle VPS environment loaded!"
echo "Type 'vps' for available commands"
ALIASES_EOF

# Start the VPS server
log "🚀 Starting VPS Control Panel..."
cd /kaggle/working
python3 vps_server.py > logs/vps.log 2>&1 &
VPS_PID=$!

# Wait for server to start
sleep 5

# Check if server started
if kill -0 $VPS_PID 2>/dev/null; then
    log "✅ VPS Control Panel started successfully!"
else
    log "⚠️ VPS server may have issues - check logs/vps.log"
fi

# Final summary
echo
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}🎉 KAGGLE VPS SETUP COMPLETE!${NC}"
echo -e "${BLUE}============================================${NC}"
echo
echo -e "${GREEN}🌐 ACCESS YOUR VPS:${NC}"
echo "   Control Panel: http://localhost:8080"
echo "   (Look for Kaggle port forwarding links above)"
echo
echo -e "${GREEN}🔧 QUICK COMMANDS:${NC}"
echo "   vps          - Show available commands"
echo "   vps-status   - Check system status  "
echo "   vps-backup   - Create backup"
echo
echo -e "${GREEN}📁 FILES CREATED:${NC}"
echo "   /kaggle/working/vps_server.py     - Main control panel"
echo "   /kaggle/working/projects/         - Sample projects"
echo "   /kaggle/working/scripts/          - Utility scripts"
echo "   /kaggle/working/backups/          - Backup storage"
echo
echo -e "${YELLOW}💡 NEXT STEPS:${NC}"
echo "1. Look for port forwarding links in Kaggle interface"
echo "2. Or run: curl http://localhost:8080/api/system"
echo "3. Create your first backup: vps-backup"
echo "4. Start coding in the projects/ directory"
echo
echo -e "${GREEN}✅ Your Kaggle VPS is ready to use!${NC}"

# Source the aliases
source ~/.bashrc 2>/dev/null || true
