#!/bin/bash

# Secure MCP SSE Server Setup Script
# This script helps you configure security settings

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔒 Secure MCP SSE Server Setup${NC}"
echo "=================================="

# Change to script directory
cd "$(dirname "$0")"

# Check if .env already exists
if [ -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env file already exists!${NC}"
    read -p "Do you want to recreate it? (y/N): " recreate
    if [[ ! "$recreate" =~ ^[Yy]$ ]]; then
        echo "Using existing .env file..."
        cat .env
        echo ""
        echo -e "${GREEN}✅ Setup complete! Run: npm run secure${NC}"
        exit 0
    fi
fi

echo -e "${YELLOW}🔧 Setting up secure configuration...${NC}"

# Generate secure tokens
echo -e "${BLUE}🔑 Generating secure tokens...${NC}"
AUTH_TOKEN=$(openssl rand -hex 32)
SESSION_SECRET=$(openssl rand -hex 64)

# Get current IP
CURRENT_IP=$(curl -s --max-time 5 http://checkip.amazonaws.com || echo "")
PRIVATE_IP=$(hostname -I | awk '{print $1}' || echo "127.0.0.1")

echo -e "${BLUE}📍 Detected IPs:${NC}"
if [ -n "$CURRENT_IP" ]; then
    echo "  🌐 Public IP:  $CURRENT_IP"
fi
echo "  🏠 Private IP: $PRIVATE_IP"
echo "  🔒 Local IP:   127.0.0.1"

# Get user input for security settings
echo ""
echo -e "${YELLOW}🔐 Security Configuration:${NC}"

# IP Whitelist
echo -e "${BLUE}1. IP Address Whitelist${NC}"
echo "   Current IPs that will be allowed:"
echo "   - 127.0.0.1 (localhost)"
echo "   - ::1 (IPv6 localhost)"
if [ -n "$CURRENT_IP" ]; then
    echo "   - $CURRENT_IP (your public IP)"
fi
echo "   - $PRIVATE_IP (your private IP)"
echo ""
read -p "Add additional IPs (comma-separated, or press Enter to skip): " additional_ips

# Build IP list
ALLOWED_IPS="127.0.0.1,::1,$PRIVATE_IP"
if [ -n "$CURRENT_IP" ]; then
    ALLOWED_IPS="$ALLOWED_IPS,$CURRENT_IP"
fi
if [ -n "$additional_ips" ]; then
    ALLOWED_IPS="$ALLOWED_IPS,$additional_ips"
fi

# Authentication token
echo ""
echo -e "${BLUE}2. Authentication Token${NC}"
echo "   Generated secure token: ${AUTH_TOKEN:0:20}..."
read -p "Use custom token? (press Enter to use generated, or type custom): " custom_token
if [ -n "$custom_token" ]; then
    AUTH_TOKEN="$custom_token"
fi

# API Keys
echo ""
echo -e "${BLUE}3. API Keys${NC}"
echo "   Please provide your API keys (leave empty if not using):"
read -p "Anthropic API Key: " ANTHROPIC_KEY
read -p "Perplexity API Key: " PERPLEXITY_KEY

# CORS Origins
echo ""
echo -e "${BLUE}4. CORS Origins${NC}"
echo "   Which domains should be allowed to access your server?"
echo "   Examples: http://localhost:3000, https://yourdomain.com"
read -p "Allowed origins (comma-separated, or '*' for all): " cors_origins
if [ -z "$cors_origins" ]; then
    cors_origins="http://localhost:3000"
fi

# Create .env file
echo ""
echo -e "${YELLOW}📝 Creating .env file...${NC}"

cat > .env << EOF
# MCP SSE Server - Secure Configuration
# Generated on $(date)

# Server Configuration
PORT=3001
NODE_ENV=production

# Security Configuration
AUTH_TOKEN=$AUTH_TOKEN
ALLOWED_IPS=$ALLOWED_IPS
ALLOWED_ORIGINS=$cors_origins

# API Keys
ANTHROPIC_API_KEY=$ANTHROPIC_KEY
PERPLEXITY_API_KEY=$PERPLEXITY_KEY

# Rate Limiting (15 minutes window, 100 requests max)
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Session Security
SESSION_SECRET=$SESSION_SECRET
EOF

# Secure the .env file
chmod 600 .env

echo -e "${GREEN}✅ .env file created and secured!${NC}"

# Update package.json with secure script
echo -e "${YELLOW}📦 Adding secure script to package.json...${NC}"

# Check if secure script already exists
if grep -q '"secure"' package.json; then
    echo "Secure script already exists in package.json"
else
    # Add secure script
    sed -i '/"scripts": {/a\    "secure": "node server-secure.js",' package.json
    echo "Added 'secure' script to package.json"
fi

# Display configuration summary
echo ""
echo -e "${BLUE}📋 Configuration Summary:${NC}"
echo "  🔐 Auth Token: ${AUTH_TOKEN:0:20}... (32 chars)"
echo "  📍 Allowed IPs: $ALLOWED_IPS"
echo "  🌐 CORS Origins: $cors_origins"
echo "  🔑 API Keys: $([ -n "$ANTHROPIC_KEY" ] && echo "Anthropic ✅" || echo "Anthropic ❌") $([ -n "$PERPLEXITY_KEY" ] && echo "Perplexity ✅" || echo "Perplexity ❌")"
echo "  🛡️  Rate Limit: 100 requests per 15 minutes"

# Security recommendations
echo ""
echo -e "${YELLOW}🛡️  Security Recommendations:${NC}"
echo "  1. ✅ Keep your .env file secret (never commit to git)"
echo "  2. ✅ Use strong, unique authentication tokens"
echo "  3. ✅ Regularly rotate your API keys"
echo "  4. ✅ Monitor server logs for suspicious activity"
echo "  5. ✅ Use HTTPS in production"
echo "  6. ✅ Consider using a VPN for additional security"

# Test commands
echo ""
echo -e "${GREEN}🚀 Ready to start secure server!${NC}"
echo ""
echo -e "${BLUE}Commands:${NC}"
echo "  Start secure server:    npm run secure"
echo "  Test authentication:    curl -H 'Authorization: Bearer $AUTH_TOKEN' http://localhost:3001/"
echo "  Test without auth:      curl http://localhost:3001/"
echo "  View logs:              pm2 logs (if using PM2)"
echo ""

# Ask if user wants to start now
read -p "Start the secure server now? (Y/n): " start_now
if [[ ! "$start_now" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}🚀 Starting secure server...${NC}"
    
    # Stop insecure server if running
    pm2 delete mcp-sse-server 2>/dev/null || true
    pkill -f "node.*server.js" 2>/dev/null || true
    
    # Start secure server
    if command -v pm2 &> /dev/null; then
        pm2 start server-secure.js --name mcp-sse-server-secure
        echo -e "${GREEN}✅ Secure server started with PM2!${NC}"
        echo "Monitor with: pm2 logs mcp-sse-server-secure"
    else
        nohup npm run secure > secure-server.log 2>&1 &
        echo -e "${GREEN}✅ Secure server started in background!${NC}"
        echo "Monitor with: tail -f secure-server.log"
    fi
    
    sleep 2
    
    # Test the server
    echo -e "${YELLOW}🧪 Testing server...${NC}"
    if curl -s -H "Authorization: Bearer $AUTH_TOKEN" http://localhost:3001/health > /dev/null; then
        echo -e "${GREEN}✅ Secure server is responding!${NC}"
    else
        echo -e "${RED}❌ Server may not be responding yet. Check logs.${NC}"
    fi
else
    echo -e "${BLUE}💡 When ready, start with: npm run secure${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Secure setup complete!${NC}" 