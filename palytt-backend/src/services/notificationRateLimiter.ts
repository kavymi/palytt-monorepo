//
//  notificationRateLimiter.ts
//  Palytt Backend
//
//  Rate limiting and smart timing for notifications
//  Uses Redis for distributed rate limiting across instances
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import { prisma } from '../db.js';
import { redis, isRedisAvailable } from '../cache/redis.js';
import { cacheGet, cacheSet, CacheTTL } from '../cache/cache.service.js';

// Maximum notifications per user per day
const MAX_NOTIFICATIONS_PER_DAY = 15;

// Maximum push notifications per user per hour
const MAX_PUSH_PER_HOUR = 5;

// Rate limit window durations in seconds
const DAY_SECONDS = 24 * 60 * 60;
const HOUR_SECONDS = 60 * 60;

// Redis key prefixes
const RATE_LIMIT_PREFIX = 'ratelimit:notification:';
const PUSH_RATE_LIMIT_PREFIX = 'ratelimit:push:';
const ACTIVITY_PATTERN_PREFIX = 'activity:pattern:';

// In-memory fallback for when Redis is unavailable
interface UserRateLimits {
  dailyCount: number;
  hourlyPushCount: number;
  dailyResetAt: number;
  hourlyResetAt: number;
}

const memoryRateLimits = new Map<string, UserRateLimits>();

/**
 * Get daily notification count for a user from Redis
 */
async function getDailyNotificationCount(userId: string): Promise<number> {
  if (!isRedisAvailable()) {
    return getMemoryDailyCount(userId);
  }

  try {
    const key = `${RATE_LIMIT_PREFIX}daily:${userId}`;
    const count = await redis.get(key);
    return count ? parseInt(count, 10) : 0;
  } catch (error) {
    console.error('❌ Redis error getting daily count:', error);
    return getMemoryDailyCount(userId);
  }
}

/**
 * Get hourly push notification count for a user from Redis
 */
async function getHourlyPushCount(userId: string): Promise<number> {
  if (!isRedisAvailable()) {
    return getMemoryHourlyPushCount(userId);
  }

  try {
    const key = `${PUSH_RATE_LIMIT_PREFIX}hourly:${userId}`;
    const count = await redis.get(key);
    return count ? parseInt(count, 10) : 0;
  } catch (error) {
    console.error('❌ Redis error getting hourly push count:', error);
    return getMemoryHourlyPushCount(userId);
  }
}

/**
 * Memory fallback: Get daily count
 */
function getMemoryDailyCount(userId: string): number {
  const limits = getOrCreateMemoryLimits(userId);
  return limits.dailyCount;
}

/**
 * Memory fallback: Get hourly push count
 */
function getMemoryHourlyPushCount(userId: string): number {
  const limits = getOrCreateMemoryLimits(userId);
  return limits.hourlyPushCount;
}

/**
 * Memory fallback: Get or create limits
 */
function getOrCreateMemoryLimits(userId: string): UserRateLimits {
  const now = Date.now();
  let limits = memoryRateLimits.get(userId);

  if (!limits) {
    limits = {
      dailyCount: 0,
      hourlyPushCount: 0,
      dailyResetAt: now + DAY_SECONDS * 1000,
      hourlyResetAt: now + HOUR_SECONDS * 1000,
    };
    memoryRateLimits.set(userId, limits);
  }

  // Reset daily counter if window expired
  if (now >= limits.dailyResetAt) {
    limits.dailyCount = 0;
    limits.dailyResetAt = now + DAY_SECONDS * 1000;
  }

  // Reset hourly counter if window expired
  if (now >= limits.hourlyResetAt) {
    limits.hourlyPushCount = 0;
    limits.hourlyResetAt = now + HOUR_SECONDS * 1000;
  }

  return limits;
}

/**
 * Check if a notification can be sent to a user (daily limit)
 */
export async function canSendNotification(userId: string): Promise<boolean> {
  const count = await getDailyNotificationCount(userId);
  return count < MAX_NOTIFICATIONS_PER_DAY;
}

/**
 * Check if a push notification can be sent to a user (hourly limit)
 */
export async function canSendPushNotification(userId: string): Promise<boolean> {
  const count = await getHourlyPushCount(userId);
  return count < MAX_PUSH_PER_HOUR;
}

/**
 * Record that a notification was sent
 */
export async function recordNotificationSent(userId: string): Promise<void> {
  if (!isRedisAvailable()) {
    const limits = getOrCreateMemoryLimits(userId);
    limits.dailyCount++;
    return;
  }

  try {
    const key = `${RATE_LIMIT_PREFIX}daily:${userId}`;
    const pipeline = redis.pipeline();
    pipeline.incr(key);
    // Set TTL only if key is new (to preserve existing expiry)
    pipeline.expire(key, DAY_SECONDS, 'NX');
    await pipeline.exec();
  } catch (error) {
    console.error('❌ Redis error recording notification:', error);
    // Fallback to memory
    const limits = getOrCreateMemoryLimits(userId);
    limits.dailyCount++;
  }
}

/**
 * Record that a push notification was sent
 */
export async function recordPushNotificationSent(userId: string): Promise<void> {
  if (!isRedisAvailable()) {
    const limits = getOrCreateMemoryLimits(userId);
    limits.hourlyPushCount++;
    return;
  }

  try {
    const key = `${PUSH_RATE_LIMIT_PREFIX}hourly:${userId}`;
    const pipeline = redis.pipeline();
    pipeline.incr(key);
    // Set TTL only if key is new (to preserve existing expiry)
    pipeline.expire(key, HOUR_SECONDS, 'NX');
    await pipeline.exec();
  } catch (error) {
    console.error('❌ Redis error recording push notification:', error);
    // Fallback to memory
    const limits = getOrCreateMemoryLimits(userId);
    limits.hourlyPushCount++;
  }
}

/**
 * Get current rate limit status for a user
 */
export async function getRateLimitStatus(userId: string): Promise<{
  dailyCount: number;
  dailyLimit: number;
  hourlyPushCount: number;
  hourlyPushLimit: number;
  canSendNotification: boolean;
  canSendPush: boolean;
}> {
  const [dailyCount, hourlyPushCount] = await Promise.all([
    getDailyNotificationCount(userId),
    getHourlyPushCount(userId),
  ]);

  return {
    dailyCount,
    dailyLimit: MAX_NOTIFICATIONS_PER_DAY,
    hourlyPushCount,
    hourlyPushLimit: MAX_PUSH_PER_HOUR,
    canSendNotification: dailyCount < MAX_NOTIFICATIONS_PER_DAY,
    canSendPush: hourlyPushCount < MAX_PUSH_PER_HOUR,
  };
}

// ============================================
// SMART TIMING - OPTIMAL NOTIFICATION TIMES
// ============================================

interface UserActivityPattern {
  userId: string;
  hourlyActivity: number[]; // 24 hours, 0-23
  peakHours: number[];
  timezone: string | null;
}

/**
 * Get user's optimal notification hours based on their activity
 * Uses Redis caching for performance
 */
export async function getOptimalNotificationHours(clerkId: string): Promise<number[]> {
  const cacheKey = `${ACTIVITY_PATTERN_PREFIX}${clerkId}`;
  
  // Check Redis cache first
  const cached = await cacheGet<UserActivityPattern>(cacheKey);
  if (cached) {
    return cached.peakHours;
  }

  try {
    // Get user's database ID
    const user = await prisma.user.findUnique({
      where: { clerkId },
      select: { id: true },
    });

    if (!user) {
      return [9, 12, 18, 20]; // Default: morning, noon, evening
    }

    // Analyze user's notification interactions in the last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const notifications = await prisma.notification.findMany({
      where: {
        userId: user.id,
        read: true,
        createdAt: { gte: thirtyDaysAgo },
      },
      select: { createdAt: true },
      take: 100,
    });

    // Count activity by hour
    const hourlyActivity = new Array(24).fill(0);
    for (const notification of notifications) {
      const hour = notification.createdAt.getHours();
      hourlyActivity[hour]++;
    }

    // Find top 4 active hours
    const hoursWithCounts = hourlyActivity.map((count, hour) => ({ hour, count }));
    hoursWithCounts.sort((a, b) => b.count - a.count);
    const peakHours = hoursWithCounts.slice(0, 4).map((h) => h.hour);

    // If no data, use defaults
    if (peakHours.every((h) => hourlyActivity[h] === 0)) {
      return [9, 12, 18, 20];
    }

    // Cache the result in Redis (1 hour TTL)
    const pattern: UserActivityPattern = {
      userId: clerkId,
      hourlyActivity,
      peakHours,
      timezone: null,
    };
    await cacheSet(cacheKey, pattern, CacheTTL.LONG);

    return peakHours;
  } catch (error) {
    console.error('❌ Failed to get optimal notification hours:', error);
    return [9, 12, 18, 20];
  }
}

/**
 * Check if current time is a good time to send notifications to a user
 */
export async function isGoodTimeToNotify(clerkId: string): Promise<boolean> {
  const optimalHours = await getOptimalNotificationHours(clerkId);
  const currentHour = new Date().getHours();
  
  // Allow notifications during peak hours or within 2 hours of peak
  for (const peakHour of optimalHours) {
    const diff = Math.abs(currentHour - peakHour);
    if (diff <= 2 || diff >= 22) { // Handle midnight wrap-around
      return true;
    }
  }
  
  return false;
}

/**
 * Get the next optimal time to send a notification to a user
 */
export async function getNextOptimalTime(clerkId: string): Promise<Date> {
  const optimalHours = await getOptimalNotificationHours(clerkId);
  const now = new Date();
  const currentHour = now.getHours();

  // Find the next optimal hour
  let nextHour = optimalHours.find((h) => h > currentHour);
  
  if (nextHour === undefined) {
    // All optimal hours are in the past today, use first hour tomorrow
    nextHour = optimalHours[0] || 9;
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(nextHour, 0, 0, 0);
    return tomorrow;
  }

  const nextTime = new Date(now);
  nextTime.setHours(nextHour, 0, 0, 0);
  return nextTime;
}

// ============================================
// NOTIFICATION PRIORITIZATION
// ============================================

type NotificationPriority = 'high' | 'medium' | 'low';

interface PrioritizedNotification {
  type: string;
  priority: NotificationPriority;
  shouldSendPush: boolean;
  canBatch: boolean;
}

/**
 * Determine notification priority based on type and context
 */
export function getNotificationPriority(
  type: string,
  context?: {
    senderIsFriend?: boolean;
    postIsRecent?: boolean;
    userHasHighEngagement?: boolean;
  }
): PrioritizedNotification {
  // High priority - always send push, don't batch
  const highPriorityTypes = ['FRIEND_REQUEST', 'MESSAGE'];
  if (highPriorityTypes.includes(type)) {
    return {
      type,
      priority: 'high',
      shouldSendPush: true,
      canBatch: false,
    };
  }

  // Medium priority - conditional push, can batch
  const mediumPriorityTypes = ['POST_LIKE', 'COMMENT', 'FOLLOW'];
  if (mediumPriorityTypes.includes(type)) {
    return {
      type,
      priority: 'medium',
      shouldSendPush: context?.senderIsFriend || context?.userHasHighEngagement || false,
      canBatch: true,
    };
  }

  // Low priority - no push, always batch if possible
  return {
    type,
    priority: 'low',
    shouldSendPush: false,
    canBatch: true,
  };
}

/**
 * Clean up stale rate limit entries from memory (for memory management)
 * Redis handles its own cleanup via TTL
 */
export function cleanupRateLimits(): void {
  const now = Date.now();
  const staleThreshold = DAY_SECONDS * 2 * 1000; // Remove entries older than 2 days

  for (const [userId, limits] of memoryRateLimits.entries()) {
    if (now - limits.dailyResetAt > staleThreshold) {
      memoryRateLimits.delete(userId);
    }
  }
}

// Run cleanup periodically (only for memory fallback)
setInterval(cleanupRateLimits, HOUR_SECONDS * 1000);
