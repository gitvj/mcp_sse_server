module.exports = {
  apps: [{
    name: 'mcp-sse-server',
    script: 'server.js',
    cwd: '/home/ubuntu/mcp-sse-server',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3001
    },
    env_development: {
      NODE_ENV: 'development',
      PORT: 3001
    },
    log_file: './logs/combined.log',
    out_file: './logs/out.log',
    error_file: './logs/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    time: true,
    // Auto-restart if CPU usage exceeds 80% for 1 minute
    max_restarts: 10,
    min_uptime: '10s',
    // Kill timeout
    kill_timeout: 5000,
    // Enable source map support
    source_map_support: false,
    // Disable auto restart if app crashes too often
    disable_restarting: false,
    // Enable cluster mode for multiple instances (if needed)
    exec_mode: 'fork'
  }]
}; 