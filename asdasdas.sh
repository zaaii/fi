#!/bin/bash

# Maganghub Proxy Setup Script untuk Oracle Cloud Ubuntu + Nginx
# Updated untuk project wkemm

set -e

echo "🚀 Setting up Maganghub Proxy Server..."
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Config
PROJECT_DIR="$HOME/maganghub-proxy"
SERVER_IP="129.80.17.133"
PORT=3000

# Create project directory
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

echo "📦 Installing dependencies..."

# Create package.json
cat > package.json << 'EOF'
{
  "name": "maganghub-proxy",
  "version": "2.0.0",
  "description": "Proxy server with caching and rate limiting for Maganghub API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.0",
    "node-cache": "^5.1.2",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

# Remove old install
rm -rf node_modules package-lock.json
npm install

echo ""
echo "📝 Creating server.js..."

# Create server.js
cat > server.js << 'SERVEREOF'
const express = require('express');
const axios = require('axios');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const NodeCache = require('node-cache');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Cache setup - TTL 10 menit (600 seconds)
const cache = new NodeCache({ 
  stdTTL: 600,
  checkperiod: 120,
  useClones: false
});

// Maganghub config
const MAGANGHUB_BASE = 'https://maganghub.kemnaker.go.id/be/v1/api';
const MAGANGHUB_TOKEN = process.env.MAGANGHUB_TOKEN;

// Track rate limit dari API response
let rateLimitRemaining = 60;
let rateLimitReset = Date.now();

// Request queue untuk prevent parallel duplicate requests
const pendingRequests = new Map();

// Middleware
app.use(helmet());
app.use(express.json({ limit: '10mb' }));

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  credentials: true,
  maxAge: 86400
}));

// Rate limiting: 100 requests per 15 minutes per IP
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later' }
});
app.use(limiter);

// Auth middleware
const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;
  const validToken = process.env.PROXY_AUTH_TOKEN;

  if (!validToken) {
    console.warn('⚠️  PROXY_AUTH_TOKEN not set - proxy is unprotected!');
    return next();
  }

  if (!authHeader || authHeader !== `Bearer ${validToken}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
};

// Logging middleware
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  const ip = req.headers['x-forwarded-for'] || req.connection.remoteAddress;
  console.log(`[${timestamp}] ${req.method} ${req.path} - IP: ${ip}`);
  next();
});

// Health check
app.get('/health', (req, res) => {
  const stats = cache.getStats();
  const uptime = process.uptime();
  
  res.json({ 
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: {
      seconds: Math.floor(uptime),
      formatted: `${Math.floor(uptime / 3600)}h ${Math.floor((uptime % 3600) / 60)}m`
    },
    rateLimit: {
      remaining: rateLimitRemaining,
      resetIn: Math.max(0, Math.floor((rateLimitReset - Date.now()) / 1000))
    },
    cache: {
      keys: stats.keys,
      hits: stats.hits,
      misses: stats.misses,
      hitRate: stats.keys > 0 ? ((stats.hits / (stats.hits + stats.misses)) * 100).toFixed(1) + '%' : '0%'
    },
    memory: {
      used: `${(process.memoryUsage().heapUsed / 1024 / 1024).toFixed(2)} MB`,
      total: `${(process.memoryUsage().heapTotal / 1024 / 1024).toFixed(2)} MB`
    }
  });
});

// Cache stats (protected)
app.get('/stats', authMiddleware, (req, res) => {
  const stats = cache.getStats();
  const keys = cache.keys();
  
  res.json({
    cache: {
      totalKeys: stats.keys,
      hits: stats.hits,
      misses: stats.misses,
      hitRate: stats.keys > 0 ? ((stats.hits / (stats.hits + stats.misses)) * 100).toFixed(2) : 0,
      cachedPaths: keys.slice(0, 50) // Limit to first 50
    },
    rateLimit: {
      remaining: rateLimitRemaining,
      limit: 60,
      resetAt: new Date(rateLimitReset).toISOString()
    },
    pendingRequests: pendingRequests.size
  });
});

// Generate cache key
function getCacheKey(path, params) {
  const sortedParams = Object.keys(params || {})
    .sort()
    .map(k => `${k}=${params[k]}`)
    .join('&');
  return `${path}${sortedParams ? '?' + sortedParams : ''}`;
}

// Main proxy endpoint
app.post('/proxy', authMiddleware, async (req, res) => {
  try {
    const { path, method = 'GET', params } = req.body;

    if (!path) {
      return res.status(400).json({ error: 'Missing path parameter' });
    }

    // Validate path
    if (!path.startsWith('/')) {
      return res.status(400).json({ error: 'Path must start with /' });
    }

    const cacheKey = getCacheKey(path, params);

    // Check cache (only for GET)
    if (method === 'GET') {
      const cached = cache.get(cacheKey);
      if (cached) {
        console.log(`  ✓ Cache HIT: ${cacheKey}`);
        return res.json({ ...cached, _cached: true, _timestamp: Date.now() });
      }
      console.log(`  ✗ Cache MISS: ${cacheKey}`);
    }

    // Request deduplication
    if (pendingRequests.has(cacheKey)) {
      console.log(`  ⏳ Deduplicating: ${cacheKey}`);
      try {
        const result = await pendingRequests.get(cacheKey);
        return res.json({ ...result.data, _deduplicated: true, _timestamp: Date.now() });
      } catch (error) {
        // If pending request failed, continue with new request
        pendingRequests.delete(cacheKey);
      }
    }

    // Make request
    const requestPromise = makeRequest(path, method, params);
    pendingRequests.set(cacheKey, requestPromise);

    try {
      const result = await requestPromise;
      
      // Cache successful GET responses
      if (method === 'GET' && result.status === 200) {
        cache.set(cacheKey, result.data);
        console.log(`  ✓ Cached: ${cacheKey}`);
      }

      res.status(result.status).json(result.data);
    } finally {
      pendingRequests.delete(cacheKey);
    }

  } catch (error) {
    console.error(`  ✗ Error:`, error.message);
    
    if (error.code === 'ECONNABORTED') {
      return res.status(504).json({ error: 'Request timeout' });
    }
    
    if (error.code === 'ECONNREFUSED') {
      return res.status(502).json({ error: 'Cannot connect to upstream API' });
    }
    
    res.status(500).json({ 
      error: 'Proxy error', 
      message: error.message 
    });
  }
});

// Make actual API request
async function makeRequest(path, method, params) {
  const url = `${MAGANGHUB_BASE}${path}`;
  const queryString = params ? new URLSearchParams(params).toString() : '';
  const fullUrl = queryString ? `${url}?${queryString}` : url;

  console.log(`  → ${method} ${fullUrl}`);
  console.log(`  → Rate limit: ${rateLimitRemaining} remaining`);

  const startTime = Date.now();
  
  const response = await axios({
    method: method,
    url: fullUrl,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${MAGANGHUB_TOKEN}`,
      'User-Agent': 'MaganghubProxy/2.0'
    },
    timeout: 30000,
    validateStatus: () => true // Don't throw on non-2xx status
  });

  const elapsed = Date.now() - startTime;

  // Update rate limit tracking
  const remaining = response.headers['x-ratelimit-remaining'];
  const reset = response.headers['x-ratelimit-reset'];
  
  if (remaining !== undefined) {
    rateLimitRemaining = parseInt(remaining);
  }
  
  if (reset !== undefined) {
    rateLimitReset = parseInt(reset) * 1000;
  }

  console.log(`  ← ${response.status} (${elapsed}ms) - Rate limit: ${rateLimitRemaining}`);

  return {
    status: response.status,
    data: response.data
  };
}

// Clear cache (protected)
app.post('/cache/clear', authMiddleware, (req, res) => {
  const { pattern } = req.body;
  
  if (pattern) {
    const keys = cache.keys();
    const deleted = keys.filter(k => k.includes(pattern));
    deleted.forEach(k => cache.del(k));
    res.json({ 
      message: `Cleared ${deleted.length} cache entries matching "${pattern}"`,
      deleted 
    });
  } else {
    const keyCount = cache.keys().length;
    cache.flushAll();
    res.json({ message: `Cleared all ${keyCount} cache entries` });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Graceful shutdown
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

function shutdown() {
  console.log('\n🛑 Shutting down gracefully...');
  cache.close();
  process.exit(0);
}

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🚀 Maganghub Proxy Server v2.0');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`📍 Server: http://0.0.0.0:${PORT}`);
  console.log(`🔐 Auth: ${process.env.PROXY_AUTH_TOKEN ? '✓ Enabled' : '✗ DISABLED (Insecure!)'}`);
  console.log(`🎯 Target: ${MAGANGHUB_BASE}`);
  console.log(`🔑 Token: ${MAGANGHUB_TOKEN ? '✓ Set' : '✗ MISSING'}`);
  console.log(`💾 Cache TTL: 10 minutes`);
  console.log(`⏱️  Rate Limit: 100 req/15min per IP`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');
  console.log('Endpoints:');
  console.log('  GET  /health        - Health check (public)');
  console.log('  GET  /stats         - Cache stats (protected)');
  console.log('  POST /proxy         - Main proxy (protected)');
  console.log('  POST /cache/clear   - Clear cache (protected)');
  console.log('');
});
SERVEREOF

echo ""
echo "🔐 Generating secure auth token..."

# Generate random auth token
AUTH_TOKEN=$(openssl rand -hex 32)

# Create .env file
cat > .env << ENVEOF
# Server config
PORT=3000

# Auth token untuk protect proxy (SIMPAN INI!)
PROXY_AUTH_TOKEN=$AUTH_TOKEN

# Maganghub API token (updated)
MAGANGHUB_TOKEN=eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiI5YzVlZTk2Yi04MzcwLTQzYTMtOTRjZi0yZDVhYTg1ZDIxZmUiLCJqdGkiOiI5MWZmZWRmMjAxZTFmZjNhNDljNmMxYWQwMmI5ZjdjMDk0ZTk1NjE4NjlhMDY3NGZkYjMxNzUyMDIzOWMyNjJhNDUyOWM5NGM2MWJkYmFmNCIsImlhdCI6MTc2MzI2MzY5NS4xNDI2MjIsIm5iZiI6MTc2MzI2MzY5NS4xNDI2MjQsImV4cCI6MTc5NDc5OTY5NS4xMzc5NjIsInN1YiI6ImZhYTM3ZTM2LTQ0YWEtNDUwMy04YzFlLWJiZTYzM2ZjODkyNSIsInNjb3BlcyI6W119.FuC3n0_4ON2awNxpYGg9G-FKo6T1MLbkySIttHENIcN4_HLhPgoB8nWiMcpJljY3B6s7GAXYHOfx-4GhHDco1i9VE6yO2Ie05fvnkjojRo8_nDc-aHLPXTEd0CzjMGfwbDqhFqhh6rBaRJ6rqtz483nvff8KHqd5gbfx58qvXGnITzzeHyX4-HgryyfW7DsVbrE7CeRTdqKiEIm05h3749FPQ02oPwgb7UWa4BcORZ7zVUVliNx66gnZZhVpoXQFwr6nkoBUfE5TP4_J47N0wVOPd4WJ1FibkZrtb7fpTXIcCIypgTZu6_sYbgYL0XE5EssKDD-bQdBAIQ_UH-ByU_MAuULVJY9qnq4WGI6r0ozeH5twqFObu_feC5-9iofFYIG-IfgBeebmkB_cOgtyjuRHyDX5DpZNOq0q83Bgp_JE9GfkkbmYl2_tjkqDg64i1OHmZjMBKgdRvIYvFQ3ZvciZSQLpqkpqIk1cE2KKiYTINNH8em5jmClB9rYtjSEbeNOuyejLQ5VO1aLWt2sqis0WOwtWsvpHN54cUrsBIcQEJqHc9sfEJ5OqjI4r33naAI2mnNCII8F5k-l-FQFMyz8a7T1K35oZz2zo_FAtBi4PO3n3sF6YV66wKBcmt5ACH1z7XnibaMvigcQCAor0ZQgRyzYoH86--eo5cwbHofU

# Allowed origins - UPDATE dengan domain Vercel kamu!
ALLOWED_ORIGINS=http://localhost:5173,https://wkemm.vercel.app,https://*.vercel.app

# Server info
SERVER_IP=$SERVER_IP
ENVEOF

chmod 600 .env

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}📋 Your Proxy Auth Token:${NC}"
echo -e "${GREEN}$AUTH_TOKEN${NC}"
echo ""
echo -e "${RED}⚠️  SAVE THIS TOKEN!${NC}"
echo "You'll need it in:"
echo "  1. Frontend .env as VITE_PROXY_AUTH_TOKEN"
echo "  2. Vercel environment variables"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if PM2 is installed
if ! command -v pm2 &> /dev/null; then
    echo "📦 Installing PM2..."
    npm install -g pm2
fi

echo "🚀 Starting server with PM2..."

# Stop if already running
pm2 stop maganghub-proxy 2>/dev/null || true
pm2 delete maganghub-proxy 2>/dev/null || true

# Start server
pm2 start server.js --name maganghub-proxy --time --log-date-format "YYYY-MM-DD HH:mm:ss"

# Save PM2 config
pm2 save

# Setup startup script
pm2 startup | grep -E "^sudo" | bash || true

echo ""
echo "✅ Server started!"
echo ""
echo "Testing endpoints..."
echo ""

sleep 2

# Test health endpoint
echo "1️⃣  Testing /health..."
curl -s http://localhost:$PORT/health | jq '.' || curl -s http://localhost:$PORT/health

echo ""
echo ""
echo "2️⃣  Testing /proxy endpoint..."
curl -s -X POST http://localhost:$PORT/proxy \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d '{
    "path": "/list/crud-program-participants",
    "method": "GET",
    "params": {
      "order_direction": "ASC",
      "page": "1",
      "limit": "1"
    }
  }' | jq '.data[0].id // "OK"' || echo "Request sent"

echo ""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 All done!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Check logs: pm2 logs maganghub-proxy"
echo "  2. Monitor: pm2 monit"
echo "  3. Check stats: curl -H 'Authorization: Bearer $AUTH_TOKEN' http://localhost:$PORT/stats"
echo ""
echo "  4. Update your frontend .env:"
echo "     VITE_PROXY_URL=http://$SERVER_IP:$PORT"
echo "     VITE_PROXY_AUTH_TOKEN=$AUTH_TOKEN"
echo ""
echo "  5. Configure Nginx reverse proxy (recommended)"
echo ""

