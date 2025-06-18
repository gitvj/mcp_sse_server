# 🚀 How MCP SSE Server Works

## 🏗️ Architecture

```
┌─────────────────┐    HTTP/SSE     ┌─────────────────┐    stdio pipes    ┌─────────────────┐
│   Remote Client │ ◄─────────────► │  SSE Server     │ ◄───────────────► │   MCP Servers   │
│   (Any Machine) │                 │  (Express.js)   │                   │  (subprocess)   │
└─────────────────┘                 └─────────────────┘                   └─────────────────┘
```

## 🔧 Components

### 1. **SSE Server (Express.js)**
- **Port**: 3001 (configurable)
- **Purpose**: HTTP API + Real-time SSE streams
- **Features**: CORS enabled, JSON-RPC proxy, process management

### 2. **MCP Process Manager**
- **Function**: Spawns MCP servers as child processes
- **Communication**: stdio pipes (stdin/stdout/stderr)
- **Tracking**: Process status, health monitoring

### 3. **Remote Access Layer**
- **HTTP API**: RESTful endpoints for control
- **SSE Streams**: Real-time data streaming
- **CORS**: Cross-origin support for web clients

## 📡 API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `GET` | `/mcp/servers` | List all MCP servers |
| `GET` | `/mcp/{server}/sse` | Real-time SSE stream |
| `POST` | `/mcp/{server}/start` | Start MCP server |
| `POST` | `/mcp/{server}/command` | Send JSON-RPC command |
| `POST` | `/mcp/{server}/stop` | Stop MCP server |

## 🆕 How to Add New MCP Servers

### Step 1: Install MCP Package

```bash
# NPM packages
npm install -g @your-org/mcp-server

# Cargo packages  
cargo install your-mcp-server

# Python packages
pip install your-mcp-server
```

### Step 2: Add to Configuration

Edit `server.js` and add to `mcpConfigs`:

```javascript
const mcpConfigs = {
    // Existing servers...
    
    'new-mcp-server': {
        command: 'your-mcp-command',  // or 'npx', 'python', etc.
        args: ['--arg1', 'value1'],   // command arguments
        env: {                        // environment variables
            API_KEY: "your-api-key",
            CONFIG_PATH: "/path/to/config"
        }
    }
};
```

### Step 3: Examples of Different MCP Types

#### **NPM Package MCP**
```javascript
'filesystem-mcp': {
    command: 'npx',
    args: ['-y', '@modelcontextprotocol/server-filesystem'],
    env: {}
}
```

#### **Python MCP**
```javascript
'python-mcp': {
    command: 'python',
    args: ['-m', 'your_mcp_module'],
    env: {
        PYTHONPATH: "/path/to/your/module"
    }
}
```

#### **Rust/Cargo MCP**
```javascript
'rust-mcp': {
    command: 'your-rust-mcp-binary',
    args: ['--config', '/path/to/config.toml'],
    env: {}
}
```

#### **Custom Script MCP**
```javascript
'custom-mcp': {
    command: 'bash',
    args: ['/path/to/your/mcp-script.sh'],
    env: {
        CUSTOM_VAR: "value"
    }
}
```

## 🌐 Usage Examples

### **From Web Browser**
```javascript
// Connect to SSE stream
const eventSource = new EventSource('http://52.66.183.104:3001/mcp/taskmaster-ai/sse');
eventSource.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log('MCP Output:', data);
};

// Send command
fetch('http://52.66.183.104:3001/mcp/taskmaster-ai/command', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "tools/list",
        params: {}
    })
});
```

### **From Terminal (curl)**
```bash
# List servers
curl http://52.66.183.104:3001/mcp/servers

# Start server
curl -X POST http://52.66.183.104:3001/mcp/taskmaster-ai/start

# Send command
curl -X POST http://52.66.183.104:3001/mcp/taskmaster-ai/command \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

### **From Python**
```python
import requests
import json
from sseclient import SSEClient

# List servers
response = requests.get('http://52.66.183.104:3001/mcp/servers')
print(response.json())

# Connect to SSE
messages = SSEClient('http://52.66.183.104:3001/mcp/taskmaster-ai/sse')
for msg in messages:
    if msg.data:
        data = json.loads(msg.data)
        print("Received:", data)
```

## 🔒 Security Considerations

### **Production Setup**
1. **Environment Variables**: Move API keys to `.env` file
2. **Authentication**: Add JWT/API key authentication
3. **Firewall**: Restrict access to specific IPs
4. **HTTPS**: Use SSL/TLS for encryption
5. **Rate Limiting**: Prevent abuse

### **Development vs Production**
```javascript
// Development (current)
const mcpConfigs = {
    'taskmaster-ai': {
        env: {
            ANTHROPIC_API_KEY: "hardcoded-key"  // ❌ Not secure
        }
    }
};

// Production (recommended)
const mcpConfigs = {
    'taskmaster-ai': {
        env: {
            ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY  // ✅ Secure
        }
    }
};
```

## 🚀 Persistent Server Operation & Auto-Startup

### **⚠️ The Problem**
When you run `node server.js` directly, the server stops when:
- Terminal window is closed
- SSH session disconnects  
- Text editor/IDE is closed
- Computer is restarted

### **✅ The Solutions**

#### **🎯 Quick Start (Recommended)**
```bash
# Run the interactive startup script
./start-persistent.sh

# Or choose a method directly:
npm run pm2:start     # Start with PM2
npm run background    # Start with nohup
```

---

## 🔧 Detailed Deployment Options

### **1. PM2 - Process Manager (⭐ RECOMMENDED)**
**Best for**: Production, auto-restart, monitoring, clustering

```bash
# Install PM2 globally
npm install -g pm2

# Start server with PM2
pm2 start server.js --name mcp-sse-server

# Enable auto-start on system boot
pm2 startup
pm2 save

# Useful PM2 commands
pm2 status           # Check status
pm2 logs             # View logs
pm2 restart all      # Restart
pm2 stop all         # Stop
pm2 delete all       # Remove from PM2
```

**PM2 with Ecosystem Config:**
```bash
# Start with advanced configuration
pm2 start ecosystem.config.js
```

### **2. Systemd Service (Auto-start on boot)**
**Best for**: System-level service, automatic startup

```bash
# Install the systemd service
sudo cp mcp-sse-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mcp-sse-server
sudo systemctl start mcp-sse-server

# Service commands
sudo systemctl status mcp-sse-server     # Check status
sudo systemctl restart mcp-sse-server    # Restart
sudo systemctl stop mcp-sse-server       # Stop
sudo systemctl disable mcp-sse-server    # Disable auto-start
journalctl -u mcp-sse-server -f          # View logs
```

### **3. Nohup (Simple Background Process)**
**Best for**: Quick background execution, development

```bash
# Start in background (survives terminal closure)
nohup node server.js > server.log 2>&1 &

# View logs
tail -f server.log

# Check if running
ps aux | grep "node.*server.js"

# Stop the process
pkill -f "node.*server.js"
```

### **4. Screen (Terminal Multiplexer)**
**Best for**: Development, easy attach/detach

```bash
# Install screen (if not available)
sudo apt-get install screen

# Start in screen session
screen -dmS mcp-sse-server node server.js

# Attach to session (to see output)
screen -r mcp-sse-server

# Detach from session (Ctrl+A, then D)
# Server keeps running in background

# List sessions
screen -list

# Kill session
screen -S mcp-sse-server -X quit
```

### **5. Docker (Containerized)**
**Best for**: Isolated environments, cloud deployment

**Dockerfile:**
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3001
CMD ["node", "server.js"]
```

**Commands:**
```bash
# Build image
docker build -t mcp-sse-server .

# Run container (detached)
docker run -d --name mcp-sse-server -p 3001:3001 mcp-sse-server

# View logs
docker logs -f mcp-sse-server

# Stop container
docker stop mcp-sse-server
```

### **6. Docker Compose (with auto-restart)**
**docker-compose.yml:**
```yaml
version: '3.8'
services:
  mcp-sse-server:
    build: .
    ports:
      - "3001:3001"
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - PORT=3001
```

```bash
# Start with auto-restart
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

---

## 🎛️ Interactive Management

### **All-in-One Script**
```bash
# Run the interactive management script
./start-persistent.sh
```

**Features:**
- ✅ Choose deployment method interactively
- ✅ Check running processes
- ✅ View logs from all methods
- ✅ Stop all instances
- ✅ Automatic dependency installation
- ✅ IP address detection

### **NPM Scripts**
```bash
npm start              # Regular start (stops when terminal closes)
npm run pm2:start      # Start with PM2
npm run pm2:stop       # Stop PM2 instance
npm run pm2:restart    # Restart PM2 instance
npm run pm2:logs       # View PM2 logs
npm run pm2:status     # Check PM2 status
npm run background     # Start with nohup in background
```

---

## 🚦 Auto-Start on System Boot

### **Method 1: PM2 (Recommended)**
```bash
pm2 startup    # Setup auto-start
pm2 save       # Save current processes
```

### **Method 2: Systemd Service**
```bash
sudo systemctl enable mcp-sse-server
```

### **Method 3: Crontab**
```bash
# Edit crontab
crontab -e

# Add this line for auto-start on boot
@reboot cd /home/ubuntu/mcp-sse-server && nohup node server.js > server.log 2>&1 &
```

### **Method 4: User Service (No sudo required)**
```bash
# Create user service directory
mkdir -p ~/.config/systemd/user

# Copy service file
cp mcp-sse-server.service ~/.config/systemd/user/

# Edit service file to remove sudo requirements
# Then enable
systemctl --user enable mcp-sse-server
systemctl --user start mcp-sse-server

# Enable lingering (start on boot without login)
sudo loginctl enable-linger ubuntu
```

## 🔧 Troubleshooting

### **Server Persistence Issues**

#### **🔍 Check What's Running**
```bash
# Use the interactive script
./start-persistent.sh
# Then choose option 5 (Check running processes)

# Or manually check:
ps aux | grep "node.*server.js"     # Check Node.js processes
pm2 status                          # Check PM2 processes  
sudo systemctl status mcp-sse-server # Check systemd service
screen -list                        # Check screen sessions
ss -tlnp | grep 3001               # Check if port is in use
```

#### **🛑 Stop All Instances**
```bash
# Use the script
./start-persistent.sh
# Then choose option 6 (Stop all instances)

# Or manually:
pkill -f "node.*server.js"           # Kill Node.js processes
pm2 delete all                       # Stop PM2 processes
sudo systemctl stop mcp-sse-server   # Stop systemd service
screen -S mcp-sse-server -X quit     # Kill screen session
```

#### **📋 View Logs**
```bash
# Use the script
./start-persistent.sh
# Then choose option 7 (View logs)

# Or manually:
pm2 logs mcp-sse-server             # PM2 logs
journalctl -u mcp-sse-server -f     # Systemd logs  
tail -f server.log                  # Nohup logs
docker logs -f mcp-sse-server       # Docker logs
```

### **Common Issues**

#### **1. Server Stops When Terminal Closes**
**Problem**: Using `node server.js` directly
**Solution**: Use any persistence method above

```bash
# ❌ Wrong - stops when terminal closes
node server.js

# ✅ Correct - persists after terminal closure
./start-persistent.sh  # Choose PM2 or nohup
```

#### **2. Port Already in Use**
**Problem**: Another process using port 3001
**Solution**: 
```bash
# Find what's using the port
ss -tlnp | grep 3001
lsof -i :3001

# Kill the process
sudo fuser -k 3001/tcp

# Or change port in server.js or environment
export PORT=3002
```

#### **3. Permission Denied**
**Problem**: Script not executable or systemd permissions
**Solution**:
```bash
# Make scripts executable
chmod +x start-persistent.sh
chmod +x start.sh

# For systemd service
sudo chown root:root mcp-sse-server.service
sudo chmod 644 mcp-sse-server.service
```

#### **4. Node.js Not Found in systemd**
**Problem**: systemd can't find Node.js installed via NVM
**Solution**: Update service file with full path
```bash
# Find Node.js path
which node

# Update mcp-sse-server.service with full path
ExecStart=/home/ubuntu/.nvm/versions/node/v20.15.1/bin/node server.js
```

#### **5. PM2 Not Starting on Boot**
**Problem**: PM2 auto-start not configured
**Solution**:
```bash
# Setup PM2 startup
pm2 startup
# Follow the displayed command (run with sudo)
pm2 save
```

#### **6. Environment Variables Missing**
**Problem**: API keys not loaded in persistent mode
**Solution**: 
```bash
# For PM2 - use ecosystem.config.js
pm2 start ecosystem.config.js

# For systemd - edit service file
sudo nano /etc/systemd/system/mcp-sse-server.service
# Add: Environment=ANTHROPIC_API_KEY=your_key

# For nohup - export before starting
export ANTHROPIC_API_KEY="your_key"
nohup node server.js > server.log 2>&1 &
```

#### **7. Server Not Accessible Externally**
**Problem**: Firewall blocking connections
**Solution**:
```bash
# For AWS EC2 - update Security Group
# Add inbound rule: Port 3001, Source 0.0.0.0/0

# For Ubuntu UFW
sudo ufw allow 3001

# Check firewall status
sudo ufw status
```

### **Debug Commands**

#### **System Information**
```bash
# Check system resources
free -h                    # Memory usage
df -h                     # Disk usage  
top                       # CPU usage
systemctl --failed        # Failed services

# Check network
netstat -tulpn | grep 3001  # Port usage
curl http://localhost:3001/  # Local connectivity
```

#### **Service-Specific Debugging**

**PM2 Debugging:**
```bash
pm2 info mcp-sse-server    # Detailed info
pm2 logs --lines 100       # Recent logs
pm2 monit                  # Real-time monitoring
pm2 describe mcp-sse-server # Process details
```

**Systemd Debugging:**
```bash
systemctl status mcp-sse-server --no-pager -l
journalctl -u mcp-sse-server --since "1 hour ago"
systemctl cat mcp-sse-server                      # Show service file
sudo systemctl daemon-reload                      # Reload after changes
```

**Docker Debugging:**
```bash
docker ps -a                    # All containers
docker inspect mcp-sse-server   # Container details
docker exec -it mcp-sse-server sh # Connect to container
```

#### **Network Debugging**
```bash
# Test server locally
curl -v http://localhost:3001/

# Test server externally (replace with your IP)
curl -v http://YOUR_IP:3001/

# Check DNS
nslookup YOUR_DOMAIN

# Test SSE endpoint
curl -N http://localhost:3001/mcp/taskmaster-ai/sse
```

## 🎯 Next Steps

1. **Start Demo**: `node demo-server.js` (simpler version)
2. **Configure Firewall**: AWS Security Group port 3001
3. **Test Remote Access**: `curl http://52.66.183.104:3001/`
4. **Add Your MCPs**: Follow the configuration examples above
5. **Deploy Production**: Use PM2 or Docker for reliability 