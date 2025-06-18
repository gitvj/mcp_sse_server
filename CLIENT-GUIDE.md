# 🔌 MCP SSE Server - Client Guide

**How to connect to your secure MCP SSE server from client applications**

## 🔑 **Authentication Requirements**

All MCP endpoints require authentication using a **Bearer Token** in the Authorization header:

```
Authorization: Bearer YOUR_AUTH_TOKEN_HERE
```

⚠️ **Get your token**: Check your server's `.env` file for `AUTH_TOKEN` value.

---

## 🌐 **Server Endpoints**

### **Base URLs**
- **Local**: `http://localhost:3001` (from server machine)
- **Remote**: `http://YOUR_SERVER_IP:3001` (from other machines)

### **Public Endpoints** (No authentication required)
- `GET /health` - Server health check

### **Protected Endpoints** (Authentication required)
- `GET /` - Dashboard
- `GET /mcp/servers` - List available MCP servers
- `GET /mcp/{server}/sse` - Real-time SSE stream
- `POST /mcp/{server}/start` - Start MCP server
- `POST /mcp/{server}/stop` - Stop MCP server
- `POST /mcp/{server}/command` - Send command to MCP server

---

## 💻 **Client Examples**

### **1. JavaScript/Browser**

#### **Basic Request**
```javascript
const token = 'YOUR_AUTH_TOKEN_HERE';
const serverUrl = 'http://YOUR_SERVER_IP:3001';

// List available MCP servers
async function listServers() {
    const response = await fetch(`${serverUrl}/mcp/servers`, {
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        }
    });
    
    if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    console.log('Available servers:', data.servers);
    return data;
}

// Start a server
async function startServer(serverName) {
    const response = await fetch(`${serverUrl}/mcp/${serverName}/start`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        }
    });
    
    const result = await response.json();
    console.log(`Server ${serverName}:`, result.status);
    return result;
}
```

#### **Server-Sent Events (SSE)**
```javascript
// Connect to real-time stream
function connectToMCP(serverName) {
    const eventSource = new EventSource(
        `${serverUrl}/mcp/${serverName}/sse`, 
        {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        }
    );
    
    eventSource.onopen = () => {
        console.log(`Connected to ${serverName}`);
    };
    
    eventSource.onmessage = (event) => {
        const data = JSON.parse(event.data);
        console.log(`[${serverName}]`, data);
        
        if (data.type === 'output') {
            console.log('MCP Output:', data.data);
        } else if (data.type === 'ping') {
            console.log('Keep-alive ping');
        }
    };
    
    eventSource.onerror = (error) => {
        console.error('SSE Error:', error);
    };
    
    return eventSource;
}

// Usage
const taskmaster = connectToMCP('taskmaster-ai');
```

#### **Send Commands to MCP**
```javascript
async function sendCommand(serverName, command) {
    const response = await fetch(`${serverUrl}/mcp/${serverName}/command`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            command: command
        })
    });
    
    const result = await response.json();
    console.log('Command result:', result);
    return result;
}

// Example: Send command to TaskMaster-AI
await sendCommand('taskmaster-ai', {
    jsonrpc: "2.0",
    id: 1,
    method: "tools/list",
    params: {}
});
```

### **2. Python Client**

#### **Basic Python Client**
```python
import requests
import json
from sseclient import SSEClient

class MCPClient:
    def __init__(self, server_url, auth_token):
        self.server_url = server_url
        self.headers = {
            'Authorization': f'Bearer {auth_token}',
            'Content-Type': 'application/json'
        }
    
    def list_servers(self):
        """Get list of available MCP servers"""
        response = requests.get(
            f'{self.server_url}/mcp/servers',
            headers=self.headers
        )
        response.raise_for_status()
        return response.json()
    
    def start_server(self, server_name):
        """Start an MCP server"""
        response = requests.post(
            f'{self.server_url}/mcp/{server_name}/start',
            headers=self.headers
        )
        response.raise_for_status()
        return response.json()
    
    def send_command(self, server_name, command):
        """Send command to MCP server"""
        response = requests.post(
            f'{self.server_url}/mcp/{server_name}/command',
            headers=self.headers,
            json={'command': command}
        )
        response.raise_for_status()
        return response.json()
    
    def stream_events(self, server_name):
        """Connect to SSE stream"""
        url = f'{self.server_url}/mcp/{server_name}/sse'
        
        # Note: SSEClient doesn't support custom headers well
        # You may need to use a different approach for SSE with auth
        messages = SSEClient(url)
        
        for msg in messages:
            if msg.data:
                yield json.loads(msg.data)

# Usage
client = MCPClient('http://YOUR_SERVER_IP:3001', 'YOUR_AUTH_TOKEN')

# List servers
servers = client.list_servers()
print("Available servers:", servers)

# Start TaskMaster-AI
result = client.start_server('taskmaster-ai')
print("Start result:", result)

# Send command
command_result = client.send_command('taskmaster-ai', {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
})
print("Command result:", command_result)
```

### **3. cURL Examples**

#### **Health Check (No Auth)**
```bash
curl http://YOUR_SERVER_IP:3001/health
```

#### **List Servers**
```bash
curl -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
     http://YOUR_SERVER_IP:3001/mcp/servers
```

#### **Start Server**
```bash
curl -X POST \
     -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
     -H "Content-Type: application/json" \
     http://YOUR_SERVER_IP:3001/mcp/taskmaster-ai/start
```

#### **Send Command**
```bash
curl -X POST \
     -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"command":{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}}' \
     http://YOUR_SERVER_IP:3001/mcp/taskmaster-ai/command
```

#### **Connect to SSE Stream**
```bash
curl -N \
     -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
     http://YOUR_SERVER_IP:3001/mcp/taskmaster-ai/sse
```

### **4. Node.js Client**

```javascript
const axios = require('axios');
const EventSource = require('eventsource');

class MCPClient {
    constructor(serverUrl, authToken) {
        this.serverUrl = serverUrl;
        this.authToken = authToken;
        this.headers = {
            'Authorization': `Bearer ${authToken}`,
            'Content-Type': 'application/json'
        };
    }
    
    async listServers() {
        const response = await axios.get(
            `${this.serverUrl}/mcp/servers`,
            { headers: this.headers }
        );
        return response.data;
    }
    
    async startServer(serverName) {
        const response = await axios.post(
            `${this.serverUrl}/mcp/${serverName}/start`,
            {},
            { headers: this.headers }
        );
        return response.data;
    }
    
    async sendCommand(serverName, command) {
        const response = await axios.post(
            `${this.serverUrl}/mcp/${serverName}/command`,
            { command },
            { headers: this.headers }
        );
        return response.data;
    }
    
    connectSSE(serverName) {
        const eventSource = new EventSource(
            `${this.serverUrl}/mcp/${serverName}/sse`,
            { headers: this.headers }
        );
        
        return eventSource;
    }
}

// Usage
const client = new MCPClient('http://YOUR_SERVER_IP:3001', 'YOUR_AUTH_TOKEN');

(async () => {
    try {
        // List available servers
        const servers = await client.listServers();
        console.log('Servers:', servers);
        
        // Start TaskMaster-AI
        await client.startServer('taskmaster-ai');
        
        // Connect to SSE stream
        const sse = client.connectSSE('taskmaster-ai');
        sse.onmessage = (event) => {
            const data = JSON.parse(event.data);
            console.log('SSE:', data);
        };
        
    } catch (error) {
        console.error('Error:', error.response?.data || error.message);
    }
})();
```

---

## 🔧 **Available MCP Servers**

| Server | Purpose | Status |
|--------|---------|--------|
| **taskmaster-ai** | Project management, task automation | ✅ Ready |
| **playwright1** | Web automation, testing | ✅ Ready |
| **playwright2** | Enhanced web automation | ✅ Ready |
| **puppeteer** | Web scraping, PDF generation | ✅ Ready |
| **doerdo-db** | PostgreSQL database operations (UV/Python) | ✅ Ready |
| **doerai-db** | PostgreSQL database operations (Node.js) | ✅ Ready |
| **github** | GitHub repository operations | ✅ Ready |
| **context7** | Upstash Context7 operations | ✅ Ready |
| **sequential-thinking** | Sequential thinking operations | ✅ Ready |

---

## 🚨 **Error Handling**

### **Common HTTP Status Codes**
- `200` - Success
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (IP not whitelisted)
- `404` - Server/endpoint not found
- `429` - Rate limited (too many requests)
- `500` - Internal server error

### **Example Error Responses**
```json
// Missing authentication
{
  "error": "Access token required",
  "message": "Please provide a valid authorization token in the Authorization header"
}

// Invalid token
{
  "error": "Invalid token",
  "message": "The provided authorization token is invalid"
}

// IP not allowed
{
  "error": "Access denied",
  "message": "Your IP address is not authorized to access this server.",
  "ip": "203.0.113.1"
}

// Rate limited
{
  "error": "Too many requests from this IP, please try again later.",
  "retryAfter": 900
}
```

---

## 🔒 **Security Best Practices**

### **1. Token Security**
- ✅ Store tokens securely (environment variables, secure storage)
- ✅ Never log or expose tokens in client-side code
- ✅ Use HTTPS in production
- ✅ Rotate tokens regularly

### **2. Network Security**
- ✅ Use VPN for additional security
- ✅ Ensure your IP is whitelisted on the server
- ✅ Consider using SSH tunnels for extra protection

### **3. Error Handling**
- ✅ Implement proper retry logic for rate limiting
- ✅ Handle authentication failures gracefully
- ✅ Log security events appropriately

---

## 🧪 **Testing Your Connection**

### **Quick Connection Test**
```bash
# 1. Test server is reachable
curl http://YOUR_SERVER_IP:3001/health

# 2. Test authentication
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://YOUR_SERVER_IP:3001/mcp/servers

# 3. Test MCP functionality
curl -X POST \
     -H "Authorization: Bearer YOUR_TOKEN" \
     http://YOUR_SERVER_IP:3001/mcp/taskmaster-ai/start
```

### **Debugging Connection Issues**

1. **Can't connect to server**
   - Check if server is running: `pm2 status`
   - Verify port 3001 is open in firewall
   - Check server IP address

2. **Authentication failed**
   - Verify token in server's `.env` file
   - Check Authorization header format
   - Ensure token is not expired

3. **IP access denied**
   - Check if your IP is in `ALLOWED_IPS` in `.env`
   - Update IP whitelist: add your IP and restart server

4. **Rate limited**
   - Wait for rate limit window to reset (15 minutes)
   - Reduce request frequency
   - Check rate limits in server configuration

---

## 📚 **Next Steps**

1. **Get your authentication token** from server administrator
2. **Verify your IP is whitelisted** on the server
3. **Test connection** with health endpoint
4. **Start building** your client application
5. **Monitor server logs** for any issues

For more advanced usage and production deployment, see:
- [SECURITY.md](./SECURITY.md) - Security configuration
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Production deployment
- [how it works.md](./how%20it%20works.md) - Technical details 