# 🔌 **MCP Client Integration Guide**

**How to connect MCP clients (like Claude Desktop) to your remote MCP SSE Server**

## 🎯 **The Challenge**

MCP clients expect **local processes** with stdio communication, but our SSE server provides **HTTP/SSE APIs**. We need a **proxy bridge** to connect them.

## ✅ **Solution: MCP Proxy Server**

The `mcp-proxy.js` acts as a **local MCP server** but forwards all requests to your remote SSE server with authentication.

```
┌─────────────────┐    stdio     ┌─────────────────┐    HTTP+Auth    ┌─────────────────┐
│   MCP Client    │ ◄──────────► │   MCP Proxy     │ ◄─────────────► │   SSE Server    │
│ (Claude Desktop)│              │  (mcp-proxy.js) │                 │ (Remote/Secure) │
└─────────────────┘              └─────────────────┘                 └─────────────────┘
```

## 🚀 **Setup Instructions**

### **Step 1: Download the Proxy**

```bash
# Clone the repository (or download mcp-proxy.js)
git clone https://github.com/gitvj/mcp_sse_server.git
cd mcp_sse_server
```

### **Step 2: Configure Authentication**

```bash
# Set your SSE server URL and auth token
export MCP_SSE_SERVER_URL="http://52.66.183.104:3001"
export MCP_SSE_AUTH_TOKEN="your-auth-token-here"

# Or create a .env file in the proxy directory
echo "MCP_SSE_SERVER_URL=http://52.66.183.104:3001" >> .env
echo "MCP_SSE_AUTH_TOKEN=your-auth-token-here" >> .env
```

### **Step 3: Test the Proxy**

```bash
# Test the proxy with playwright1
node mcp-proxy.js playwright1

# Test with other servers
node mcp-proxy.js taskmaster-ai
node mcp-proxy.js github
node mcp-proxy.js doerdo-db
```

### **Step 4: Configure MCP Client**

For **Claude Desktop**, update your MCP configuration:

```json
{
  "mcpServers": {
    "playwright1": {
      "command": "node",
      "args": ["/path/to/mcp_sse_server/mcp-proxy.js", "playwright1"],
      "env": {
        "MCP_SSE_SERVER_URL": "http://52.66.183.104:3001",
        "MCP_SSE_AUTH_TOKEN": "your-auth-token-here"
      }
    },
    "taskmaster-ai": {
      "command": "node", 
      "args": ["/path/to/mcp_sse_server/mcp-proxy.js", "taskmaster-ai"],
      "env": {
        "MCP_SSE_SERVER_URL": "http://52.66.183.104:3001",
        "MCP_SSE_AUTH_TOKEN": "your-auth-token-here"
      }
    },
    "github": {
      "command": "node",
      "args": ["/path/to/mcp_sse_server/mcp-proxy.js", "github"],
      "env": {
        "MCP_SSE_SERVER_URL": "http://52.66.183.104:3001", 
        "MCP_SSE_AUTH_TOKEN": "your-auth-token-here"
      }
    },
    "doerdo-db": {
      "command": "node",
      "args": ["/path/to/mcp_sse_server/mcp-proxy.js", "doerdo-db"],
      "env": {
        "MCP_SSE_SERVER_URL": "http://52.66.183.104:3001",
        "MCP_SSE_AUTH_TOKEN": "your-auth-token-here"
      }
    }
  }
}
```

## 🔧 **Available Remote Servers**

All these servers are available through the proxy:

| Server Name | Purpose | Proxy Command |
|-------------|---------|---------------|
| `taskmaster-ai` | Project management & automation | `node mcp-proxy.js taskmaster-ai` |
| `playwright1` | Web automation (v1) | `node mcp-proxy.js playwright1` |
| `playwright2` | Web automation (v2) | `node mcp-proxy.js playwright2` |
| `puppeteer` | Web scraping & PDF generation | `node mcp-proxy.js puppeteer` |
| `doerdo-db` | PostgreSQL operations (Python/UV) | `node mcp-proxy.js doerdo-db` |
| `doerai-db` | PostgreSQL operations (Node.js) | `node mcp-proxy.js doerai-db` |
| `github` | GitHub repository operations | `node mcp-proxy.js github` |
| `context7` | Upstash Context7 operations | `node mcp-proxy.js context7` |
| `sequential-thinking` | Sequential thinking operations | `node mcp-proxy.js sequential-thinking` |

## 🧪 **Testing Your Setup**

### **1. Test Proxy Connection**

```bash
# Test if proxy can connect to remote server
node mcp-proxy.js playwright1 2>&1 | grep "Proxy ready"
```

### **2. Test Command Forwarding**

```bash
# Send a test command
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | node mcp-proxy.js playwright1
```

### **3. Test in Claude Desktop**

1. Update your MCP configuration
2. Restart Claude Desktop
3. Check if the servers appear in the MCP panel
4. Try using the tools/capabilities

## 🔒 **Security Notes**

### **Token Security**
- ✅ Store tokens in environment variables, not in config files
- ✅ Use different tokens for different users/environments
- ✅ Rotate tokens regularly

### **Network Security**
- ✅ Ensure your IP is whitelisted on the SSE server
- ✅ Use HTTPS in production environments
- ✅ Consider VPN for additional security

## 🚨 **Troubleshooting**

### **Common Issues**

#### **"Auth token required" Error**
```bash
# Make sure token is set
echo $MCP_SSE_AUTH_TOKEN
# Should output your token, not empty
```

#### **"Connection refused" Error**
```bash
# Test if SSE server is reachable
curl http://52.66.183.104:3001/health
# Should return: {"status":"healthy",...}
```

#### **"IP not authorized" Error**
- Check if your IP is in the ALLOWED_IPS list on the server
- Contact server administrator to whitelist your IP

#### **Proxy not starting**
```bash
# Check Node.js version
node --version
# Should be v14 or higher

# Check proxy file permissions
ls -la mcp-proxy.js
# Should be readable
```

### **Debug Mode**

Enable verbose logging:

```bash
# Run with debug output
DEBUG=1 node mcp-proxy.js playwright1
```

## 📈 **Performance Considerations**

### **Latency**
- **Local MCP**: ~1-5ms response time
- **Remote MCP via Proxy**: ~50-200ms response time (depending on network)

### **Reliability**
- Proxy handles connection retries
- Remote server has health checks and auto-restart
- Network interruptions are handled gracefully

## 🔄 **Alternative Approaches**

### **Option B: Direct HTTP Integration**

For applications that can make HTTP requests directly:

```javascript
// Instead of MCP client, use HTTP API directly
const response = await fetch('http://52.66.183.104:3001/mcp/playwright1/command', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer your-token-here',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    command: {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/list",
      params: {}
    }
  })
});
```

### **Option C: Local Server Setup**

For maximum performance, run the MCP servers locally:

```json
{
  "mcpServers": {
    "playwright1": {
      "command": "npx",
      "args": ["-y", "@executeautomation/playwright-mcp-server"],
      "env": {}
    }
  }
}
```

## 🎯 **Best Practices**

1. **Use Proxy for MCP Clients** - When you need compatibility with existing MCP clients
2. **Use HTTP API for Web Apps** - When building web applications or services
3. **Use Local Setup for Development** - When developing/testing MCP functionality
4. **Use Remote for Production** - When you need centralized, secure, monitored MCP services

---

**Choose the approach that best fits your use case!** 

- **🔌 MCP Proxy** - Best for Claude Desktop and other MCP clients
- **🌐 HTTP API** - Best for web applications and custom integrations  
- **🏠 Local Setup** - Best for development and maximum performance 