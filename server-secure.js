const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const session = require('express-session');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const { spawn } = require('child_process');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Security Configuration
const AUTH_TOKEN = process.env.AUTH_TOKEN || 'change-this-default-token';
const ALLOWED_IPS = process.env.ALLOWED_IPS ? process.env.ALLOWED_IPS.split(',') : ['127.0.0.1', '::1'];
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : ['http://localhost:3000'];
const SESSION_SECRET = process.env.SESSION_SECRET || crypto.randomBytes(64).toString('hex');

// Store active MCP processes
const mcpProcesses = new Map();
const activeSessions = new Map();

// Security Middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            scriptSrc: ["'self'"],
            imgSrc: ["'self'", "data:", "https:"],
        },
    },
    hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
    }
}));

// Rate Limiting
const limiter = rateLimit({
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
    max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // limit each IP to 100 requests per windowMs
    message: {
        error: 'Too many requests from this IP, please try again later.',
        retryAfter: Math.ceil((parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000) / 1000)
    },
    standardHeaders: true,
    legacyHeaders: false,
});

app.use(limiter);

// Session Management
app.use(session({
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
        secure: process.env.NODE_ENV === 'production',
        httpOnly: true,
        maxAge: 24 * 60 * 60 * 1000 // 24 hours
    }
}));

// IP Whitelist Middleware
const ipWhitelist = (req, res, next) => {
    const clientIp = req.ip || req.connection.remoteAddress || req.socket.remoteAddress || 
                    (req.connection.socket ? req.connection.socket.remoteAddress : null);
    
    console.log(`Access attempt from IP: ${clientIp}`);
    
    // Check if IP is whitelisted
    const isAllowed = ALLOWED_IPS.some(allowedIp => {
        if (allowedIp === '0.0.0.0') return true; // Allow all (for development only)
        return clientIp === allowedIp || clientIp === `::ffff:${allowedIp}`;
    });
    
    if (!isAllowed) {
        console.log(`❌ Access denied for IP: ${clientIp}`);
        return res.status(403).json({ 
            error: 'Access denied', 
            message: 'Your IP address is not authorized to access this server.',
            ip: clientIp 
        });
    }
    
    next();
};

// Authentication Middleware
const authenticate = (req, res, next) => {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN
    
    if (!token) {
        return res.status(401).json({ 
            error: 'Access token required',
            message: 'Please provide a valid authorization token in the Authorization header'
        });
    }
    
    if (token !== AUTH_TOKEN) {
        console.log(`❌ Invalid token attempt: ${token.substring(0, 10)}...`);
        return res.status(401).json({ 
            error: 'Invalid token',
            message: 'The provided authorization token is invalid'
        });
    }
    
    // Create/update session
    const sessionId = req.session.id || uuidv4();
    req.session.authenticated = true;
    req.session.lastAccess = new Date();
    activeSessions.set(sessionId, {
        ip: req.ip,
        lastAccess: new Date(),
        userAgent: req.headers['user-agent']
    });
    
    next();
};

// CORS with restricted origins
app.use(cors({
    origin: function (origin, callback) {
        // Allow requests with no origin (like mobile apps or curl requests)
        if (!origin) return callback(null, true);
        
        if (ALLOWED_ORIGINS.indexOf(origin) !== -1 || ALLOWED_ORIGINS.includes('*')) {
            callback(null, true);
        } else {
            callback(new Error('Not allowed by CORS'));
        }
    },
    credentials: true,
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Cache-Control']
}));

app.use(express.json({ limit: '10mb' }));

// Apply IP whitelist to all routes
app.use(ipWhitelist);

// MCP Server configurations (using environment variables)
const mcpConfigs = {
    'taskmaster-ai': {
        command: 'task-master-ai',
        args: [],
        env: {
            ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY,
            PERPLEXITY_API_KEY: process.env.PERPLEXITY_API_KEY,
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
    },
    'doerdo-db': {
        command: 'uv',
        args: [
            'run',
            'postgres-mcp',
            '--access-mode=unrestricted'
        ],
        env: {
            DATABASE_URI: process.env.DOERDO_DATABASE_URI || "postgresql://user:pass@localhost:5432/db"
        }
    },
    'doerai-db': {
        command: 'npx',
        args: [
            '-y',
            '@modelcontextprotocol/server-postgres'
        ],
        env: {
            POSTGRES_CONNECTION_STRING: process.env.DOERAI_DATABASE_URI || "postgresql://postgres:password@localhost:5432/doerai_dev"
        }
    },
    'github': {
        command: 'npx',
        args: [
            '-y',
            '@modelcontextprotocol/server-github'
        ],
        env: {
            GITHUB_PERSONAL_ACCESS_TOKEN: process.env.GITHUB_PERSONAL_ACCESS_TOKEN
        }
    },
    'context7': {
        command: 'npx',
        args: [
            '-y',
            '@upstash/context7-mcp@latest'
        ],
        env: {}
    },
    'sequential-thinking': {
        command: 'npx',
        args: [
            '-y',
            '@modelcontextprotocol/server-sequential-thinking'
        ],
        env: {}
    }
};

// Validate required environment variables
if (!process.env.ANTHROPIC_API_KEY) {
    console.warn('⚠️  ANTHROPIC_API_KEY not set in environment');
}
if (!process.env.PERPLEXITY_API_KEY) {
    console.warn('⚠️  PERPLEXITY_API_KEY not set in environment');
}

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

// Public routes (no authentication required)
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        timestamp: new Date().toISOString(),
        security: 'enabled',
        version: '2.0.0-secure'
    });
});

// Authentication endpoint
app.post('/auth/login', (req, res) => {
    const { token } = req.body;
    
    if (!token || token !== AUTH_TOKEN) {
        return res.status(401).json({ 
            error: 'Invalid credentials',
            message: 'Please provide a valid authentication token'
        });
    }
    
    const sessionId = uuidv4();
    req.session.authenticated = true;
    req.session.sessionId = sessionId;
    req.session.lastAccess = new Date();
    
    activeSessions.set(sessionId, {
        ip: req.ip,
        lastAccess: new Date(),
        userAgent: req.headers['user-agent']
    });
    
    res.json({ 
        message: 'Authentication successful',
        sessionId: sessionId,
        expiresIn: '24 hours'
    });
});

// Session info endpoint
app.get('/auth/session', authenticate, (req, res) => {
    res.json({
        authenticated: true,
        sessionId: req.session.sessionId,
        lastAccess: req.session.lastAccess,
        ip: req.ip
    });
});

// Logout endpoint
app.post('/auth/logout', authenticate, (req, res) => {
    const sessionId = req.session.sessionId;
    activeSessions.delete(sessionId);
    req.session.destroy();
    res.json({ message: 'Logged out successfully' });
});

// Protected dashboard (authentication required)
app.get('/', authenticate, (req, res) => {
    const serverList = Object.keys(mcpConfigs).map(name => ({
        name,
        running: mcpProcesses.has(name)
    }));
    
    res.send(`
    <h1>🔒 Secure MCP SSE Server</h1>
    <p><strong>Status:</strong> Authenticated ✅</p>
    <p><strong>Session:</strong> ${req.session.sessionId}</p>
    <p><strong>Available servers:</strong> ${Object.keys(mcpConfigs).join(', ')}</p>
    <p><strong>Running servers:</strong> ${serverList.filter(s => s.running).map(s => s.name).join(', ') || 'None'}</p>
    
    <h2>🔐 Security Features:</h2>
    <ul>
        <li>✅ Token-based authentication</li>
        <li>✅ IP address whitelisting</li>
        <li>✅ Rate limiting</li>
        <li>✅ CORS protection</li>
        <li>✅ Security headers (Helmet)</li>
        <li>✅ Environment variable protection</li>
    </ul>
    
    <h2>📡 API Endpoints:</h2>
    <ul>
        <li><strong>GET /mcp/servers</strong> - List all servers (auth required)</li>
        <li><strong>GET /mcp/{server}/sse</strong> - SSE stream (auth required)</li>
        <li><strong>POST /mcp/{server}/start</strong> - Start a server (auth required)</li>
        <li><strong>POST /mcp/{server}/command</strong> - Send command (auth required)</li>
        <li><strong>POST /auth/login</strong> - Authenticate</li>
        <li><strong>GET /auth/session</strong> - Session info</li>
    </ul>
    
    <p><a href="/mcp/servers">🔗 Check server status (JSON)</a></p>
    `);
});

// Protected MCP routes (authentication required)
app.get('/mcp/servers', authenticate, (req, res) => {
    const servers = Object.keys(mcpConfigs).map(name => ({
        name,
        running: mcpProcesses.has(name),
        // Don't expose sensitive config details
        hasConfig: !!mcpConfigs[name]
    }));
    
    res.json({
        servers,
        timestamp: new Date().toISOString(),
        session: req.session.sessionId
    });
});

// SSE endpoint (authentication required)
app.get('/mcp/:server/sse', authenticate, (req, res) => {
    const serverName = req.params.server;
    
    if (!mcpConfigs[serverName]) {
        return res.status(404).json({ error: 'Server not found' });
    }

    // Set SSE headers
    res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'Access-Control-Allow-Credentials': 'true'
    });

    // Start MCP process if not already running
    if (!mcpProcesses.has(serverName)) {
        startMcpProcess(serverName, mcpConfigs[serverName]);
    }

    const mcpData = mcpProcesses.get(serverName);
    
    if (mcpData) {
        // Listen for new data
        const dataHandler = (data) => {
            res.write(`data: ${JSON.stringify({ 
                type: 'output', 
                data: data.toString(),
                timestamp: new Date().toISOString(),
                server: serverName
            })}\n\n`);
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
        res.write(`data: ${JSON.stringify({ 
            type: 'ping', 
            timestamp: new Date().toISOString(),
            session: req.session.sessionId
        })}\n\n`);
    }, 30000);

    req.on('close', () => {
        clearInterval(keepAlive);
    });
});

// Send commands to MCP servers (authentication required)
app.post('/mcp/:server/command', authenticate, (req, res) => {
    const serverName = req.params.server;
    const { command } = req.body;

    if (!mcpConfigs[serverName]) {
        return res.status(404).json({ error: 'Server not found' });
    }

    // Log command for security audit
    console.log(`Command sent to ${serverName} by session ${req.session.sessionId}: ${JSON.stringify(command).substring(0, 100)}...`);

    if (!mcpProcesses.has(serverName)) {
        startMcpProcess(serverName, mcpConfigs[serverName]);
    }

    const mcpData = mcpProcesses.get(serverName);
    
    if (mcpData && mcpData.process) {
        try {
            mcpData.process.stdin.write(JSON.stringify(command) + '\n');
            res.json({ 
                status: 'sent',
                server: serverName,
                timestamp: new Date().toISOString(),
                session: req.session.sessionId
            });
        } catch (error) {
            console.error(`Error sending command to ${serverName}:`, error);
            res.status(500).json({ error: 'Failed to send command', details: error.message });
        }
    } else {
        res.status(503).json({ error: 'MCP server not available' });
    }
});

// Start/stop individual servers (authentication required)
app.post('/mcp/:server/start', authenticate, (req, res) => {
    const serverName = req.params.server;
    
    if (!mcpConfigs[serverName]) {
        return res.status(404).json({ error: 'Server not found' });
    }

    if (mcpProcesses.has(serverName)) {
        return res.json({ status: 'already_running' });
    }

    try {
        console.log(`Starting server ${serverName} by session ${req.session.sessionId}`);
        startMcpProcess(serverName, mcpConfigs[serverName]);
        res.json({ 
            status: 'started', 
            server: serverName,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error(`Error starting ${serverName}:`, error);
        res.status(500).json({ error: error.message });
    }
});

app.post('/mcp/:server/stop', authenticate, (req, res) => {
    const serverName = req.params.server;
    
    if (!mcpProcesses.has(serverName)) {
        return res.status(404).json({ error: 'Server not running' });
    }

    console.log(`Stopping server ${serverName} by session ${req.session.sessionId}`);
    const mcpData = mcpProcesses.get(serverName);
    mcpData.process.kill('SIGTERM');
    mcpProcesses.delete(serverName);
    
    res.json({ 
        status: 'stopped', 
        server: serverName,
        timestamp: new Date().toISOString()
    });
});

// Admin endpoints
app.get('/admin/sessions', authenticate, (req, res) => {
    const sessions = Array.from(activeSessions.entries()).map(([id, data]) => ({
        id: id.substring(0, 8) + '...',
        ip: data.ip,
        lastAccess: data.lastAccess,
        userAgent: data.userAgent?.substring(0, 50) + '...'
    }));
    
    res.json({
        activeSessions: sessions.length,
        sessions
    });
});

// Start the server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🔒 Secure MCP SSE Server running on http://0.0.0.0:${PORT}`);
    console.log('🛡️  Security features enabled:');
    console.log('   ✅ Authentication required');
    console.log('   ✅ IP whitelist active');
    console.log('   ✅ Rate limiting enabled');
    console.log('   ✅ CORS protection');
    console.log('   ✅ Security headers');
    console.log('   ✅ Environment variables');
    
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
    
    console.log('\n🔑 Authentication required for all MCP endpoints');
    console.log(`📝 Allowed IPs: ${ALLOWED_IPS.join(', ')}`);
    console.log(`🌐 Allowed Origins: ${ALLOWED_ORIGINS.join(', ')}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('Shutting down Secure MCP SSE Server...');
    for (const [name, mcpData] of mcpProcesses) {
        console.log(`Stopping ${name}...`);
        mcpData.process.kill('SIGTERM');
    }
    process.exit(0);
}); 