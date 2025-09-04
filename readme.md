# 🎯 Kaggle VPS Control Panel

Transform your Kaggle kernel into a powerful pseudo-VPS with a professional web-based control panel. Get 30 hours/week of free GPU-enabled computing with persistent-like functionality!

![Control Panel Preview](https://via.placeholder.com/800x400/667eea/ffffff?text=Kaggle+VPS+Control+Panel)

## ✨ Features

### 🖥️ **Professional Web Control Panel**
- Real-time resource monitoring (CPU, RAM, GPU, Disk)
- Session management (start/stop/restart)
- One-click backup and restore
- System health monitoring
- Live log viewer
- Quick access to all services

### 🔄 **Persistence System**
- Automatic session save/restore
- Compress and backup entire environment
- Auto-save every hour (configurable)
- Quick restore in new sessions
- Version-controlled backups

### 🖱️ **Remote Desktop (VNC)**
- Full Ubuntu desktop via web browser
- XFCE4 lightweight desktop environment
- VNC client support
- Pre-installed development tools
- Multi-monitor support

### 🚀 **Pre-configured Services**
- Jupyter Lab for data science
- VS Code server for development
- Nginx reverse proxy
- SQLite database
- File manager web interface
- Terminal access via web

### 💪 **Powerful Hardware** (Free!)
- 4 CPU cores (Intel Xeon)
- 16 GB RAM
- Tesla P100 GPU (16 GB VRAM)
- 100 GB SSD storage
- Unlimited bandwidth

## 🚀 Quick Start

### Method 1: One-Command Setup
```bash
# In a new Kaggle notebook with GPU enabled:
!curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/kaggle-vps-control/main/setup.sh | bash
```

### Method 2: Manual Setup
1. Create new Kaggle notebook (GPU enabled)
2. Upload this repository as a dataset
3. Add the dataset as input to your notebook
4. Run:
```python
import os
os.chdir('/kaggle/working')
!cp -r /kaggle/input/kaggle-vps-control/* .
!chmod +x setup.sh && ./setup.sh
```

### Method 3: Restore from Backup
1. Create new Kaggle notebook
2. Add your backup dataset as input
3. Run the setup script - it will auto-detect and restore your previous session

## 📋 Repository Structure

```
kaggle-vps-control/
├── 🎮 control_panel.html      # Main web control panel
├── 🐍 vps_backend.py          # Python Flask backend API
├── 🚀 setup.sh                # Master setup script
├── 📋 requirements.txt        # Python dependencies  
├── 📁 scripts/
│   ├── monitor_resources.py   # System monitoring
│   ├── auto_save.py          # Automatic backups
│   ├── system_info.sh        # System information
│   └── quick_backup.sh       # Manual backup utility
├── 📁 config/
│   ├── nginx.conf            # Nginx configuration
│   └── vnc_setup.sh          # VNC server setup
├── 📁 examples/
│   ├── flask_app.py          # Sample web application
│   ├── ml_project.ipynb      # Sample ML notebook
│   └── data_analysis.py      # Sample data script
└── 📖 README.md              # This file
```

## 🌐 Service Access Points

Once setup is complete, access your services at:

| Service | URL | Description |
|---------|-----|-------------|
| 🎮 **Control Panel** | `http://localhost:5000` | Main dashboard |
| 🖥️ **Web VNC** | `http://localhost:6080/vnc.html` | Desktop in browser |
| 📓 **Jupyter Lab** | `http://localhost:8888` | Data science environment |
| 📁 **File Manager** | `http://localhost:9000` | Web-based file browser |
| 💻 **Web Terminal** | `http://localhost:7681` | Terminal in browser |

**VNC Direct Access:** `localhost:5901` (Password: `kaggle123`)

## 🎮 Control Panel Features

### Dashboard Overview
- **System Status**: Real-time connection, session, and backup status
- **Resource Meters**: Live CPU, Memory, GPU, and disk usage
- **Session Info**: Current session ID, uptime, and kernel type
- **Quick Stats**: Last backup time and auto-save status

### Session Management
```
🟢 Start Session    - Initialize new VPS session
🔴 Stop Session     - Gracefully stop current session  
🔄 Restart Session  - Quick restart with state preservation
🖥️ Open VNC         - Launch desktop environment
```

### Backup & Restore
```
💾 Save Session     - Create full environment backup
⬆️ Restore Session  - Restore from previous backup
⏰ Auto-Save        - Enable hourly automatic backups
📜 Backup History   - View and manage all backups
```

### Quick Actions
```
📓 Jupyter Lab      - Launch data science environment
💻 Terminal         - Open web-based terminal
📁 File Manager     - Browse files via web interface
📦 Package Manager  - Install software packages
❤️ Health Check     - Comprehensive system diagnostics
📊 System Info      - Detailed hardware information
🚨 Emergency Stop   - Force stop all services
```

## 💾 Backup System

### Automatic Backups
- Saves every hour while session is active
- Includes: code, data, configurations, installed packages
- Compressed using zip (typically 50-200 MB)
- Keeps last 5 backups to save space

### Manual Backups
```bash
# Quick backup (via alias)
vps-backup

# Detailed backup with custom name
python3 scripts/create_backup.py --name "my_project_v1"

# List all backups
ls -la /kaggle/working/backups/
```

### Restore Process
1. **Automatic**: Script detects backup datasets in `/kaggle/input`
2. **Manual**: Use control panel restore function
3. **Command line**: `python3 scripts/restore_backup.py backup_file.zip`

## 🔧 Customization

### Adding Services
Edit `/kaggle/working/scripts/start_services.sh`:
```bash
# Add your service
nohup python3 my_app.py > logs/my_app.log 2>&1 &
echo $! > pids/my_app.pid
```

### Custom Packages
Add to `/kaggle/working/requirements.txt`:
```
streamlit
fastapi
your-package==1.0.0
```

### Desktop Applications
Install via apt in setup script:
```bash
apt-get install -y firefox code gimp vlc
```

## 📊 Monitoring & Debugging

### Resource Monitoring
```bash
# Real-time resources
htop
nvidia-smi

# Via web panel
curl http://localhost:5000/api/resources

# Historical data
tail -f /kaggle/working/logs/resource_monitor.log
```

### Service Status
```bash
# Check all services
vps-status

# Individual services  
ps aux | grep vps_backend
ps aux | grep vncserver
netstat -tlnp
```

### Logs
```bash
# Main application log
vps-logs

# All logs
ls -la /kaggle/working/logs/

# Specific service
tail -f /kaggle/working/logs/jupyter.log
```

## ⚡ Performance Tips

### Resource Optimization
- **GPU**: Use when needed, disable for CPU-only tasks
- **Memory**: Monitor usage, clean up large variables
- **Disk**: Regular cleanup of temp files and old backups
- **CPU**: Use multiprocessing for parallel tasks

### Session Management
- **Save frequently**: Don't lose work to timeouts
- **Monitor timeout**: ~12 hours maximum session length
- **Auto-save**: Enable for peace of mind
- **Quick restore**: Keep setup script bookmarked

## 🔒 Security Notes

- Default VNC password: `kaggle123` (change in setup)
- Services bind to localhost only (secure by default)
- No external network access to internal services
- Regular backup encryption recommended for sensitive data

## 🐛 Troubleshooting

### Common Issues

**"Control panel won't start"**
```bash
# Check if port is in use
netstat -tlnp | grep 5000

# Restart services
./stop_services.sh && ./start_control_panel.sh

# Check logs
tail -f /kaggle/working/logs/vps_control.log
```

**"VNC connection failed"**
```bash
# Restart VNC server
vncserver -kill :1
vncserver :1 -geometry 1280x720

# Check VNC logs
cat ~/.vnc/*.log
```

**"Backup restore failed"**
```bash
# Check backup integrity
unzip -t backup_file.zip

# Manual restore
python3 scripts/restore_backup.py --debug backup_file.zip
```

**"Out of disk space"**
```bash
# Clean up
rm -rf /tmp/*
rm /kaggle/working/logs/*.log.old
rm /kaggle/working/backups/old_backup_*.zip

# Check usage
du -sh /kaggle/working/* | sort -h
```

### Getting Help

1. **Check logs**: Most issues show up in `/kaggle/working/logs/`
2. **Health check**: Use the control panel's health check feature
3. **System info**: Run `scripts/system_info.sh` for diagnostics
4. **Reset**: Delete everything and run setup again

## 🤝 Contributing

Contributions welcome! Please read our contributing guidelines.

### Development Setup
```bash
git clone https://github.com/YOUR_USERNAME/kaggle-vps-control
cd kaggle-vps-control

# Test locally
python3 vps_backend.py
# Open http://localhost:5000
```

### Feature Requests
- Web-based IDE integration
- Database management interface
- Container support (Docker)
- Multi-user capabilities
- Mobile app companion

## 📝 License

MIT License - see LICENSE file for details.

## ⭐ Acknowledgments

- Kaggle for providing free GPU compute
- XFCE4 team for lightweight desktop
- Flask/nginx for web services
- Community contributors

---

**🎯 Turn your Kaggle kernel into a powerful development environment in minutes!**

**Star ⭐ this repo if it helps you!**
