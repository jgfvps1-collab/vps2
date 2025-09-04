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
    
    def load_session
