import Fastify from 'fastify';
import cors from '@fastify/cors';
import websocket from '@fastify/websocket';
import rateLimit from '@fastify/rate-limit';
import { fastifyTRPCPlugin } from '@trpc/server/adapters/fastify';
import { createContext } from './trpc.js';
import { appRouter } from './routers/app.js';
import { initializeRedis, closeRedis, checkRedisHealth, redis, isRedisAvailable } from './cache/redis.js';
import { getCacheStats, subscribeToCacheInvalidation } from './cache/cache.service.js';

const isProduction = process.env.NODE_ENV === 'production';
const isDevelopment = !isProduction && process.env.NODE_ENV !== 'test';
const isDocker = process.env.DOCKER === 'true' || process.env.IS_DOCKER === 'true';

// Check if pino-pretty is available (only in dev dependencies)
const hasPinoPretty = () => {
  try {
    require.resolve('pino-pretty');
    return true;
  } catch {
    return false;
  }
};

// Create logger configuration with fallback for missing pino-pretty
const createLoggerConfig = () => {
  // Use pino-pretty only in local development when it's available
  if (isDevelopment && !isDocker && hasPinoPretty()) {
    return {
      level: 'debug',
      transport: {
        target: 'pino-pretty',
        options: {
          colorize: true,
          translateTime: 'HH:MM:ss Z',
          ignore: 'pid,hostname',
        },
      },
    };
  }
  
  // For Docker, production, or when pino-pretty is not available, use basic logging
  return {
    level: isProduction ? 'info' : 'debug',
  };
};

const server = Fastify({
  logger: createLoggerConfig(),
  maxParamLength: 5000,
});

// Register plugins
await server.register(cors, {
  origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000', 'http://localhost:5173'],
  credentials: true,
});

// Register rate limiting with Redis backend
await server.register(rateLimit, {
  global: true,
  max: isProduction ? 100 : 1000, // requests per window
  timeWindow: '1 minute',
  cache: 10000,
  allowList: ['127.0.0.1', '::1'], // Whitelist localhost
  redis: isRedisAvailable() ? redis : undefined,
  keyGenerator: (req) => {
    // Use user ID if authenticated, otherwise IP
    const userId = req.headers['x-clerk-user-id'];
    return userId ? `user:${userId}` : req.ip;
  },
  errorResponseBuilder: (_req, context) => {
    return {
      code: 'RATE_LIMIT_EXCEEDED',
      message: `Rate limit exceeded. Try again in ${context.after}`,
      retryAfter: context.after,
    };
  },
  onExceeded: (req) => {
    console.warn(`⚠️ Rate limit exceeded for ${req.ip}`);
  },
});

// Register WebSocket support for subscriptions
await server.register(websocket);

// Register tRPC
await server.register(fastifyTRPCPlugin, {
  prefix: '/trpc',
  trpcOptions: {
    router: appRouter,
    createContext,
    onError({ path, error }: { path?: string; error: Error }) {
      console.error(`Error in tRPC handler on path '${path}':`, error);
    },
  },
  useWSS: true, // Enable WebSocket support
});

// Health check endpoint
server.get('/health', async () => {
  const redisHealth = await checkRedisHealth();
  const cacheStats = await getCacheStats();
  
  return { 
    status: redisHealth.status === 'healthy' ? 'ok' : 'degraded',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    redis: redisHealth,
    cache: cacheStats,
  };
});

// Root endpoint
server.get('/', async () => {
  return { 
    message: 'Palytt Backend API',
    version: '0.1.0',
    endpoints: {
      health: '/health',
      trpc: '/trpc',
    },
  };
});

// Start server
const start = async () => {
  try {
    // Initialize Redis connection
    await initializeRedis();
    
    // Subscribe to cache invalidation events (for multi-instance deployments)
    await subscribeToCacheInvalidation();
    
    const port = process.env.PORT ? parseInt(process.env.PORT, 10) : 4000;
    const host = process.env.HOST || '0.0.0.0';
    
    await server.listen({ port, host });
    
    console.log(`
🚀 Server ready at: http://localhost:${port}
⚡ tRPC endpoint: http://localhost:${port}/trpc
🌐 tRPC panel: http://localhost:${port}/trpc/panel
💓 Health check: http://localhost:${port}/health
🔴 Redis: ${isRedisAvailable() ? 'connected' : 'not available (using memory fallback)'}
    `);
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
};

// Handle graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');
  await closeRedis();
  await server.close();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully...');
  await closeRedis();
  await server.close();
  process.exit(0);
});

start(); 