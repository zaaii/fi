#!/bin/bash

# Update Proxy Server untuk Support Encoded Payload
# Run: bash proxy-server-update.sh di Oracle Cloud

cd ~/maganghub-proxy

# Backup old server.js
cp server.js server.js.backup

# Create updated server.js dengan encoded payload support
cat > server.js << 'EOF'
const express = require('express');
const axios = require('axios');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const NodeCache = require('node-cache');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Trust proxy headers from Nginx/Cloudflare
app.set('trust proxy', true);

// Cache setup - TTL 10 menit
const cache = new NodeCache({ stdTTL: 600, checkperiod: 120, useClones: false });

// Maganghub config
const MAGANGHUB_BASE = 'https://maganghub.kemnaker.go.id/be/v1/api';
const MAGANGHUB_TOKEN = process.env.MAGANGHUB_TOKEN;

// Track rate limit
let rateLimitRemaining = 60;
let rateLimitReset = Date.now();

// Request queue untuk prevent parallel hits
const pendingRequests = new Map();

// Middleware
app.use(helmet());
app.use(express.json());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  methods: ['GET', 'POST'],
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 2000,
  message: { error: 'Too many requests' }
});
app.use(limiter);

// Auth middleware
const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;
  const validToken = process.env.PROXY_AUTH_TOKEN;
  
  if (!validToken) {
    console.warn('⚠️  PROXY_AUTH_TOKEN not set!');
    return next();
  }
  
  if (authHeader !== `Bearer ${validToken}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
};

// Logging
app.use((req, res, next) => {
  const ip = req.headers['x-forwarded-for'] || req.connection.remoteAddress;
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} - IP: ${ip}`);
  next();
});

// Health check
app.get('/health', (req, res) => {
  const stats = cache.getStats();
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: { 
      seconds: Math.floor(process.uptime()),
      formatted: formatUptime(process.uptime())
    },
    rateLimit: {
      remaining: rateLimitRemaining,
      resetIn: Math.max(0, Math.floor((rateLimitReset - Date.now()) / 1000))
    },
    cache: {
      keys: stats.keys,
      hits: stats.hits,
      misses: stats.misses,
      hitRate: stats.keys > 0 ? (stats.hits / (stats.hits + stats.misses) * 100).toFixed(1) + '%' : '0%'
    },
    memory: {
      used: (process.memoryUsage().heapUsed / 1024 / 1024).toFixed(2) + ' MB',
      total: (process.memoryUsage().heapTotal / 1024 / 1024).toFixed(2) + ' MB'
    }
  });
});

function formatUptime(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${h}h ${m}m`;
}

// Cache stats endpoint
app.get('/stats', authMiddleware, (req, res) => {
  const stats = cache.getStats();
  const keys = cache.keys();
  res.json({
    cache: {
      keys: stats.keys,
      hits: stats.hits,
      misses: stats.misses,
      hitRate: stats.keys > 0 ? (stats.hits / (stats.hits + stats.misses) * 100).toFixed(2) : 0,
      cachedPaths: keys
    },
    rateLimit: {
      remaining: rateLimitRemaining,
      limit: 60,
      resetAt: new Date(rateLimitReset).toISOString()
    }
  });
});

// Generate cache key
function getCacheKey(path, params) {
  const sortedParams = Object.keys(params || {})
    .sort()
    .map(k => `${k}=${params[k]}`)
    .join('&');
  return `${path}?${sortedParams}`;
}

// Main proxy dengan encoded payload support
app.post('/proxy', authMiddleware, async (req, res) => {
  try {
    let { path, method = 'GET', params, data, p } = req.body;
    
    // Decode encoded path (new format)
    if (p && !path) {
      try {
        const decoded = Buffer.from(p, 'base64').toString('utf-8');
        // Parse path and query string
        if (decoded.includes('?')) {
          const [pathPart, queryPart] = decoded.split('?');
          path = pathPart;
          params = {};
          const queryParams = new URLSearchParams(queryPart);
          queryParams.forEach((value, key) => {
            params[key] = value;
          });
        } else {
          path = decoded;
        }
      } catch (err) {
        return res.status(400).json({ error: 'Invalid encoded path' });
      }
    }
    
    if (!path) {
      return res.status(400).json({ error: 'Missing path parameter' });
    }

    // Generate cache key
    const cacheKey = getCacheKey(path, params);

    // Check cache first (only for GET)
    if (method === 'GET') {
      const cached = cache.get(cacheKey);
      if (cached) {
        console.log(`  ✓ Cache HIT: ${cacheKey}`);
        return res.json({ ...cached, _cached: true });
      }
      console.log(`  ✗ Cache MISS: ${cacheKey}`);
    }

    // Check if same request is pending (deduplication)
    if (pendingRequests.has(cacheKey)) {
      console.log(`  ⏳ Request pending: ${cacheKey}`);
      const result = await pendingRequests.get(cacheKey);
      return res.json({ ...result, _deduplicated: true });
    }

    // Create promise for this request
    const requestPromise = makeRequest(path, method, params, data);
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
    
    res.status(500).json({ 
      error: 'Proxy error', 
      message: error.message 
    });
  }
});

// Actual API request
async function makeRequest(path, method, params, data) {
  const url = `${MAGANGHUB_BASE}${path}`;
  const queryString = params ? new URLSearchParams(params).toString() : '';
  const fullUrl = queryString ? `${url}?${queryString}` : url;

  console.log(`  → GET ${fullUrl}`);
  console.log(`  → Rate limit: ${rateLimitRemaining} remaining`);

  const response = await axios({
    method: method,
    url: fullUrl,
    data: data,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${MAGANGHUB_TOKEN}`,
      'User-Agent': 'MaganghubProxy/2.0'
    },
    timeout: 30000,
    validateStatus: () => true
  });

  // Update rate limit info
  const remaining = response.headers['x-ratelimit-remaining'];
  const reset = response.headers['x-ratelimit-reset'];
  
  if (remaining !== undefined) {
    rateLimitRemaining = parseInt(remaining);
  }
  if (reset !== undefined) {
    rateLimitReset = parseInt(reset) * 1000;
  }

  console.log(`  ← ${response.status} (${response.status === 200 ? 'OK' : 'Error'}) - Rate limit: ${rateLimitRemaining}`);

  return {
    status: response.status,
    data: response.data
  };
}

// Clear cache endpoint
app.post('/cache/clear', authMiddleware, (req, res) => {
  const { pattern } = req.body;
  
  if (pattern) {
    const keys = cache.keys();
    const deleted = keys.filter(k => k.includes(pattern));
    deleted.forEach(k => cache.del(k));
    res.json({ message: `Cleared ${deleted.length} cache entries matching "${pattern}"` });
  } else {
    cache.flushAll();
    res.json({ message: 'Cache cleared completely' });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log('🚀 Maganghub Proxy Server v2.1 (with encryption)');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`📍 Server: http://0.0.0.0:${PORT}`);
  console.log(`🔐 Auth: ${process.env.PROXY_AUTH_TOKEN ? '✓ Enabled' : '✗ Disabled'}`);
  console.log(`🎯 Target: ${MAGANGHUB_BASE}`);
  console.log(`🔑 Token: ${MAGANGHUB_TOKEN ? '✓ Set' : '✗ Missing'}`);
  console.log(`💾 Cache TTL: 10 minutes`);
  console.log(`🔒 Payload: Base64 encoded`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');
});

process.on('SIGTERM', () => {
  console.log('Shutting down...');
  cache.close();
  process.exit(0);
});
EOF

echo "✅ server.js updated with encryption support!"
echo ""
echo "🔄 Restarting PM2..."
pm2 restart maganghub-proxy

echo ""
echo "📊 Checking logs..."
pm2 logs maganghub-proxy --lines 10 --nostream

echo ""
echo "✅ Done! Proxy server now supports encoded payloads."
echo ""
echo "Test:"
echo "curl http://localhost:3000/health"
EOF

chmod +x proxy-server-update.sh

echo "✅ Script created: proxy-server-update.sh"

