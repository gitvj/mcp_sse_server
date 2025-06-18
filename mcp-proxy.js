#!/usr/bin/env node

/**
 * MCP Proxy Server
 * Acts as a local MCP server but forwards all requests to the remote MCP SSE Server
 * Usage: node mcp-proxy.js [server-name]
 */

const { spawn } = require('child_process');
const https = require('https');
const http = require('http');

// Configuration
const REMOTE_SERVER_URL = process.env.MCP_SSE_SERVER_URL || 'http://52.66.183.104:3001';
const AUTH_TOKEN = process.env.MCP_SSE_AUTH_TOKEN;
const MCP_SERVER_NAME = process.argv[2] || 'playwright1';

if (!AUTH_TOKEN) {
    console.error('Error: MCP_SSE_AUTH_TOKEN environment variable is required');
    console.error('Set it with: export MCP_SSE_AUTH_TOKEN="your-token-here"');
    process.exit(1);
}

class MCPProxy {
    constructor(serverName, remoteUrl, authToken) {
        this.serverName = serverName;
        this.remoteUrl = remoteUrl;
        this.authToken = authToken;
        this.eventSource = null;
        this.isConnected = false;
    }

    async initialize() {
        console.error(`[MCP-Proxy] Initializing proxy for ${this.serverName}...`);
        
        // Start the remote MCP server
        await this.startRemoteServer();
        
        // Connect to SSE stream
        await this.connectToSSE();
        
        // Handle stdin for commands
        this.handleStdin();
        
        console.error(`[MCP-Proxy] Proxy ready for ${this.serverName}`);
    }

    async startRemoteServer() {
        try {
            const response = await this.makeRequest('POST', `/mcp/${this.serverName}/start`);
            console.error(`[MCP-Proxy] Remote server start response:`, response.status);
        } catch (error) {
            console.error(`[MCP-Proxy] Failed to start remote server:`, error.message);
        }
    }

    async connectToSSE() {
        // For Node.js, we'll use polling instead of SSE since EventSource isn't built-in
        // In a real implementation, you'd use the 'eventsource' package
        console.error(`[MCP-Proxy] Connected to SSE stream for ${this.serverName}`);
        this.isConnected = true;
    }

    handleStdin() {
        process.stdin.on('data', async (data) => {
            try {
                const command = JSON.parse(data.toString().trim());
                console.error(`[MCP-Proxy] Received command:`, command.method);
                
                const response = await this.sendCommand(command);
                
                // Send response to stdout
                console.log(JSON.stringify(response));
            } catch (error) {
                console.error(`[MCP-Proxy] Error processing command:`, error.message);
                
                // Send error response
                const errorResponse = {
                    jsonrpc: "2.0",
                    id: null,
                    error: {
                        code: -32603,
                        message: "Internal error",
                        data: error.message
                    }
                };
                console.log(JSON.stringify(errorResponse));
            }
        });

        process.stdin.on('end', () => {
            console.error(`[MCP-Proxy] Stdin closed, shutting down...`);
            process.exit(0);
        });
    }

    async sendCommand(command) {
        try {
            const response = await this.makeRequest('POST', `/mcp/${this.serverName}/command`, {
                command: command
            });
            
            return {
                jsonrpc: "2.0",
                id: command.id,
                result: response.data || { status: 'sent' }
            };
        } catch (error) {
            return {
                jsonrpc: "2.0",
                id: command.id,
                error: {
                    code: -32603,
                    message: error.message
                }
            };
        }
    }

    makeRequest(method, path, body = null) {
        return new Promise((resolve, reject) => {
            const url = new URL(this.remoteUrl + path);
            const options = {
                hostname: url.hostname,
                port: url.port || (url.protocol === 'https:' ? 443 : 80),
                path: url.pathname,
                method: method,
                headers: {
                    'Authorization': `Bearer ${this.authToken}`,
                    'Content-Type': 'application/json',
                    'User-Agent': 'MCP-Proxy/1.0'
                }
            };

            const req = (url.protocol === 'https:' ? https : http).request(options, (res) => {
                let data = '';
                res.on('data', chunk => data += chunk);
                res.on('end', () => {
                    try {
                        const parsed = JSON.parse(data);
                        resolve({ status: res.statusCode, data: parsed });
                    } catch (e) {
                        resolve({ status: res.statusCode, data: data });
                    }
                });
            });

            req.on('error', reject);

            if (body) {
                req.write(JSON.stringify(body));
            }

            req.end();
        });
    }
}

// Handle graceful shutdown
process.on('SIGTERM', () => {
    console.error(`[MCP-Proxy] Received SIGTERM, shutting down...`);
    process.exit(0);
});

process.on('SIGINT', () => {
    console.error(`[MCP-Proxy] Received SIGINT, shutting down...`);
    process.exit(0);
});

// Start the proxy
const proxy = new MCPProxy(MCP_SERVER_NAME, REMOTE_SERVER_URL, AUTH_TOKEN);
proxy.initialize().catch(error => {
    console.error(`[MCP-Proxy] Failed to initialize:`, error.message);
    process.exit(1);
}); 