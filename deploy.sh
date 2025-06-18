#!/bin/bash

# MCP SSE Server - Automated Deployment Script
# This script sets up everything needed for the MCP SSE Server on Ubuntu

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/deploy.log"
NODE_VERSION="20"

# Function to log and print messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "STEP")
            echo -e "${PURPLE}[STEP]${NC} $message"
            ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get system info
get_system_info() {
    log_message "INFO" "Gathering system information..."
    
    OS_NAME=$(lsb_release -si 2>/dev/null || echo "Unknown")
    OS_VERSION=$(lsb_release -sr 2>/dev/null || echo "Unknown")
    ARCH=$(uname -m)
    
    log_message "INFO" "OS: $OS_NAME $OS_VERSION ($ARCH)"
    
    # Check if Ubuntu
    if [[ "$OS_NAME" != "Ubuntu" ]]; then
        log_message "WARNING" "This script is designed for Ubuntu. Proceeding anyway..."
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log_message "STEP" "Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_message "ERROR" "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
    
    # Check sudo privileges
    if ! sudo -n true 2>/dev/null; then
        log_message "INFO" "Checking sudo privileges..."
        sudo -v
    fi
    
    # Check internet connectivity
    if ! curl -s --max-time 5 http://checkip.amazonaws.com >/dev/null; then
        log_message "ERROR" "No internet connection detected. Please check your network."
        exit 1
    fi
    
    log_message "SUCCESS" "Prerequisites check passed"
}

# Function to install system dependencies
install_system_dependencies() {
    log_message "STEP" "Installing system dependencies..."
    
    # Update package list
    log_message "INFO" "Updating package lists..."
    sudo apt update
    
    # Install essential packages
    log_message "INFO" "Installing essential packages..."
    sudo apt install -y \
        curl \
        wget \
        git \
        build-essential \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        ufw \
        htop \
        unzip
    
    log_message "SUCCESS" "System dependencies installed"
}

# Function to install Node.js
install_nodejs() {
    log_message "STEP" "Installing Node.js $NODE_VERSION..."
    
    if command_exists node; then
        local current_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$current_version" -ge "$NODE_VERSION" ]]; then
            log_message "SUCCESS" "Node.js $(node -v) already installed"
            return 0
        fi
    fi
    
    # Install Node.js via NodeSource
    log_message "INFO" "Adding NodeSource repository..."
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
    
    log_message "INFO" "Installing Node.js..."
    sudo apt-get install -y nodejs
    
    # Verify installation
    if command_exists node && command_exists npm; then
        log_message "SUCCESS" "Node.js $(node -v) and npm $(npm -v) installed successfully"
    else
        log_message "ERROR" "Failed to install Node.js"
        exit 1
    fi
}

# Function to install PM2
install_pm2() {
    log_message "STEP" "Installing PM2 process manager..."
    
    if command_exists pm2; then
        log_message "SUCCESS" "PM2 already installed"
        return 0
    fi
    
    log_message "INFO" "Installing PM2 globally..."
    sudo npm install -g pm2
    
    if command_exists pm2; then
        log_message "SUCCESS" "PM2 installed successfully"
    else
        log_message "ERROR" "Failed to install PM2"
        exit 1
    fi
}

# Function to install MCP servers
install_mcp_servers() {
    log_message "STEP" "Installing MCP servers..."
    
    local mcp_servers=(
        "taskmaster-ai"
        "@executeautomation/playwright-mcp-server"
        "@modelcontextprotocol/server-puppeteer"
        "@playwright/mcp"
        "@modelcontextprotocol/server-postgres"
        "@modelcontextprotocol/server-github"
        "@upstash/context7-mcp@latest"
        "@modelcontextprotocol/server-sequential-thinking"
        "postgres-mcp"
    )
    
    for server in "${mcp_servers[@]}"; do
        log_message "INFO" "Installing $server..."
        if npm install -g "$server" >> "$LOG_FILE" 2>&1; then
            log_message "SUCCESS" "$server installed"
        else
            log_message "WARNING" "Failed to install $server (may not be critical)"
        fi
    done
    
    # Install Playwright browsers for MCP servers
    log_message "INFO" "Installing Playwright browsers..."
    if command_exists playwright; then
        playwright install >> "$LOG_FILE" 2>&1 || log_message "WARNING" "Playwright browser installation failed"
    fi
    
    # Install UV for Python MCP servers
    log_message "INFO" "Installing UV (Python package manager)..."
    if ! command_exists uv; then
        curl -LsSf https://astral.sh/uv/install.sh | sh >> "$LOG_FILE" 2>&1 || log_message "WARNING" "UV installation failed"
        # Add UV to PATH for current session
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
}

# Function to setup project dependencies
setup_project() {
    log_message "STEP" "Setting up project dependencies..."
    
    cd "$SCRIPT_DIR"
    
    # Install Node.js dependencies
    log_message "INFO" "Installing project dependencies..."
    npm install
    
    # Make scripts executable
    log_message "INFO" "Setting script permissions..."
    chmod +x start-persistent.sh
    chmod +x setup-secure.sh
    chmod +x test-persistence.sh
    
    log_message "SUCCESS" "Project setup completed"
}

# Function to configure security
configure_security() {
    log_message "STEP" "Configuring security..."
    
    cd "$SCRIPT_DIR"
    
    # Check if .env already exists
    if [[ -f ".env" ]]; then
        log_message "INFO" ".env file already exists, keeping existing configuration"
        return 0
    fi
    
    log_message "INFO" "Creating secure configuration..."
    
    # Generate secure tokens
    local auth_token=$(openssl rand -hex 32)
    local session_secret=$(openssl rand -hex 64)
    
    # Get IP addresses
    local public_ip=$(curl -s --max-time 5 http://checkip.amazonaws.com || echo "")
    local private_ip=$(hostname -I | awk '{print $1}' || echo "127.0.0.1")
    
    # Build allowed IPs list
    local allowed_ips="127.0.0.1,::1,$private_ip"
    if [[ -n "$public_ip" ]]; then
        allowed_ips="$allowed_ips,$public_ip"
    fi
    
    # Create .env file
    cat > .env << EOF
# MCP SSE Server - Secure Configuration
# Generated on $(date)

# Server Configuration
PORT=3001
NODE_ENV=production

# Security Configuration
AUTH_TOKEN=$auth_token
ALLOWED_IPS=$allowed_ips
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001

# API Keys (Add your keys here)
ANTHROPIC_API_KEY=
PERPLEXITY_API_KEY=

# Rate Limiting (15 minutes window, 100 requests max)
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Session Security
SESSION_SECRET=$session_secret
EOF
    
    # Secure the .env file
    chmod 600 .env
    
    log_message "SUCCESS" "Security configuration created"
    log_message "INFO" "🔑 Your authentication token: $auth_token"
    log_message "INFO" "📝 Edit .env file to add your API keys"
}

# Function to configure firewall
configure_firewall() {
    log_message "STEP" "Configuring firewall..."
    
    # Check if UFW is available
    if ! command_exists ufw; then
        log_message "WARNING" "UFW not available, skipping firewall configuration"
        return 0
    fi
    
    # Enable UFW if not already enabled
    if ! sudo ufw status | grep -q "Status: active"; then
        log_message "INFO" "Enabling UFW firewall..."
        sudo ufw --force enable
    fi
    
    # Allow SSH (important!)
    sudo ufw allow ssh
    
    # Allow MCP server port
    sudo ufw allow 3001
    
    log_message "SUCCESS" "Firewall configured (SSH and port 3001 allowed)"
}

# Function to start server
start_server() {
    log_message "STEP" "Starting MCP SSE Server..."
    
    cd "$SCRIPT_DIR"
    
    # Stop any existing instances
    if command_exists pm2; then
        pm2 delete mcp-sse-server-secure 2>/dev/null || true
        pm2 delete mcp-sse-server 2>/dev/null || true
    fi
    
    # Kill any other node processes on port 3001
    sudo fuser -k 3001/tcp 2>/dev/null || true
    
    # Start secure server with PM2
    log_message "INFO" "Starting secure server with PM2..."
    pm2 start server-secure.js --name mcp-sse-server-secure
    
    # Configure PM2 startup
    log_message "INFO" "Configuring PM2 auto-start..."
    pm2 startup > /tmp/pm2_startup_cmd.txt 2>&1
    
    # Execute the startup command if it contains sudo
    if grep -q "sudo" /tmp/pm2_startup_cmd.txt; then
        local startup_cmd=$(grep "sudo" /tmp/pm2_startup_cmd.txt | tail -1)
        eval "$startup_cmd" || log_message "WARNING" "PM2 startup configuration may have failed"
    fi
    
    # Save PM2 configuration
    pm2 save
    
    log_message "SUCCESS" "MCP SSE Server started and configured for auto-start"
}

# Function to run health checks
run_health_checks() {
    log_message "STEP" "Running health checks..."
    
    cd "$SCRIPT_DIR"
    
    # Wait for server to start
    sleep 5
    
    # Check if server is responding
    local health_check_url="http://localhost:3001/health"
    
    for i in {1..10}; do
        if curl -s "$health_check_url" >/dev/null 2>&1; then
            log_message "SUCCESS" "Server health check passed"
            break
        else
            if [[ $i -eq 10 ]]; then
                log_message "ERROR" "Server health check failed after 10 attempts"
                return 1
            fi
            log_message "INFO" "Waiting for server to start... (attempt $i/10)"
            sleep 3
        fi
    done
    
    # Check PM2 status
    if pm2 list | grep -q "mcp-sse-server-secure.*online"; then
        log_message "SUCCESS" "PM2 process status: online"
    else
        log_message "WARNING" "PM2 process may not be running correctly"
    fi
    
    # Check firewall status
    if command_exists ufw && sudo ufw status | grep -q "3001.*ALLOW"; then
        log_message "SUCCESS" "Firewall allows port 3001"
    else
        log_message "WARNING" "Firewall may not be configured correctly"
    fi
}

# Function to display final information
display_final_info() {
    log_message "STEP" "Deployment completed successfully! 🎉"
    
    local public_ip=$(curl -s --max-time 5 http://checkip.amazonaws.com || echo "Unable to get public IP")
    local private_ip=$(hostname -I | awk '{print $1}' || echo "127.0.0.1")
    local auth_token=$(grep "AUTH_TOKEN=" .env | cut -d'=' -f2)
    
    echo ""
    echo -e "${GREEN}🎉 MCP SSE Server Deployment Complete! 🎉${NC}"
    echo "=================================================="
    echo ""
    echo -e "${BLUE}📍 Server Access URLs:${NC}"
    echo "   🔒 Local:   http://localhost:3001"
    echo "   🏠 Private: http://$private_ip:3001"
    if [[ "$public_ip" != "Unable to get public IP" ]]; then
        echo "   🌐 Public:  http://$public_ip:3001"
    fi
    echo ""
    echo -e "${BLUE}🔑 Authentication:${NC}"
    echo "   Token: $auth_token"
    echo ""
    echo -e "${BLUE}🧪 Test Your Server:${NC}"
    echo "   Health: curl http://localhost:3001/health"
    echo "   Auth:   curl -H \"Authorization: Bearer $auth_token\" http://localhost:3001/mcp/servers"
    echo ""
    echo -e "${BLUE}📋 Management Commands:${NC}"
    echo "   Status:  pm2 status"
    echo "   Logs:    pm2 logs mcp-sse-server-secure"
    echo "   Restart: pm2 restart mcp-sse-server-secure"
    echo "   Stop:    pm2 stop mcp-sse-server-secure"
    echo ""
    echo -e "${BLUE}📚 Documentation:${NC}"
    echo "   Security Guide: ./SECURITY.md"
    echo "   Client Guide:   ./CLIENT-GUIDE.md"
    echo "   Quick Start:    ./QUICK-START.md"
    echo ""
    echo -e "${YELLOW}⚠️  Next Steps:${NC}"
    echo "   1. Add your API keys to .env file"
    echo "   2. Test server connectivity from client machines"
    echo "   3. Review security settings in SECURITY.md"
    echo "   4. Share authentication token with authorized users"
    echo ""
    echo -e "${GREEN}✅ Your MCP SSE Server is now running securely!${NC}"
    echo ""
}

# Function to handle cleanup on exit
cleanup() {
    if [[ $? -ne 0 ]]; then
        log_message "ERROR" "Deployment failed. Check $LOG_FILE for details."
        echo ""
        echo -e "${RED}❌ Deployment failed!${NC}"
        echo "Check the log file for details: $LOG_FILE"
        echo ""
        echo "Common issues:"
        echo "  - Network connectivity problems"
        echo "  - Permission issues (ensure user has sudo privileges)"
        echo "  - Port 3001 already in use"
        echo ""
        echo "For help, see DEPLOYMENT.md or create an issue on GitHub."
    fi
}

# Main deployment function
main() {
    # Setup logging and cleanup
    trap cleanup EXIT
    
    echo -e "${PURPLE}🚀 MCP SSE Server - Automated Deployment${NC}"
    echo "========================================"
    echo "Starting deployment at $(date)"
    echo "Log file: $LOG_FILE"
    echo ""
    
    # Create log file
    touch "$LOG_FILE"
    
    # Run deployment steps
    get_system_info
    check_prerequisites
    install_system_dependencies
    install_nodejs
    install_pm2
    install_mcp_servers
    setup_project
    configure_security
    configure_firewall
    start_server
    run_health_checks
    display_final_info
    
    log_message "SUCCESS" "Deployment completed successfully at $(date)"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 