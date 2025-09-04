#!/usr/bin/env python3
"""
Kaggle VPS Control Panel Backend API
This script runs inside your Kaggle kernel to provide the backend for the control panel
"""

import os
import sys
import json
import time
import psutil
import subprocess
import threading
from datetime import datetime, timedelta
from pathlib import Path
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import zipfile
import shutil

app = Flask(__name__)
CORS(app)

# Configuration
CONFIG = {
    'backup_dir': '/kaggle/working/backups',
    'log_file': '/kaggle/working/vps_control.log',
    'session_file': '/kaggle/working/session_info.json',
    'auto_save_interval': 3600,  # 1 hour
    'max_log_entries': 1000,
    'vnc_port': 5901,
    'web_vnc_port': 6080
}

class KaggleVPSManager:
    def __init__(self):
        self.session_active = False
        self.session_start_time = None
        self.auto_save_enabled = False
        self.auto_save_thread = None
        self.session_id = None
        self.logs = []
        
        # Create necessary directories
        Path(CONFIG['backup_dir']).mkdir(exist_ok=True)
        
        # Initialize session
        self.load_session_info()
        self.log_message("VPS Manager initialized", "info")
    
    def log_message(self, message, level="info"):
        """Add a log entry"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = {
            'timestamp': timestamp,
            'level': level,
            'message': message
        }
        self.logs.append(log_entry)
        
        # Keep only last N entries
        if len(self.logs) > CONFIG['max_log_entries']:
            self.logs = self.logs[-CONFIG['max_log_entries']:]
        
        # Also write to file
        with open(CONFIG['log_file'], 'a') as f:
            f.write(f"[{timestamp}] [{level.upper()}] {message}\n")
        
        print(f"[{level.upper()}] {message}")
    
    def save_session_info(self):
        """Save session information to file"""
        session_info = {
            'session_active': self.session_active,
            'session_start_time': self.session_start_time.isoformat() if self.session_start_time else None,
            'session_id': self.session_id,
            'auto_save_enabled': self.auto_save_enabled
        }
        
        with open(CONFIG['session_file'], 'w') as f:
            json.dump(session_info, f, indent=2)
    
    def load_session_info(self):
        """Load session information from file"""
        if os.path.exists(CONFIG['session_file']):
            try:
                with open(CONFIG['session_file'], 'r') as f:
                    session_info = json.load(f)
                
                self.session_active = session_info.get('session_active', False)
                self.session_id = session_info.get('session_id')
                self.auto_save_enabled = session_info.get('auto_save_enabled', False)
                
                if session_info.get('session_start_time'):
                    self.session_start_time = datetime.fromisoformat(session_info['session_start_time'])
                
                self.log_message("Session info loaded", "info")
            except Exception as e:
                self.log_message(f"Failed to load session info: {e}", "error")
    
    def get_system_resources(self):
        """Get current system resource usage"""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/kaggle/working')
            
            # GPU info (if available)
            gpu_info = self.get_gpu_info()
            
            return {
                'cpu': {
                    'usage_percent': round(cpu_percent, 1),
                    'cores': psutil.cpu_count()
                },
                'memory': {
                    'total': round(memory.total / (1024**3), 2),
                    'used': round(memory.used / (1024**3), 2),
                    'available': round(memory.available / (1024**3), 2),
                    'percent': memory.percent
                },
                'disk': {
                    'total': round(disk.total / (1024**3), 2),
                    'used': round(disk.used / (1024**3), 2),
                    'free': round(disk.free / (1024**3), 2),
                    'percent': round((disk.used / disk.total) * 100, 1)
                },
                'gpu': gpu_info
            }
        except Exception as e:
            self.log_message(f"Error getting system resources: {e}", "error")
            return None
    
    def get_gpu_info(self):
        """Get GPU information using nvidia-smi"""
        try:
            result = subprocess.run(['nvidia-smi', '--query-gpu=memory.total,memory.used,memory.free,utilization.gpu', 
                                   '--format=csv,noheader,nounits'], 
                                  capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if lines and lines[0]:
                    values = [float(x.strip()) for x in lines[0].split(',')]
                    total_mem, used_mem, free_mem, gpu_util = values
                    
                    return {
                        'available': True,
                        'memory_total': round(total_mem / 1024, 2),  # Convert to GB
                        'memory_used': round(used_mem / 1024, 2),
                        'memory_free': round(free_mem / 1024, 2),
                        'utilization': gpu_util
                    }
        except Exception as e:
            self.log_message(f"GPU info unavailable: {e}", "warning")
        
        return {'available': False}
    
    def start_session(self):
        """Start a new VPS session"""
        try:
            self.session_id = f"kaggle-{int(time.time())}"
            self.session_start_time = datetime.now()
            self.session_active = True
            
            self.log_message(f"Starting session {self.session_id}", "info")
            
            # Initialize environment
            self.setup_environment()
            
            # Start auto-save if enabled
            if self.auto_save_enabled:
                self.start_auto_save()
            
            self.save_session_info()
            self.log_message("Session started successfully", "success")
            
            return True
        except Exception as e:
            self.log_message(f"Failed to start session: {e}", "error")
            return False
    
    def stop_session(self):
        """Stop the current session"""
        try:
            if self.auto_save_thread:
                self.auto_save_enabled = False
                self.auto_save_thread = None
            
            self.session_active = False
            self.log_message(f"Session {self.session_id} stopped", "warning")
            
            self.save_session_info()
            return True
        except Exception as e:
            self.log_message(f"Error stopping session: {e}", "error")
            return False
    
    def setup_environment(self):
        """Setup the VPS environment"""
        try:
            self.log_message("Setting up environment...", "info")
            
            # Install basic packages
            packages = ['htop', 'tree', 'nano', 'curl', 'wget']
            for package in packages:
                subprocess.run(['apt-get', 'install', '-y', '-qq', package], 
                             check=False, capture_output=True)
            
            # Setup VNC if not already running
            self.setup_vnc()
            
            self.log_message("Environment setup completed", "success")
        except Exception as e:
            self.log_message(f"Environment setup failed: {e}", "error")
    
    def setup_vnc(self):
        """Setup VNC server"""
        try:
            # Check if VNC is already running
            vnc_check = subprocess.run(['pgrep', 'Xvnc'], capture_output=True)
            if vnc_check.returncode == 0:
                self.log_message("VNC server already running", "info")
                return
            
            # Install VNC server
            subprocess.run(['apt-get', 'install', '-y', '-qq', 'tightvncserver', 'xfce4'], 
                         capture_output=True)
            
            # Setup VNC password
            vnc_dir = Path.home() / '.vnc'
            vnc_dir.mkdir(exist_ok=True)
            
            # Create password file
            subprocess.run(['echo', 'vncpass'], input='vncpass\nvncpass\nn\n', 
                         text=True, stdout=subprocess.PIPE)
            
            # Start VNC server
            subprocess.run(['vncserver', ':1', '-geometry', '1280x720', '-depth', '24'], 
                         capture_output=True)
            
            self.log_message("VNC server started on port 5901", "success")
        except Exception as e:
            self.log_message(f"VNC setup failed: {e}", "error")
    
    def create_backup(self):
        """Create a backup of the current session"""
        try:
            self.log_message("Creating backup...", "info")
            
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_name = f"session_backup_{timestamp}.zip"
            backup_path = Path(CONFIG['backup_dir']) / backup_name
            
            # Create backup directory structure
            temp_backup = Path('/tmp/session_backup')
            temp_backup.mkdir(exist_ok=True)
            
            # Backup working directory
            working_backup = temp_backup / 'working'
            shutil.copytree('/kaggle/working', working_backup, ignore=shutil.ignore_patterns('*.tmp', '__pycache__'))
            
            # Backup home configs
            home_backup = temp_backup / 'home'
            home_backup.mkdir(exist_ok=True)
            
            home_files = ['.bashrc', '.vimrc', '.gitconfig']
            for file in home_files:
                src = Path.home() / file
                if src.exists():
                    shutil.copy2(src, home_backup / file)
            
            # Save package lists
            with open(temp_backup / 'requirements.txt', 'w') as f:
                subprocess.run(['pip', 'freeze'], stdout=f)
            
            # Create session info
            session_info = {
                'backup_time': timestamp,
                'session_id': self.session_id,
                'uptime_hours': self.get_uptime_hours()
            }
            
            with open(temp_backup / 'backup_info.json', 'w') as f:
                json.dump(session_info, f, indent=2)
            
            # Create zip file
            with zipfile.ZipFile(backup_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
                for root, dirs, files in os.walk(temp_backup):
                    for file in files:
                        file_path = Path(root) / file
                        arc_path = file_path.relative_to(temp_backup)
                        zipf.write(file_path, arc_path)
            
            # Cleanup
            shutil.rmtree(temp_backup)
            
            backup_size = backup_path.stat().st_size / (1024 * 1024)  # MB
            self.log_message(f"Backup created: {backup_name} ({backup_size:.1f} MB)", "success")
            
            return {
                'filename': backup_name,
                'size_mb': round(backup_size, 1),
                'path': str(backup_path)
            }
            
        except Exception as e:
            self.log_message(f"Backup failed: {e}", "error")
            return None
    
    def restore_backup(self, backup_filename=None):
        """Restore from a backup"""
        try:
            if not backup_filename:
                # Find latest backup
                backups = list(Path(CONFIG['backup_dir']).glob('session_backup_*.zip'))
                if not backups:
                    raise Exception("No backups found")
                backup_path = max(backups, key=lambda x: x.stat().st_mtime)
            else:
                backup_path = Path(CONFIG['backup_dir']) / backup_filename
            
            if not backup_path.exists():
                raise Exception(f"Backup file not found: {backup_path}")
            
            self.log_message(f"Restoring from {backup_path.name}...", "info")
            
            # Extract backup
            temp_restore = Path('/tmp/session_restore')
            if temp_restore.exists():
                shutil.rmtree(temp_restore)
            temp_restore.mkdir()
            
            with zipfile.ZipFile(backup_path, 'r') as zipf:
                zipf.extractall(temp_restore)
            
            # Restore working directory
            working_restore = temp_restore / 'working'
            if working_restore.exists():
                # Backup current working directory
                current_backup = Path('/tmp/current_working_backup')
                if current_backup.exists():
                    shutil.rmtree(current_backup)
                shutil.copytree('/kaggle/working', current_backup)
                
                # Restore from backup
                shutil.copytree(working_restore, '/kaggle/working', dirs_exist_ok=True)
            
            # Restore home configs
            home_restore = temp_restore / 'home'
            if home_restore.exists():
                for file in home_restore.iterdir():
                    shutil.copy2(file, Path.home() / file.name)
            
            # Restore packages
            requirements_file = temp_restore / 'requirements.txt'
            if requirements_file.exists():
                subprocess.run(['pip', 'install', '-r', str(requirements_file)], 
                             capture_output=True)
            
            # Cleanup
            shutil.rmtree(temp_restore)
            
            self.log_message("Backup restored successfully", "success")
            return True
            
        except Exception as e:
            self.log_message(f"Restore failed: {e}", "error")
            return False
    
    def get_uptime_hours(self):
        """Get session uptime in hours"""
        if self.session_start_time:
            delta = datetime.now() - self.session_start_time
            return round(delta.total_seconds() / 3600, 2)
        return 0
    
    def start_auto_save(self):
        """Start automatic backup thread"""
        def auto_save_worker():
            while self.auto_save_enabled:
                time.sleep(CONFIG['auto_save_interval'])
                if self.session_active and self.auto_save_enabled:
                    self.log_message("Auto-save triggered", "info")
                    self.create_backup()
        
        self.auto_save_thread = threading.Thread(target=auto_save_worker, daemon=True)
        self.auto_save_thread.start()
        self.log_message("Auto-save started", "success")
    
    def get_status(self):
        """Get overall system status"""
        return {
            'session_active': self.session_active,
            'session_id': self.session_id,
            'uptime_hours': self.get_uptime_hours(),
            'auto_save_enabled': self.auto_save_enabled,
            'last_backup': self.get_last_backup_info(),
            'resources': self.get_system_resources()
        }
    
    def get_last_backup_info(self):
        """Get information about the last backup"""
        try:
            backups = list(Path(CONFIG['backup_dir']).glob('session_backup_*.zip'))
            if not backups:
                return None
            
            latest = max(backups, key=lambda x: x.stat().st_mtime)
            return {
                'filename': latest.name,
                'size_mb': round(latest.stat().st_size / (1024 * 1024), 1),
                'created': datetime.fromtimestamp(latest.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S")
            }
        except:
            return None

# Initialize manager
vps_manager = KaggleVPSManager()

# API Routes
@app.route('/')
def index():
    """Serve the control panel"""
    return send_from_directory('.', 'control_panel.html')

@app.route('/api/status')
def get_status():
    """Get current system status"""
    return jsonify(vps_manager.get_status())

@app.route('/api/session/start', methods=['POST'])
def start_session():
    """Start a new session"""
    success = vps_manager.start_session()
    return jsonify({'success': success})

@app.route('/api/session/stop', methods=['POST'])
def stop_session():
    """Stop current session"""
    success = vps_manager.stop_session()
    return jsonify({'success': success})

@app.route('/api/session/restart', methods=['POST'])
def restart_session():
    """Restart current session"""
    vps_manager.stop_session()
    time.sleep(2)
    success = vps_manager.start_session()
    return jsonify({'success': success})

@app.route('/api/backup/create', methods=['POST'])
def create_backup():
    """Create a new backup"""
    backup_info = vps_manager.create_backup()
    return jsonify({'success': backup_info is not None, 'backup': backup_info})

@app.route('/api/backup/restore', methods=['POST'])
def restore_backup():
    """Restore from backup"""
    data = request.get_json()
    filename = data.get('filename') if data else None
    success = vps_manager.restore_backup(filename)
    return jsonify({'success': success})

@app.route('/api/backup/list')
def list_backups():
    """List available backups"""
    try:
        backups = []
        backup_dir = Path(CONFIG['backup_dir'])
        for backup in backup_dir.glob('session_backup_*.zip'):
            backups.append({
                'filename': backup.name,
                'size_mb': round(backup.stat().st_size / (1024 * 1024), 1),
                'created': datetime.fromtimestamp(backup.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S")
            })
        backups.sort(key=lambda x: x['created'], reverse=True)
        return jsonify({'backups': backups})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/autosave/toggle', methods=['POST'])
def toggle_auto_save():
    """Toggle auto-save feature"""
    vps_manager.auto_save_enabled = not vps_manager.auto_save_enabled
    
    if vps_manager.auto_save_enabled:
        vps_manager.start_auto_save()
    else:
        vps_manager.auto_save_thread = None
    
    return jsonify({'enabled': vps_manager.auto_save_enabled})

@app.route('/api/resources')
def get_resources():
    """Get system resources"""
    resources = vps_manager.get_system_resources()
    return jsonify(resources)

@app.route('/api/logs')
def get_logs():
    """Get system logs"""
    return jsonify({'logs': vps_manager.logs[-50:]})  # Last 50 entries

@app.route('/api/health')
def health_check():
    """System health check"""
    try:
        resources = vps_manager.get_system_resources()
        checks = {
            'cpu_ok': resources['cpu']['usage_percent'] < 90,
            'memory_ok': resources['memory']['percent'] < 90,
            'disk_ok': resources['disk']['percent'] < 90,
            'session_ok': vps_manager.session_active
        }
        
        overall_health = all(checks.values())
        
        return jsonify({
            'healthy': overall_health,
            'checks': checks,
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("🚀 Starting Kaggle VPS Control Panel Backend")
    print(f"📊 Access control panel at http://localhost:5000")
    print(f"🖥️  VNC server will be available on port {CONFIG['vnc_port']}")
    
    # Start the Flask app
    app.run(host='0.0.0.0', port=5000, debug=False)
