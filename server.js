const express = require('express');
const cors = require('cors');
const { spawn } = require('child_process');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Cache-Control']
}));
app.use(express.json());

// Store active MCP processes
const mcpProcesses = new Map();

// MCP Server configurations
const mcpConfigs = {
    'taskmaster-ai': {
        command: 'task-master-ai',
        args: [],
        env: {
            ANTHROPIC_API_KEY: "YOUR_ANTHROPIC_API_KEY_HERE",
            PERPLEXITY_API_KEY: "YOUR_PERPLEXITY_API_KEY_HERE",
            MODEL: "claude-3-7-sonnet-20250219"
        }
    },
    'playwright1': {
        command: 'npx',
        args: ['@playwright/mcp@latest'],
        env: {}
    },
    'playwright2': {
        command: 'npx',
        args: ['-y', '@executeautomation/playwright-mcp-server'],
        env: {}
    },
    'puppeteer': {
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-puppeteer'],
        env: {}
    }
};

// Function to start an MCP process
function startMcpProcess(serverName, config) {
    console.log(`Starting MCP server: ${serverName}`);
    
    const process = spawn(config.command, config.args, {
        env: { ...process.env, ...config.env },
        stdio: ['pipe', 'pipe', 'pipe']
    });

    process.stdout.on('data', (data) => {
        console.log(`[${serverName}] ${data}`);
    });

    process.stderr.on('data', (data) => {
        console.error(`[${serverName}] ERROR: ${data}`);
    });

    mcpProcesses.set(serverName, { process, config });
    return process;
}

// SSE endpoint for real-time communication
app.get('/mcp/:server/sse', (req, res) => {
    const serverName = req.params.server;
    
    if (!mcpConfigs[serverName]) {
        return res.status(404).json({ error: 'Server not found' });
    }

    // Set SSE headers
    res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Cache-Control'
    });

    // Start MCP process if not already running
    if (!mcpProcesses.has(serverName)) {
        startMcpProcess(serverName, mcpConfigs[serverName]);
    }

    const mcpData = mcpProcesses.get(serverName);
    
    if (mcpData) {
        // Listen for new data
        const dataHandler = (data) => {
            res.write(`data: ${JSON.stringify({ type: 'output', data: data.toString() })}\n\n`);
        };

        mcpData.process.stdout.on('data', dataHandler);
        mcpData.process.stderr.on('data', dataHandler);

        // Clean up on client disconnect
        req.on('close', () => {
            mcpData.process.stdout.removeListener('data', dataHandler);
            mcpData.process.stderr.removeListener('data', dataHandler);
        });
    }

    // Keep connection alive
    const keepAlive = setInterval(() => {
        res.write(`data: ${JSON.stringify({ type: 'ping', timestamp: Date.now() })}\n\n`);
    }, 30000);

    req.on('close', () => {
        clearInterval(keepAlive);
    });
});

// Send commands to MCP servers
app.post('/mcp/:server/command', (req, res) => {
    const serverName = req.params.server;
    const { command } = req.body;

    if (!mcpConfigs[serverName]) {
        return res.status(404).json({ error: 'Server not found' });
    }

    if (!mcpProcesses.has(serverName)) {
        startMcpProcess(serverName, mcpConfigs[serverName]);
    }

    const mcpData = mcpProcesses.get(serverName);
    
    if (mcpData && mcpData.process) {
        try {
            mcpData.process.stdin.write(JSON.stringify(command) + '\n');
            res.json({ status: 'sent', command });
        } catch (error) {
            res.status(500).json({ error: 'Failed to send command', details: error.message });
        }
    } else {
        res.status(503).json({ error: 'MCP server not available' });
    }
});

// List available MCP servers
app.get('/mcp/servers', (req, res) => {
    const servers = Object.keys(mcpConfigs).map(name => ({
        name,
        running: mcpProcesses.has(name),
        config: mcpConfigs[name]
    }));
    
    res.json(servers);
});

// Start/stop individual servers
app.post('/mcp/:server/start', (req, res) => {
    const serverName = req.params.server;
    
    if (!mcpConfigs[serverName]) {
        return res.status(404).json({ error: 'Server not found' });
    }

    if (mcpProcesses.has(serverName)) {
        return res.json({ status: 'already_running' });
    }

    try {
        startMcpProcess(serverName, mcpConfigs[serverName]);
        res.json({ status: 'started', server: serverName });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/mcp/:server/stop', (req, res) => {
    const serverName = req.params.server;
    
    if (!mcpProcesses.has(serverName)) {
        return res.status(404).json({ error: 'Server not running' });
    }

    const mcpData = mcpProcesses.get(serverName);
    mcpData.process.kill('SIGTERM');
    mcpProcesses.delete(serverName);
    
    res.json({ status: 'stopped', server: serverName });
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        timestamp: new Date().toISOString(),
        runningServers: Array.from(mcpProcesses.keys())
    });
});

// Simple dashboard
app.get('/', (req, res) => {
    res.send(`
    <h1>🚀 MCP SSE Server</h1>
    <p>Available servers: ${Object.keys(mcpConfigs).join(', ')}</p>
    <p><a href="/mcp/servers">Check server status (JSON)</a></p>
    <h2>API Endpoints:</h2>
    <ul>
        <li><strong>GET /mcp/servers</strong> - List all servers</li>
        <li><strong>GET /mcp/{server}/sse</strong> - SSE stream for server</li>
        <li><strong>POST /mcp/{server}/start</strong> - Start a server</li>
        <li><strong>POST /mcp/{server}/command</strong> - Send command to server</li>
    </ul>
    `);
});

// Start the server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 MCP SSE Server running on http://0.0.0.0:${PORT}`);
    const os = require('os');
    const interfaces = os.networkInterfaces();
    console.log('📍 Access URLs:');
    console.log(`   🔒 Local: http://localhost:${PORT}`);
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                console.log(`   🌐 Network: http://${iface.address}:${PORT}`);
            }
        }
    }
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('Shutting down MCP SSE Server...');
    for (const [name, mcpData] of mcpProcesses) {
        console.log(`Stopping ${name}...`);
        mcpData.process.kill('SIGTERM');
    }
    process.exit(0);
}); 