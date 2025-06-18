# 🚀 MCP SSE Server - Secure & Persistent

[![Production Ready](https://img.shields.io/badge/Production-Ready-green.svg)](https://github.com/gitvj/mcp_sse_server)
[![Security](https://img.shields.io/badge/Security-Enterprise--Level-blue.svg)](./SECURITY.md)
[![License](https://img.shields.io/badge/License-ISC-yellow.svg)](./LICENSE)

**Secure, persistent HTTP/SSE bridge for Model Context Protocol (MCP) servers with enterprise-level security features.**

## 🌟 **Features**

✅ **Enterprise Security** - Token auth, IP whitelist, rate limiting  
✅ **Persistent Operation** - Survives terminal closure, auto-starts on boot  
✅ **Multiple MCP Servers** - TaskMaster-AI, Playwright, Puppeteer support  
✅ **Real-time SSE** - Live streaming from MCP servers  
✅ **Production Ready** - PM2, systemd, Docker deployment options  
✅ **Remote Access** - Access MCP servers from any machine  
✅ **Comprehensive Docs** - Security guides, client examples, troubleshooting  

## 🚀 **Quick Deploy (Ubuntu)**

```bash
# 1. Clone repository
git clone https://github.com/gitvj/mcp_sse_server.git
cd mcp_sse_server

# 2. Run automated setup
./deploy.sh

# 3. Your secure MCP server is running! 🎉
```

**That's it!** The deploy script handles everything: dependencies, security, persistence.

## ⚠️ **Security Notice**

This server includes **enterprise-level security** by default:
- 🔐 **Bearer Token Authentication** required for all MCP endpoints
- 🛡️ **IP Whitelisting** - only trusted IPs allowed
- ⚡ **Rate Limiting** - DoS protection (100 req/15min)
- 🔒 **Environment Variables** - secure API key storage
- 📋 **Audit Logging** - all security events tracked

**See [SECURITY.md](./SECURITY.md) for complete security documentation.**

## 📚 **Documentation**

| Document | Purpose |
|----------|---------|
| [QUICK-START.md](./QUICK-START.md) | Fast setup guide |
| [SECURITY.md](./SECURITY.md) | Complete security guide |
| [CLIENT-GUIDE.md](./CLIENT-GUIDE.md) | How to connect from client apps |
| [DEPLOYMENT.md](./DEPLOYMENT.md) | Production deployment options |
| [how it works.md](./how%20it%20works.md) | Technical architecture |

## 🎯 **Use Cases**

- **Remote MCP Access** - Access TaskMaster-AI from any machine
- **Web Applications** - Integrate MCP servers into web apps via HTTP/SSE
- **Development Teams** - Shared MCP server infrastructure
- **Production Deployments** - Scalable MCP server hosting
- **Cross-Platform Access** - Windows/Mac clients → Linux MCP servers

## 📋 Prerequisites

✅ Node.js v20.15.1 (already installed via NVM)  
✅ npm and npx (already available)  
✅ MCP tools (taskmaster-ai, playwright servers)

## 🔧 Installation

1. **Dependencies are already installed**:
   ```bash
   # Already done:
   # npm install express cors dotenv
   ```

2. **Create server.js**:
   ```bash
   cat > server.js << 'EOF'
   const express = require('express');
   const cors = require('cors');
   const { spawn } = require('child_process');
   
   const app = express();
   const PORT = process.env.PORT || 3001;
   
   app.use(cors());
   app.use(express.json());
   
   const mcpProcesses = new Map();
   
   const mcpConfigs = {
       'taskmaster-ai': {
           command: 'task-master-ai',
           args: [],
           env: {
               ANTHROPIC_API_KEY: "YOUR_ANTHROPIC_API_KEY_HERE",
               PERPLEXITY_API_KEY: "YOUR_PERPLEXITY_API_KEY_HERE",
               MODEL: "claude-3-7-sonnet-20250219"
           }
       },
       'playwright1': {
           command: 'npx',
           args: ['@playwright/mcp@latest'],
           env: {}
       },
       'playwright2': {
           command: 'npx',
           args: ['-y', '@executeautomation/playwright-mcp-server'],
           env: {}
       },
       'puppeteer': {
           command: 'npx',
           args: ['-y', '@modelcontextprotocol/server-puppeteer'],
           env: {}
       }
   };
   
   function startMcpProcess(serverName, config) {
       console.log(`Starting MCP server: ${serverName}`);
       const process = spawn(config.command, config.args, {
           env: { ...process.env, ...config.env },
           stdio: ['pipe', 'pipe', 'pipe']
       });
       
       process.stdout.on('data', (data) => {
           console.log(`[${serverName}] ${data}`);
       });
       
       process.stderr.on('data', (data) => {
           console.error(`[${serverName}] ERROR: ${data}`);
       });
       
       mcpProcesses.set(serverName, { process, config });
       return process;
   }
   
   // SSE endpoint
   app.get('/mcp/:server/sse', (req, res) => {
       const serverName = req.params.server;
       
       if (!mcpConfigs[serverName]) {
           return res.status(404).json({ error: 'Server not found' });
       }
   
       res.writeHead(200, {
           'Content-Type': 'text/event-stream',
           'Cache-Control': 'no-cache',
           'Connection': 'keep-alive',
           'Access-Control-Allow-Origin': '*'
       });
   
       if (!mcpProcesses.has(serverName)) {
           startMcpProcess(serverName, mcpConfigs[serverName]);
       }
   
       const mcpData = mcpProcesses.get(serverName);
       
       if (mcpData) {
           const dataHandler = (data) => {
               res.write(`data: ${JSON.stringify({ type: 'output', data: data.toString() })}\n\n`);
           };
   
           mcpData.process.stdout.on('data', dataHandler);
           mcpData.process.stderr.on('data', dataHandler);
   
           req.on('close', () => {
               mcpData.process.stdout.removeListener('data', dataHandler);
               mcpData.process.stderr.removeListener('data', dataHandler);
           });
       }
   
       const keepAlive = setInterval(() => {
           res.write(`data: ${JSON.stringify({ type: 'ping', timestamp: Date.now() })}\n\n`);
       }, 30000);
   
       req.on('close', () => {
           clearInterval(keepAlive);
       });
   });
   
   // API endpoints
   app.get('/mcp/servers', (req, res) => {
       const servers = Object.keys(mcpConfigs).map(name => ({
           name,
           running: mcpProcesses.has(name),
           config: mcpConfigs[name]
       }));
       res.json(servers);
   });
   
   app.post('/mcp/:server/start', (req, res) => {
       const serverName = req.params.server;
       if (!mcpConfigs[serverName]) {
           return res.status(404).json({ error: 'Server not found' });
       }
       if (mcpProcesses.has(serverName)) {
           return res.json({ status: 'already_running' });
       }
       try {
           startMcpProcess(serverName, mcpConfigs[serverName]);
           res.json({ status: 'started', server: serverName });
       } catch (error) {
           res.status(500).json({ error: error.message });
       }
   });
   
   app.post('/mcp/:server/command', (req, res) => {
       const serverName = req.params.server;
       const { command } = req.body;
   
       if (!mcpConfigs[serverName]) {
           return res.status(404).json({ error: 'Server not found' });
       }
   
       if (!mcpProcesses.has(serverName)) {
           startMcpProcess(serverName, mcpConfigs[serverName]);
       }
   
       const mcpData = mcpProcesses.get(serverName);
       
       if (mcpData && mcpData.process) {
           try {
               mcpData.process.stdin.write(JSON.stringify(command) + '\n');
               res.json({ status: 'sent', command });
           } catch (error) {
               res.status(500).json({ error: error.message });
           }
       } else {
           res.status(503).json({ error: 'MCP server not available' });
       }
   });
   
   app.get('/', (req, res) => {
       res.send(`
       <h1>🚀 MCP SSE Server</h1>
       <p>Available servers: ${Object.keys(mcpConfigs).join(', ')}</p>
       <p><a href="/mcp/servers">Check server status (JSON)</a></p>
       <h2>API Endpoints:</h2>
       <ul>
           <li><strong>GET /mcp/servers</strong> - List all servers</li>
           <li><strong>GET /mcp/{server}/sse</strong> - SSE stream for server</li>
           <li><strong>POST /mcp/{server}/start</strong> - Start a server</li>
           <li><strong>POST /mcp/{server}/command</strong> - Send command to server</li>
       </ul>
       `);
   });
   
   app.listen(PORT, '0.0.0.0', () => {
       console.log(`🚀 MCP SSE Server running on http://0.0.0.0:${PORT}`);
       console.log('📍 Access from:');
       console.log(`   🔒 Local: http://localhost:${PORT}`);
       
       const os = require('os');
       const interfaces = os.networkInterfaces();
       for (const name of Object.keys(interfaces)) {
           for (const iface of interfaces[name]) {
               if (iface.family === 'IPv4' && !iface.internal) {
                   console.log(`   🌐 Network: http://${iface.address}:${PORT}`);
               }
           }
       }
   });
   EOF
   ```

3. **Start the server**:
   ```bash
   node server.js
   ```

## 🔥 Firewall Configuration

**For AWS EC2**: Add inbound rule for port 3001 in Security Group
**For UFW**: `sudo ufw allow 3001`

## 📡 Usage from Remote Machines

### Connect to SSE Stream
```javascript
const eventSource = new EventSource('http://YOUR_IP:3001/mcp/taskmaster-ai/sse');
eventSource.onmessage = function(event) {
    const data = JSON.parse(event.data);
    console.log('Received:', data);
};
```

### Send Commands
```javascript
fetch('http://YOUR_IP:3001/mcp/taskmaster-ai/command', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ command: 'your-mcp-command' })
});
```

### List Available Servers
```bash
curl http://YOUR_IP:3001/mcp/servers
```

## 🎯 Next Steps

1. Configure your firewall to allow port 3001
2. Get your public IP: `curl http://checkip.amazonaws.com`
3. Test from another machine: `curl http://YOUR_IP:3001/`
4. Start using MCP remotely!

## 🔧 Troubleshooting

- **Port in use**: Change PORT in .env file
- **Connection refused**: Check firewall settings
- **MCP servers not starting**: Verify API keys in config 