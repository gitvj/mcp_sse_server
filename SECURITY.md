# 🔒 MCP SSE Server Security Guide

## ⚠️ **CRITICAL SECURITY WARNING**

**Your current server (`server.js`) has NO SECURITY PROTECTION!**

❌ **Anyone on the internet can:**
- Access your MCP servers
- Use your API keys (Anthropic, Perplexity)
- Execute commands on your system
- View sensitive information

## 🛡️ **Secure Solution Available**

We've created a **secure version** (`server-secure.js`) with enterprise-level protection.

### **🚀 Quick Secure Setup**

```bash
# 1. Run security setup (interactive)
./setup-secure.sh

# 2. Start secure server
npm run secure

# 3. Test with authentication
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3001/
```

---

## 🔐 **Security Features Comparison**

| Feature | `server.js` (Current) | `server-secure.js` (Secure) |
|---------|----------------------|----------------------------|
| **Authentication** | ❌ None | ✅ Bearer Token |
| **IP Whitelist** | ❌ None | ✅ Configurable |
| **Rate Limiting** | ❌ None | ✅ 100 req/15min |
| **CORS Protection** | ❌ Wide open (`*`) | ✅ Restricted origins |
| **API Key Security** | ❌ Hardcoded | ✅ Environment variables |
| **Security Headers** | ❌ None | ✅ Helmet.js |
| **Session Management** | ❌ None | ✅ Secure sessions |
| **Audit Logging** | ❌ Basic | ✅ Detailed security logs |

---

## 🎯 **Security Levels**

### **Level 1: Basic Protection (Minimum)**
```bash
# IP-only access (block external access)
# Edit server.js, change:
app.listen(PORT, '127.0.0.1', () => {  // Only localhost
```

### **Level 2: Authentication Required**
```bash
# Use the secure server with basic config
./setup-secure.sh
npm run secure
```

### **Level 3: Enterprise Security (Recommended)**
```bash
# Full security setup with monitoring
./setup-secure.sh
# Configure restrictive IP whitelist
# Use strong authentication tokens
# Enable HTTPS
# Set up monitoring
```

---

## 🔧 **Secure Server Features**

### **🔑 Authentication**
- **Bearer Token**: All MCP endpoints require `Authorization: Bearer TOKEN`
- **Session Management**: 24-hour session expiry
- **Login/Logout**: Proper session handling

### **🛡️ IP Whitelisting**
- **Configurable**: Only specific IPs can access
- **Auto-detection**: Includes your current IP automatically
- **Flexible**: Add trusted IPs as needed

### **⚡ Rate Limiting**
- **Smart Throttling**: 100 requests per 15 minutes per IP
- **DoS Protection**: Prevents abuse and overload
- **Configurable**: Adjust limits in `.env`

### **🌐 CORS Protection**
- **Origin Restrictions**: Only trusted domains allowed
- **Credential Support**: Secure cookie handling
- **Flexible Configuration**: Environment-based

### **🔐 Environment Variables**
- **No Hardcoded Secrets**: All sensitive data in `.env`
- **Secure Storage**: File permissions restricted
- **Easy Rotation**: Update credentials without code changes

### **📋 Security Headers**
- **Helmet.js**: Industry-standard security headers
- **HSTS**: Force HTTPS in production
- **CSP**: Content Security Policy protection
- **XSS Protection**: Cross-site scripting prevention

---

## 🚀 **Migration Guide**

### **Step 1: Setup Secure Server**
```bash
# Stop current insecure server
pm2 delete mcp-sse-server

# Setup secure version
./setup-secure.sh
```

### **Step 2: Configure Security**
The setup script will ask for:
- **IP Whitelist**: Which IPs can access (your IP auto-detected)
- **Auth Token**: Secure access token (auto-generated)
- **API Keys**: Your Anthropic/Perplexity keys
- **CORS Origins**: Which domains can connect

### **Step 3: Start Secure Server**
```bash
# With PM2 (recommended)
npm run pm2:secure

# Or background
npm run background:secure

# Or direct
npm run secure
```

### **Step 4: Update Clients**
All clients must now include authentication:

```javascript
// Before (insecure)
fetch('http://your-ip:3001/mcp/servers')

// After (secure)
fetch('http://your-ip:3001/mcp/servers', {
    headers: {
        'Authorization': 'Bearer YOUR_TOKEN_HERE'
    }
})
```

---

## 🧪 **Testing Security**

### **Test Authentication**
```bash
# Should work (with valid token)
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3001/health

# Should fail (no token)
curl http://localhost:3001/health

# Should fail (wrong token)
curl -H "Authorization: Bearer wrong-token" http://localhost:3001/health
```

### **Test IP Whitelist**
```bash
# From allowed IP - should work
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3001/health

# From blocked IP - should fail with 403
# (Test from different machine/IP)
```

### **Test Rate Limiting**
```bash
# Rapid requests should eventually be rate limited
for i in {1..150}; do
  curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3001/health
done
```

---

## 🛠️ **Configuration Options**

### **Environment Variables (.env)**
```bash
# Security
AUTH_TOKEN=your-secret-token-here
ALLOWED_IPS=127.0.0.1,your-ip-here
ALLOWED_ORIGINS=http://localhost:3000,https://yourdomain.com

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000    # 15 minutes
RATE_LIMIT_MAX_REQUESTS=100    # Max requests per window

# Session
SESSION_SECRET=your-session-secret
```

### **IP Whitelist Examples**
```bash
# Local only
ALLOWED_IPS=127.0.0.1,::1

# Specific IPs
ALLOWED_IPS=127.0.0.1,192.168.1.100,203.0.113.1

# Development (allow all - NOT for production)
ALLOWED_IPS=0.0.0.0
```

### **CORS Origins Examples**
```bash
# Local development
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001

# Production
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com

# Multiple environments
ALLOWED_ORIGINS=http://localhost:3000,https://staging.domain.com,https://prod.domain.com
```

---

## 🚨 **Security Incidents**

### **If You Suspect Unauthorized Access**

1. **Immediate Actions:**
   ```bash
   # Stop all servers
   pm2 delete all
   pkill -f "node.*server"
   
   # Change authentication token
   nano .env  # Update AUTH_TOKEN
   
   # Restart with new token
   npm run pm2:secure
   ```

2. **Investigation:**
   ```bash
   # Check server logs
   pm2 logs mcp-sse-server-secure
   
   # Check system logs
   sudo journalctl -u mcp-sse-server -f
   
   # Check network connections
   ss -tlnp | grep 3001
   ```

3. **Prevention:**
   ```bash
   # Rotate API keys
   # Update IP whitelist
   # Review security logs
   # Consider additional firewall rules
   ```

---

## 📊 **Monitoring & Logging**

### **Security Logs**
The secure server logs all security events:
- Authentication attempts (success/failure)
- IP access denials
- Rate limit violations
- Command executions
- Session activities

### **Log Locations**
```bash
# PM2 logs
pm2 logs mcp-sse-server-secure

# Background logs
tail -f secure-server.log

# System logs (if using systemd)
sudo journalctl -u mcp-sse-server -f
```

### **Log Analysis**
```bash
# Failed authentication attempts
grep "Invalid token" secure-server.log

# Blocked IP attempts
grep "Access denied" secure-server.log

# Rate limit violations
grep "Too many requests" secure-server.log
```

---

## 🏆 **Best Practices**

### **🔐 Authentication**
- ✅ Use strong, unique tokens (32+ characters)
- ✅ Rotate tokens regularly (monthly)
- ✅ Never share tokens in plain text
- ✅ Use environment variables, not hardcoded values

### **🌐 Network Security**
- ✅ Restrict IP access to trusted sources only
- ✅ Use HTTPS in production (add SSL certificate)
- ✅ Consider VPN for additional security layer
- ✅ Configure firewall rules appropriately

### **📝 Operational Security**
- ✅ Monitor logs regularly
- ✅ Keep dependencies updated
- ✅ Use strong server passwords
- ✅ Enable system firewalls
- ✅ Regular security audits

### **🔑 Secrets Management**
- ✅ Keep `.env` file secure (chmod 600)
- ✅ Never commit secrets to git
- ✅ Use separate tokens for different environments
- ✅ Have incident response plan ready

---

## 🚀 **Production Deployment**

### **Additional Security for Production**

1. **HTTPS/SSL**
   ```bash
   # Add SSL certificate
   # Configure nginx/apache reverse proxy
   # Force HTTPS redirects
   ```

2. **Advanced Firewalls**
   ```bash
   # Configure UFW/iptables
   sudo ufw allow from TRUSTED_IP to any port 3001
   sudo ufw deny 3001
   ```

3. **Monitoring**
   ```bash
   # Set up log monitoring
   # Configure alerting
   # Use intrusion detection
   ```

4. **Backups**
   ```bash
   # Regular configuration backups
   # API key rotation procedures
   # Disaster recovery plan
   ```

---

## 🎯 **Next Steps**

1. **🔒 Secure Now**: Run `./setup-secure.sh` immediately
2. **🧪 Test**: Verify authentication and IP restrictions work
3. **📋 Monitor**: Check logs for security events
4. **🔄 Maintain**: Regular token rotation and updates
5. **📈 Scale**: Consider additional security measures for production

**Remember: Security is not optional - it's essential!** 🛡️ 