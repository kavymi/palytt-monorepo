//
//  cache.service.ts
//  Palytt Backend
//
//  Caching layer with Redis backend and in-memory fallback
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import { redis, isRedisAvailable, redisPublisher, redisSubscriber } from './redis.js';

// Cache key prefixes for different data types
export const CacheKeys = {
  USER_PROFILE: 'user:profile:',
  USER_BY_CLERK: 'user:clerk:',
  USER_POSTS: 'user:posts:',
  POST: 'post:',
  POST_FEED: 'feed:',
  FRIENDS: 'friends:',
  FOLLOWERS: 'followers:',
  FOLLOWING: 'following:',
  PLACE: 'place:',
  NOTIFICATIONS: 'notifications:',
  RATE_LIMIT: 'ratelimit:',
  SESSION: 'session:',
} as const;

// Default TTLs in seconds
export const CacheTTL = {
  USER_PROFILE: 300, // 5 minutes
  USER_POSTS: 120, // 2 minutes
  POST: 300, // 5 minutes
  POST_FEED: 60, // 1 minute
  FRIENDS: 300, // 5 minutes
  FOLLOWERS: 300, // 5 minutes
  FOLLOWING: 300, // 5 minutes
  PLACE: 600, // 10 minutes
  NOTIFICATIONS: 60, // 1 minute
  SESSION: 3600, // 1 hour
  SHORT: 30, // 30 seconds
  MEDIUM: 300, // 5 minutes
  LONG: 3600, // 1 hour
} as const;

// In-memory cache fallback when Redis is unavailable
const memoryCache = new Map<string, { value: string; expiresAt: number }>();
const MEMORY_CACHE_MAX_SIZE = 1000;

/**
 * Clean up expired entries from memory cache
 */
function cleanupMemoryCache(): void {
  const now = Date.now();
  for (const [key, entry] of memoryCache.entries()) {
    if (entry.expiresAt <= now) {
      memoryCache.delete(key);
    }
  }
}

// Run cleanup every minute
setInterval(cleanupMemoryCache, 60000);

/**
 * Get a value from cache
 */
export async function cacheGet<T>(key: string): Promise<T | null> {
  try {
    if (isRedisAvailable()) {
      const value = await redis.get(key);
      if (value) {
        return JSON.parse(value) as T;
      }
      return null;
    }

    // Fallback to memory cache
    const entry = memoryCache.get(key);
    if (entry && entry.expiresAt > Date.now()) {
      return JSON.parse(entry.value) as T;
    }
    memoryCache.delete(key);
    return null;
  } catch (error) {
    console.error(`❌ Cache get error for key ${key}:`, error);
    return null;
  }
}

/**
 * Set a value in cache with TTL
 */
export async function cacheSet<T>(
  key: string,
  value: T,
  ttlSeconds: number = CacheTTL.MEDIUM
): Promise<boolean> {
  try {
    const serialized = JSON.stringify(value);

    if (isRedisAvailable()) {
      await redis.setex(key, ttlSeconds, serialized);
      return true;
    }

    // Fallback to memory cache
    if (memoryCache.size >= MEMORY_CACHE_MAX_SIZE) {
      // Remove oldest entries when cache is full
      const keysToDelete = Array.from(memoryCache.keys()).slice(0, 100);
      keysToDelete.forEach((k) => memoryCache.delete(k));
    }

    memoryCache.set(key, {
      value: serialized,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
    return true;
  } catch (error) {
    console.error(`❌ Cache set error for key ${key}:`, error);
    return false;
  }
}

/**
 * Delete a specific key from cache
 */
export async function cacheDelete(key: string): Promise<boolean> {
  try {
    if (isRedisAvailable()) {
      await redis.del(key);
    }
    memoryCache.delete(key);
    return true;
  } catch (error) {
    console.error(`❌ Cache delete error for key ${key}:`, error);
    return false;
  }
}

/**
 * Delete multiple keys matching a pattern
 */
export async function cacheDeletePattern(pattern: string): Promise<number> {
  try {
    let deletedCount = 0;

    if (isRedisAvailable()) {
      // Use SCAN to find keys matching pattern (safer than KEYS for large datasets)
      let cursor = '0';
      do {
        const [nextCursor, keys] = await redis.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
        cursor = nextCursor;

        if (keys.length > 0) {
          await redis.del(...keys);
          deletedCount += keys.length;
        }
      } while (cursor !== '0');
    }

    // Also clean memory cache
    for (const key of memoryCache.keys()) {
      if (matchesPattern(key, pattern)) {
        memoryCache.delete(key);
        deletedCount++;
      }
    }

    return deletedCount;
  } catch (error) {
    console.error(`❌ Cache delete pattern error for ${pattern}:`, error);
    return 0;
  }
}

/**
 * Check if a key matches a glob pattern
 */
function matchesPattern(key: string, pattern: string): boolean {
  const regex = new RegExp(
    '^' + pattern.replace(/\*/g, '.*').replace(/\?/g, '.') + '$'
  );
  return regex.test(key);
}

/**
 * Invalidate cache for a specific user
 */
export async function invalidateUserCache(userId: string): Promise<void> {
  await Promise.all([
    cacheDelete(`${CacheKeys.USER_PROFILE}${userId}`),
    cacheDeletePattern(`${CacheKeys.USER_POSTS}${userId}*`),
    cacheDeletePattern(`${CacheKeys.FRIENDS}${userId}*`),
    cacheDeletePattern(`${CacheKeys.FOLLOWERS}${userId}*`),
    cacheDeletePattern(`${CacheKeys.FOLLOWING}${userId}*`),
  ]);
}

/**
 * Invalidate cache for a specific user by Clerk ID
 */
export async function invalidateUserCacheByClerkId(clerkId: string): Promise<void> {
  // First, try to get the user ID from the clerk mapping
  const userId = await cacheGet<string>(`${CacheKeys.USER_BY_CLERK}${clerkId}`);
  
  await cacheDelete(`${CacheKeys.USER_BY_CLERK}${clerkId}`);
  
  if (userId) {
    await invalidateUserCache(userId);
  }
}

/**
 * Invalidate cache for a specific post
 */
export async function invalidatePostCache(postId: string, authorId?: string): Promise<void> {
  await cacheDelete(`${CacheKeys.POST}${postId}`);
  
  // Also invalidate feed caches (they'll be rebuilt on next request)
  await cacheDeletePattern(`${CacheKeys.POST_FEED}*`);
  
  // Invalidate author's posts cache if we know the author
  if (authorId) {
    await cacheDeletePattern(`${CacheKeys.USER_POSTS}${authorId}*`);
  }
}

/**
 * Invalidate all feed caches (use sparingly)
 */
export async function invalidateFeedCaches(): Promise<void> {
  await cacheDeletePattern(`${CacheKeys.POST_FEED}*`);
}

/**
 * Get or set pattern - fetch from cache or compute and cache
 */
export async function cacheGetOrSet<T>(
  key: string,
  fetcher: () => Promise<T>,
  ttlSeconds: number = CacheTTL.MEDIUM
): Promise<T> {
  // Try to get from cache first
  const cached = await cacheGet<T>(key);
  if (cached !== null) {
    return cached;
  }

  // Fetch fresh data
  const value = await fetcher();

  // Cache the result (don't await to not block response)
  cacheSet(key, value, ttlSeconds).catch((err) => {
    console.error(`❌ Failed to cache ${key}:`, err);
  });

  return value;
}

/**
 * Increment a counter (useful for rate limiting)
 */
export async function cacheIncrement(
  key: string,
  ttlSeconds?: number
): Promise<number> {
  try {
    if (isRedisAvailable()) {
      const value = await redis.incr(key);
      if (ttlSeconds && value === 1) {
        // Set expiry only on first increment
        await redis.expire(key, ttlSeconds);
      }
      return value;
    }

    // Memory fallback
    const entry = memoryCache.get(key);
    const now = Date.now();
    
    if (entry && entry.expiresAt > now) {
      const newValue = parseInt(entry.value, 10) + 1;
      entry.value = String(newValue);
      return newValue;
    }

    const expiresAt = ttlSeconds ? now + ttlSeconds * 1000 : now + 3600000;
    memoryCache.set(key, { value: '1', expiresAt });
    return 1;
  } catch (error) {
    console.error(`❌ Cache increment error for ${key}:`, error);
    return 0;
  }
}

/**
 * Get current counter value
 */
export async function cacheGetCounter(key: string): Promise<number> {
  const value = await cacheGet<string>(key);
  return value ? parseInt(value, 10) : 0;
}

/**
 * Set multiple values at once
 */
export async function cacheSetMultiple(
  entries: Array<{ key: string; value: unknown; ttl?: number }>
): Promise<boolean> {
  try {
    if (isRedisAvailable()) {
      const pipeline = redis.pipeline();
      for (const entry of entries) {
        const ttl = entry.ttl ?? CacheTTL.MEDIUM;
        pipeline.setex(entry.key, ttl, JSON.stringify(entry.value));
      }
      await pipeline.exec();
      return true;
    }

    // Memory fallback
    for (const entry of entries) {
      const ttl = entry.ttl ?? CacheTTL.MEDIUM;
      await cacheSet(entry.key, entry.value, ttl);
    }
    return true;
  } catch (error) {
    console.error('❌ Cache set multiple error:', error);
    return false;
  }
}

/**
 * Get multiple values at once
 */
export async function cacheGetMultiple<T>(keys: string[]): Promise<(T | null)[]> {
  try {
    if (isRedisAvailable()) {
      const values = await redis.mget(...keys);
      return values.map((v) => (v ? (JSON.parse(v) as T) : null));
    }

    // Memory fallback
    return keys.map((key) => {
      const entry = memoryCache.get(key);
      if (entry && entry.expiresAt > Date.now()) {
        return JSON.parse(entry.value) as T;
      }
      return null;
    });
  } catch (error) {
    console.error('❌ Cache get multiple error:', error);
    return keys.map(() => null);
  }
}

/**
 * Cache statistics for monitoring
 */
export async function getCacheStats(): Promise<{
  redis: {
    available: boolean;
    keys?: number;
    memory?: string;
  };
  memory: {
    size: number;
    maxSize: number;
  };
}> {
  const stats = {
    redis: {
      available: isRedisAvailable(),
    } as { available: boolean; keys?: number; memory?: string },
    memory: {
      size: memoryCache.size,
      maxSize: MEMORY_CACHE_MAX_SIZE,
    },
  };

  if (isRedisAvailable()) {
    try {
      const info = await redis.info('memory');
      const usedMemoryMatch = info.match(/used_memory_human:(\S+)/);
      if (usedMemoryMatch) {
        stats.redis.memory = usedMemoryMatch[1];
      }

      const dbSize = await redis.dbsize();
      stats.redis.keys = dbSize;
    } catch (error) {
      console.error('❌ Error getting Redis stats:', error);
    }
  }

  return stats;
}

// ============================================
// PUB/SUB FOR CACHE INVALIDATION
// ============================================

const INVALIDATION_CHANNEL = 'cache:invalidate';

type InvalidationMessage = {
  type: 'key' | 'pattern' | 'user' | 'post';
  value: string;
  authorId?: string;
};

/**
 * Subscribe to cache invalidation events
 * Call this on server startup for multi-instance deployments
 */
export async function subscribeToCacheInvalidation(): Promise<void> {
  if (!isRedisAvailable()) {
    console.warn('⚠️ Redis not available, skipping pub/sub subscription');
    return;
  }

  try {
    await redisSubscriber.connect();
    await redisSubscriber.subscribe(INVALIDATION_CHANNEL);

    redisSubscriber.on('message', async (channel: string, message: string) => {
      if (channel !== INVALIDATION_CHANNEL) return;

      try {
        const data = JSON.parse(message) as InvalidationMessage;

        switch (data.type) {
          case 'key':
            await cacheDelete(data.value);
            break;
          case 'pattern':
            await cacheDeletePattern(data.value);
            break;
          case 'user':
            await invalidateUserCache(data.value);
            break;
          case 'post':
            await invalidatePostCache(data.value, data.authorId);
            break;
        }
      } catch (error) {
        console.error('❌ Error processing invalidation message:', error);
      }
    });

    console.log('✅ Subscribed to cache invalidation channel');
  } catch (error) {
    console.error('❌ Failed to subscribe to cache invalidation:', error);
  }
}

/**
 * Publish cache invalidation event to all instances
 */
export async function publishCacheInvalidation(
  message: InvalidationMessage
): Promise<void> {
  if (!isRedisAvailable()) return;

  try {
    await redisPublisher.connect();
    await redisPublisher.publish(INVALIDATION_CHANNEL, JSON.stringify(message));
  } catch (error) {
    console.error('❌ Failed to publish cache invalidation:', error);
  }
}

/**
 * Broadcast user cache invalidation to all instances
 */
export async function broadcastUserInvalidation(userId: string): Promise<void> {
  await invalidateUserCache(userId);
  await publishCacheInvalidation({ type: 'user', value: userId });
}

/**
 * Broadcast post cache invalidation to all instances
 */
export async function broadcastPostInvalidation(
  postId: string,
  authorId?: string
): Promise<void> {
  await invalidatePostCache(postId, authorId);
  await publishCacheInvalidation({ type: 'post', value: postId, authorId });
}

