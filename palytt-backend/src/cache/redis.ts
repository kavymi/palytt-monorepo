//
//  redis.ts
//  Palytt Backend
//
//  Redis connection and client management
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import Redis, { RedisOptions } from 'ioredis';

// Environment configuration
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const isProduction = process.env.NODE_ENV === 'production';

// Connection options
const redisOptions: RedisOptions = {
  maxRetriesPerRequest: 3,
  retryStrategy: (times: number) => {
    if (times > 10) {
      console.error('❌ Redis connection failed after 10 retries');
      return null; // Stop retrying
    }
    const delay = Math.min(times * 100, 3000);
    console.log(`🔄 Redis reconnecting in ${delay}ms (attempt ${times})`);
    return delay;
  },
  reconnectOnError: (err: Error) => {
    const targetErrors = ['READONLY', 'ECONNRESET', 'ETIMEDOUT'];
    return targetErrors.some((e) => err.message.includes(e));
  },
  enableReadyCheck: true,
  lazyConnect: true, // Don't connect until first command
};

// Parse Redis URL and create client
function createRedisClient(name: string): Redis {
  const client = new Redis(REDIS_URL, {
    ...redisOptions,
    connectionName: `palytt-${name}`,
  });

  // Event handlers
  client.on('connect', () => {
    console.log(`✅ Redis [${name}] connecting...`);
  });

  client.on('ready', () => {
    console.log(`✅ Redis [${name}] ready`);
  });

  client.on('error', (err: Error) => {
    console.error(`❌ Redis [${name}] error:`, err.message);
  });

  client.on('close', () => {
    if (!isProduction) {
      console.log(`🔌 Redis [${name}] connection closed`);
    }
  });

  client.on('reconnecting', () => {
    console.log(`🔄 Redis [${name}] reconnecting...`);
  });

  return client;
}

// Main Redis client for caching and general operations
export const redis = createRedisClient('main');

// Subscriber client for Pub/Sub (requires dedicated connection)
export const redisSubscriber = createRedisClient('subscriber');

// Publisher client for Pub/Sub
export const redisPublisher = createRedisClient('publisher');

/**
 * Initialize Redis connections
 * Call this on server startup
 */
export async function initializeRedis(): Promise<void> {
  try {
    // Connect main client
    await redis.connect();
    console.log('✅ Redis main client connected');

    // Verify connection with PING
    const pong = await redis.ping();
    if (pong !== 'PONG') {
      throw new Error('Redis PING failed');
    }

    console.log('✅ Redis connection verified');
  } catch (error) {
    console.error('❌ Failed to initialize Redis:', error);
    // Don't throw - allow server to start without Redis (degraded mode)
    console.warn('⚠️ Running in degraded mode without Redis caching');
  }
}

/**
 * Check Redis health status
 */
export async function checkRedisHealth(): Promise<{
  status: 'healthy' | 'unhealthy' | 'degraded';
  latency?: number;
  error?: string;
}> {
  try {
    const start = Date.now();
    const result = await redis.ping();
    const latency = Date.now() - start;

    if (result === 'PONG') {
      return {
        status: latency > 100 ? 'degraded' : 'healthy',
        latency,
      };
    }

    return {
      status: 'unhealthy',
      error: 'Unexpected PING response',
    };
  } catch (error) {
    return {
      status: 'unhealthy',
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Get Redis connection info for debugging
 */
export async function getRedisInfo(): Promise<Record<string, string>> {
  try {
    const info = await redis.info();
    const lines = info.split('\r\n');
    const result: Record<string, string> = {};

    for (const line of lines) {
      if (line.includes(':')) {
        const [key, value] = line.split(':');
        result[key] = value;
      }
    }

    return result;
  } catch (error) {
    return { error: error instanceof Error ? error.message : 'Unknown error' };
  }
}

/**
 * Gracefully close Redis connections
 * Call this on server shutdown
 */
export async function closeRedis(): Promise<void> {
  try {
    await Promise.all([
      redis.quit(),
      redisSubscriber.quit(),
      redisPublisher.quit(),
    ]);
    console.log('✅ Redis connections closed');
  } catch (error) {
    console.error('❌ Error closing Redis connections:', error);
  }
}

/**
 * Check if Redis is available
 */
export function isRedisAvailable(): boolean {
  return redis.status === 'ready';
}

// Export default client for convenience
export default redis;

