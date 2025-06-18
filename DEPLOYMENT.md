# 🚀 MCP SSE Server - Deployment Guide

**Production-ready deployment options for the MCP SSE Server**

## 🎯 **Automated Deployment (Recommended)**

The fastest way to deploy on any Ubuntu machine:

```bash
# 1. Clone repository
git clone https://github.com/gitvj/mcp_sse_server.git
cd mcp_sse_server

# 2. Run automated deployment
./deploy.sh

# 3. Done! Server running with security enabled
```

The `deploy.sh` script automatically:
- ✅ Installs all dependencies (Node.js, npm, PM2)
- ✅ Installs MCP servers (TaskMaster-AI, Playwright, Puppeteer)
- ✅ Configures security (generates tokens, sets IP whitelist)
- ✅ Starts server with PM2 (persistent, auto-restart)
- ✅ Configures auto-start on system boot
- ✅ Sets up firewall rules

---

## 🔧 **Manual Deployment**

### **Prerequisites**
- Ubuntu 20.04+ (tested on 22.04)
- Node.js 20+ 
- npm/npx
- Internet connection for package installation

### **Step 1: System Dependencies**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 20 via NodeSource
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 globally
npm install -g pm2

# Install system dependencies
sudo apt install -y curl git ufw
```

### **Step 2: Clone and Setup**
```bash
# Clone repository
git clone https://github.com/gitvj/mcp_sse_server.git
cd mcp_sse_server

# Install Node.js dependencies
npm install

# Install MCP servers
npm install -g @modelcontextprotocol/server-filesystem
npm install -g @executeautomation/playwright-mcp-server
npm install -g @modelcontextprotocol/server-puppeteer
npm install -g taskmaster-ai
```

### **Step 3: Security Configuration**
```bash
# Run interactive security setup
./setup-secure.sh

# Or manual configuration
cp env.example .env
nano .env  # Edit with your settings
chmod 600 .env
```

### **Step 4: Start Server**
```bash
# Start with PM2 (recommended)
npm run pm2:secure

# Configure auto-start
pm2 startup
pm2 save

# Or start in background
npm run background:secure
```

### **Step 5: Firewall Configuration**
```bash
# Enable UFW firewall
sudo ufw enable

# Allow SSH (important!)
sudo ufw allow ssh

# Allow MCP server port
sudo ufw allow 3001

# Check status
sudo ufw status
```

---

## 🌐 **Cloud Deployment**

### **AWS EC2 Deployment**

#### **Launch Instance**
1. **Instance Type**: t2.micro or larger
2. **OS**: Ubuntu 22.04 LTS
3. **Security Group**: Allow inbound on port 3001
4. **Key Pair**: Create/use SSH key pair

#### **Security Group Rules**
```
Type        Protocol    Port    Source          Description
SSH         TCP         22      0.0.0.0/0      SSH access
Custom TCP  TCP         3001    0.0.0.0/0      MCP Server
```

#### **Deployment Commands**
```bash
# Connect to instance
ssh -i your-key.pem ubuntu@your-ec2-ip

# Deploy MCP server
git clone https://github.com/gitvj/mcp_sse_server.git
cd mcp_sse_server
./deploy.sh

# Your server is now accessible at http://your-ec2-ip:3001
```

### **Google Cloud Platform**

#### **Create VM Instance**
```bash
# Create instance
gcloud compute instances create mcp-server \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --machine-type=e2-micro \
    --zone=us-central1-a \
    --tags=mcp-server

# Create firewall rule
gcloud compute firewall-rules create allow-mcp-server \
    --allow tcp:3001 \
    --source-ranges 0.0.0.0/0 \
    --target-tags mcp-server
```

#### **Deploy to VM**
```bash
# SSH to instance
gcloud compute ssh mcp-server --zone=us-central1-a

# Deploy
git clone https://github.com/gitvj/mcp_sse_server.git
cd mcp_sse_server
./deploy.sh
```

### **DigitalOcean Droplet**

#### **Create Droplet**
1. **Image**: Ubuntu 22.04 LTS
2. **Size**: Basic $4/month (1GB RAM)
3. **Datacenter**: Choose closest region
4. **Authentication**: SSH key or password

#### **Deploy**
```bash
# SSH to droplet
ssh root@your-droplet-ip

# Deploy as ubuntu user
adduser ubuntu
usermod -aG sudo ubuntu
su - ubuntu

git clone https://github.com/gitvj/mcp_sse_server.git
cd mcp_sse_server
./deploy.sh
```

---

## 🐳 **Docker Deployment**

### **Using Docker Compose (Recommended)**

Create `docker-compose.yml`:
```yaml
version: '3.8'
services:
  mcp-sse-server:
    build: .
    ports:
      - "3001:3001"
    environment:
      - NODE_ENV=production
      - PORT=3001
    env_file:
      - .env
    restart: unless-stopped
    volumes:
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### **Dockerfile**
```dockerfile
FROM node:20-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache curl

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Create logs directory
RUN mkdir -p logs

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3001/health || exit 1

# Start server
CMD ["node", "server-secure.js"]
```

### **Deploy with Docker**
```bash
# Build and run
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Update
docker-compose pull && docker-compose up -d
```

---

## 🔄 **CI/CD Pipeline**

### **GitHub Actions Example**

`.github/workflows/deploy.yml`:
```yaml
name: Deploy MCP SSE Server

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to server
      uses: appleboy/ssh-action@v0.1.5
      with:
        host: ${{ secrets.SERVER_HOST }}
        username: ${{ secrets.SERVER_USER }}
        key: ${{ secrets.SERVER_SSH_KEY }}
        script: |
          cd /home/ubuntu/mcp_sse_server
          git pull origin main
          npm install
          pm2 restart mcp-sse-server-secure
```

---

## 📊 **Monitoring & Maintenance**

### **Server Monitoring**
```bash
# Check server status
pm2 status

# View logs
pm2 logs mcp-sse-server-secure

# Monitor resources
pm2 monit

# Check system resources
htop
df -h
free -h
```

### **Log Management**
```bash
# Rotate PM2 logs
pm2 install pm2-logrotate

# Configure log rotation
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7
```

### **Backup Strategy**
```bash
# Backup configuration
cp .env .env.backup.$(date +%Y%m%d)

# Backup server files
tar -czf mcp-sse-backup-$(date +%Y%m%d).tar.gz \
    .env package.json server-secure.js
```

### **Updates**
```bash
# Update MCP SSE Server
git pull origin main
npm install
pm2 restart mcp-sse-server-secure

# Update MCP servers
npm update -g taskmaster-ai
npm update -g @executeautomation/playwright-mcp-server
npm update -g @modelcontextprotocol/server-puppeteer
```

---

## 🚨 **Troubleshooting**

### **Common Issues**

#### **Port 3001 in use**
```bash
# Find what's using the port
sudo lsof -i :3001

# Kill the process
sudo fuser -k 3001/tcp
```

#### **Permission denied**
```bash
# Fix file permissions
chmod +x deploy.sh
chmod +x setup-secure.sh
chmod 600 .env
```

#### **Node.js not found**
```bash
# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

#### **PM2 not starting on boot**
```bash
# Setup PM2 startup
pm2 startup
# Follow the command it shows
pm2 save
```

### **Health Checks**
```bash
# Test server health
curl http://localhost:3001/health

# Test authentication
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:3001/mcp/servers

# Test from external machine
curl http://YOUR_SERVER_IP:3001/health
```

---

## 🔒 **Production Security**

### **SSL/HTTPS Setup**
For production, use a reverse proxy with SSL:

#### **Nginx with Let's Encrypt**
```bash
# Install Nginx
sudo apt install nginx

# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Configure Nginx
sudo nano /etc/nginx/sites-available/mcp-sse-server
```

Nginx config:
```nginx
server {
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/mcp-sse-server /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com
```

### **Additional Security**
```bash
# Enable fail2ban
sudo apt install fail2ban

# Configure firewall rules
sudo ufw allow 80
sudo ufw allow 443
sudo ufw deny 3001  # Only allow through Nginx
```

---

## 📈 **Scaling**

### **Load Balancing**
For high availability, use multiple instances:

```yaml
# docker-compose.yml
version: '3.8'
services:
  mcp-server-1:
    build: .
    ports:
      - "3001:3001"
    env_file: .env
    
  mcp-server-2:
    build: .
    ports:
      - "3002:3001"
    env_file: .env
    
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - mcp-server-1
      - mcp-server-2
```

### **Database Backend**
For persistent sessions and scaling:
```bash
# Use Redis for session storage
npm install redis connect-redis
```

---

## 🎯 **Next Steps**

1. **Choose deployment method** (automated script recommended)
2. **Configure security** (firewall, SSL, monitoring)
3. **Test functionality** (health checks, client connections)
4. **Set up monitoring** (logs, alerts, backups)
5. **Document access** (share credentials with team)

For support and advanced configurations, see:
- [SECURITY.md](./SECURITY.md) - Security configuration
- [CLIENT-GUIDE.md](./CLIENT-GUIDE.md) - Client integration
- [QUICK-START.md](./QUICK-START.md) - Quick reference 