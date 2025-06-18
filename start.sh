#!/bin/bash

# MCP SSE Server Startup Script
echo "🚀 Starting MCP SSE Server..."

# Change to server directory
cd /home/ubuntu/mcp-sse-server

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Get the public IP of this machine
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
PRIVATE_IP=$(hostname -I | awk '{print $1}')

echo "📍 Server will be accessible at:"
echo "   🌐 Public:  http://$PUBLIC_IP:3001"
echo "   🏠 Private: http://$PRIVATE_IP:3001"
echo "   🔒 Local:   http://localhost:3001"
echo ""
echo "💡 Configure your firewall to allow port 3001 for external access"
echo "   AWS: Add inbound rule for port 3001 in Security Group"
echo "   UFW: sudo ufw allow 3001"
echo ""

# Start the server
echo "🎬 Starting server..."
npm start 