# 🚀 MCP SSE Server - Quick Start Guide

## 🎯 The Problem
When you run `node server.js`, the server **stops** when you:
- Close the terminal
- Close your IDE/text editor  
- Disconnect from SSH
- Restart the computer

## ✅ The Solution

### **🔥 Super Quick Start**
```bash
# 1. Make script executable (one time only)
chmod +x start-persistent.sh

# 2. Run interactive script
./start-persistent.sh

# 3. Choose option 1 (PM2) - RECOMMENDED
# 4. Done! Server now runs forever
```

---

## 🎛️ Available Commands

### **Starting the Server (Choose ONE)**
```bash
./start-persistent.sh          # Interactive menu (RECOMMENDED)
npm run pm2:start              # Start with PM2
npm run background             # Start with nohup  
npm start                      # Regular start (stops when terminal closes)
```

### **Managing the Server**
```bash
npm run pm2:status             # Check if running
npm run pm2:logs               # View logs
npm run pm2:restart            # Restart server
npm run pm2:stop               # Stop server
```

### **Check What's Running**
```bash
./start-persistent.sh          # Choose option 5
# OR
ps aux | grep "node.*server.js"
pm2 status
ss -tlnp | grep 3001
```

---

## 🏆 Recommended Method: PM2

**Why PM2?**
- ✅ Survives terminal closure
- ✅ Auto-restarts if crashes
- ✅ Starts automatically on computer boot
- ✅ Built-in log management
- ✅ Easy monitoring

**Setup PM2 (one time):**
```bash
npm install -g pm2             # Install PM2
npm run pm2:start              # Start server
pm2 startup                    # Setup auto-start on boot
pm2 save                       # Save configuration
```

**Daily Usage:**
```bash
pm2 status                     # Check status
pm2 logs                       # View logs  
pm2 restart all                # Restart if needed
```

---

## 🔧 Alternative Methods

### **Method 1: Nohup (Simple)**
```bash
npm run background             # Start in background
tail -f server.log             # View logs
pkill -f "node.*server.js"     # Stop server
```

### **Method 2: Systemd Service**
```bash
sudo cp mcp-sse-server.service /etc/systemd/system/
sudo systemctl enable mcp-sse-server
sudo systemctl start mcp-sse-server
```

### **Method 3: Screen Session**
```bash
screen -dmS mcp-sse-server node server.js
screen -r mcp-sse-server       # Attach to session
# Ctrl+A, D to detach
```

---

## 🚦 Auto-Start on Boot

### **PM2 (Recommended)**
```bash
pm2 startup                    # One-time setup
pm2 save                       # Save current processes
```

### **Systemd Service**
```bash
sudo systemctl enable mcp-sse-server
```

### **Crontab**
```bash
crontab -e
# Add: @reboot cd /home/ubuntu/mcp-sse-server && npm run background
```

---

## 🆘 Quick Troubleshooting

### **Server not accessible?**
```bash
# Check if running
ss -tlnp | grep 3001

# Check firewall (AWS)
# Add inbound rule for port 3001 in Security Group

# Check firewall (Ubuntu)
sudo ufw allow 3001
```

### **Port already in use?**
```bash
sudo fuser -k 3001/tcp         # Kill process using port
```

### **Stop everything?**
```bash
./start-persistent.sh          # Choose option 6
# OR
pkill -f "node.*server.js"
pm2 delete all
```

---

## 📍 Access Your Server

Once running, your server is available at:
- **Local**: http://localhost:3001
- **Network**: http://YOUR_IP:3001 (replace with your actual IP)

### **Get Your IP Address**
```bash
curl http://checkip.amazonaws.com     # Public IP
hostname -I | awk '{print $1}'       # Private IP
```

---

## 🎯 Next Steps

1. **Start the server**: `./start-persistent.sh` → Choose PM2
2. **Test it works**: `curl http://localhost:3001`
3. **Configure firewall**: Allow port 3001 for external access
4. **Use remotely**: Access from any machine via your IP

**Done!** Your MCP SSE Server now runs persistently. 🎉 