#!/bin/bash

# MCP SSE Server - Persistent Startup Script
# This script provides multiple ways to run the server persistently

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_DIR="/home/ubuntu/mcp-sse-server"
SERVER_FILE="server.js"
PORT=3001

echo -e "${BLUE}🚀 MCP SSE Server - Persistent Startup${NC}"
echo "=================================================="

# Change to server directory
cd "$SERVER_DIR"

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js not found! Please install Node.js first.${NC}"
    exit 1
fi

# Check if server file exists
if [ ! -f "$SERVER_FILE" ]; then
    echo -e "${RED}❌ Server file '$SERVER_FILE' not found!${NC}"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    npm install
fi

# Create logs directory for PM2
mkdir -p logs

# Get IP addresses
PUBLIC_IP=$(curl -s --max-time 5 http://checkip.amazonaws.com || echo "Unable to get public IP")
PRIVATE_IP=$(hostname -I | awk '{print $1}' || echo "Unable to get private IP")

echo -e "${BLUE}📍 Server will be accessible at:${NC}"
if [ "$PUBLIC_IP" != "Unable to get public IP" ]; then
    echo -e "   🌐 Public:  http://$PUBLIC_IP:$PORT"
fi
echo -e "   🏠 Private: http://$PRIVATE_IP:$PORT"
echo -e "   🔒 Local:   http://localhost:$PORT"
echo ""

# Function to show menu
show_menu() {
    echo -e "${YELLOW}Choose how to run the server:${NC}"
    echo "1) PM2 (Recommended - Advanced process manager)"
    echo "2) Systemd (System service - auto-start on boot)"
    echo "3) Nohup (Simple background process)"
    echo "4) Screen (Terminal multiplexer)"
    echo "5) Check running processes"
    echo "6) Stop all instances"
    echo "7) View logs"
    echo "0) Exit"
    echo ""
}

# Function to install PM2
install_pm2() {
    if ! command -v pm2 &> /dev/null; then
        echo -e "${YELLOW}📦 Installing PM2...${NC}"
        npm install -g pm2
    fi
}

# Function to start with PM2
start_pm2() {
    install_pm2
    echo -e "${GREEN}🚀 Starting with PM2...${NC}"
    
    # Stop if already running
    pm2 delete mcp-sse-server 2>/dev/null || true
    
    # Start with ecosystem config
    if [ -f "ecosystem.config.js" ]; then
        pm2 start ecosystem.config.js
    else
        pm2 start "$SERVER_FILE" --name mcp-sse-server
    fi
    
    # Save PM2 configuration
    pm2 save
    
    # Setup auto-start on boot
    pm2 startup
    
    echo -e "${GREEN}✅ Server started with PM2!${NC}"
    echo -e "${BLUE}💡 Useful PM2 commands:${NC}"
    echo "   pm2 status          - Check status"
    echo "   pm2 logs            - View logs"
    echo "   pm2 restart all     - Restart server"
    echo "   pm2 stop all        - Stop server"
    echo "   pm2 delete all      - Remove from PM2"
}

# Function to setup systemd service
setup_systemd() {
    echo -e "${GREEN}🚀 Setting up Systemd service...${NC}"
    
    # Copy service file
    sudo cp mcp-sse-server.service /etc/systemd/system/
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    # Enable and start service
    sudo systemctl enable mcp-sse-server
    sudo systemctl start mcp-sse-server
    
    echo -e "${GREEN}✅ Systemd service installed and started!${NC}"
    echo -e "${BLUE}💡 Useful systemd commands:${NC}"
    echo "   sudo systemctl status mcp-sse-server    - Check status"
    echo "   sudo systemctl restart mcp-sse-server   - Restart"
    echo "   sudo systemctl stop mcp-sse-server      - Stop"
    echo "   sudo systemctl disable mcp-sse-server   - Disable auto-start"
    echo "   journalctl -u mcp-sse-server -f         - View logs"
}

# Function to start with nohup
start_nohup() {
    echo -e "${GREEN}🚀 Starting with nohup...${NC}"
    
    # Kill existing process
    pkill -f "node.*server.js" 2>/dev/null || true
    sleep 2
    
    # Start in background
    nohup node "$SERVER_FILE" > server.log 2>&1 &
    PID=$!
    
    echo -e "${GREEN}✅ Server started with PID: $PID${NC}"
    echo -e "${BLUE}💡 Useful commands:${NC}"
    echo "   tail -f server.log                    - View logs"
    echo "   ps aux | grep 'node.*server.js'      - Check process"
    echo "   pkill -f 'node.*server.js'           - Stop server"
}

# Function to start with screen
start_screen() {
    echo -e "${GREEN}🚀 Starting with screen...${NC}"
    
    # Install screen if not available
    if ! command -v screen &> /dev/null; then
        echo -e "${YELLOW}📦 Installing screen...${NC}"
        sudo apt-get update && sudo apt-get install -y screen
    fi
    
    # Kill existing screen session
    screen -S mcp-sse-server -X quit 2>/dev/null || true
    
    # Start new screen session
    screen -dmS mcp-sse-server node "$SERVER_FILE"
    
    echo -e "${GREEN}✅ Server started in screen session 'mcp-sse-server'${NC}"
    echo -e "${BLUE}💡 Useful screen commands:${NC}"
    echo "   screen -r mcp-sse-server              - Attach to session"
    echo "   screen -list                          - List sessions"
    echo "   Ctrl+A, D                             - Detach from session"
    echo "   screen -S mcp-sse-server -X quit      - Kill session"
}

# Function to check running processes
check_processes() {
    echo -e "${BLUE}🔍 Checking running processes...${NC}"
    echo ""
    
    # Check PM2
    if command -v pm2 &> /dev/null; then
        echo -e "${YELLOW}PM2 Processes:${NC}"
        pm2 status 2>/dev/null || echo "No PM2 processes running"
        echo ""
    fi
    
    # Check systemd
    echo -e "${YELLOW}Systemd Service:${NC}"
    sudo systemctl is-active mcp-sse-server 2>/dev/null || echo "Systemd service not running"
    echo ""
    
    # Check regular processes
    echo -e "${YELLOW}Node.js Processes:${NC}"
    ps aux | grep "node.*server.js" | grep -v grep || echo "No node server.js processes running"
    echo ""
    
    # Check screen sessions
    if command -v screen &> /dev/null; then
        echo -e "${YELLOW}Screen Sessions:${NC}"
        screen -list 2>/dev/null | grep mcp-sse-server || echo "No screen sessions running"
        echo ""
    fi
    
    # Check port
    echo -e "${YELLOW}Port $PORT Status:${NC}"
    if ss -tlnp | grep ":$PORT " > /dev/null; then
        echo -e "${GREEN}✅ Port $PORT is in use${NC}"
        ss -tlnp | grep ":$PORT "
    else
        echo -e "${RED}❌ Port $PORT is not in use${NC}"
    fi
}

# Function to stop all instances
stop_all() {
    echo -e "${YELLOW}🛑 Stopping all server instances...${NC}"
    
    # Stop PM2
    if command -v pm2 &> /dev/null; then
        pm2 delete mcp-sse-server 2>/dev/null || true
    fi
    
    # Stop systemd
    sudo systemctl stop mcp-sse-server 2>/dev/null || true
    
    # Kill node processes
    pkill -f "node.*server.js" 2>/dev/null || true
    
    # Kill screen sessions
    if command -v screen &> /dev/null; then
        screen -S mcp-sse-server -X quit 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ All instances stopped${NC}"
}

# Function to view logs
view_logs() {
    echo -e "${BLUE}📋 Available logs:${NC}"
    echo "1) PM2 logs"
    echo "2) Systemd logs"
    echo "3) Nohup logs (server.log)"
    echo "4) All available logs"
    echo ""
    read -p "Choose log to view (1-4): " log_choice
    
    case $log_choice in
        1)
            if command -v pm2 &> /dev/null; then
                pm2 logs mcp-sse-server
            else
                echo "PM2 not installed"
            fi
            ;;
        2)
            sudo journalctl -u mcp-sse-server -f
            ;;
        3)
            if [ -f "server.log" ]; then
                tail -f server.log
            else
                echo "server.log not found"
            fi
            ;;
        4)
            echo -e "${YELLOW}PM2 Logs:${NC}"
            command -v pm2 &> /dev/null && pm2 logs --lines 10 || echo "PM2 not available"
            echo ""
            echo -e "${YELLOW}Systemd Logs:${NC}"
            sudo journalctl -u mcp-sse-server --lines 10 || echo "Systemd service not available"
            echo ""
            echo -e "${YELLOW}Nohup Logs:${NC}"
            [ -f "server.log" ] && tail -10 server.log || echo "server.log not found"
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

# Main menu loop
while true; do
    show_menu
    read -p "Enter your choice (0-7): " choice
    echo ""
    
    case $choice in
        1)
            start_pm2
            ;;
        2)
            setup_systemd
            ;;
        3)
            start_nohup
            ;;
        4)
            start_screen
            ;;
        5)
            check_processes
            ;;
        6)
            stop_all
            ;;
        7)
            view_logs
            ;;
        0)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid choice. Please try again.${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    clear
done 