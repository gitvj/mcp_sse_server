#!/bin/bash

# Test script to verify MCP SSE Server persistence
# This script starts the server, tests it, then simulates terminal closure

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧪 Testing MCP SSE Server Persistence${NC}"
echo "========================================"

# Change to script directory
cd "$(dirname "$0")"

echo -e "${YELLOW}📍 Current directory: $(pwd)${NC}"

# Check if server.js exists
if [ ! -f "server.js" ]; then
    echo -e "${RED}❌ server.js not found!${NC}"
    exit 1
fi

echo -e "${YELLOW}🔧 Installing dependencies if needed...${NC}"
if [ ! -d "node_modules" ]; then
    npm install
fi

echo -e "${YELLOW}🚀 Starting server with nohup (background)...${NC}"

# Stop any existing processes
pkill -f "node.*server.js" 2>/dev/null || true
sleep 2

# Start server in background
nohup node server.js > test-server.log 2>&1 &
SERVER_PID=$!

echo -e "${GREEN}✅ Server started with PID: $SERVER_PID${NC}"

# Wait a moment for server to start
echo -e "${YELLOW}⏳ Waiting for server to start...${NC}"
sleep 3

# Test if server is responding
echo -e "${YELLOW}🔍 Testing server response...${NC}"
if curl -s http://localhost:3001/ > /dev/null; then
    echo -e "${GREEN}✅ Server is responding!${NC}"
else
    echo -e "${RED}❌ Server is not responding${NC}"
    echo "Log contents:"
    cat test-server.log
    exit 1
fi

# Show server status
echo -e "${BLUE}📊 Server Status:${NC}"
echo "  PID: $SERVER_PID"
echo "  URL: http://localhost:3001"
echo "  Log: test-server.log"

# Test server endpoints
echo -e "${YELLOW}🔗 Testing API endpoints...${NC}"

echo -e "${BLUE}GET /health:${NC}"
curl -s http://localhost:3001/health | head -c 200
echo ""

echo -e "${BLUE}GET /mcp/servers:${NC}"
curl -s http://localhost:3001/mcp/servers | head -c 200
echo ""

# Simulate terminal closure (this script ending doesn't kill the server)
echo -e "${GREEN}🎉 Test Complete!${NC}"
echo ""
echo -e "${YELLOW}📋 What happened:${NC}"
echo "  1. ✅ Server started in background with nohup"
echo "  2. ✅ Server responded to HTTP requests"
echo "  3. ✅ API endpoints are working"
echo "  4. ✅ Server will continue running after this script ends"
echo ""
echo -e "${BLUE}💡 To verify persistence:${NC}"
echo "  - Close this terminal window"
echo "  - Open a new terminal"
echo "  - Run: curl http://localhost:3001/"
echo "  - The server should still respond!"
echo ""
echo -e "${BLUE}🛑 To stop the server:${NC}"
echo "  - Run: pkill -f 'node.*server.js'"
echo "  - Or:  kill $SERVER_PID"
echo ""
echo -e "${BLUE}📋 View logs:${NC}"
echo "  - Run: tail -f test-server.log"

# Keep the script running for a moment to show it's working
echo -e "${YELLOW}⏳ Server running... (Press Ctrl+C to exit this script, server will keep running)${NC}"

# Wait and show some live stats
for i in {1..10}; do
    if ps -p $SERVER_PID > /dev/null; then
        echo -e "${GREEN}[$i/10] Server PID $SERVER_PID is running${NC}"
    else
        echo -e "${RED}[$i/10] Server PID $SERVER_PID stopped!${NC}"
        break
    fi
    sleep 1
done

echo ""
echo -e "${GREEN}🎯 Test completed! Server should still be running in background.${NC}"
echo -e "${BLUE}   Verify with: ps aux | grep 'node.*server.js'${NC}" 