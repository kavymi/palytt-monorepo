//
//  notificationRateLimiter.ts
//  Palytt Backend
//
//  Rate limiting and smart timing for notifications
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import { prisma } from '../db.js';

// Maximum notifications per user per day
const MAX_NOTIFICATIONS_PER_DAY = 15;

// Maximum push notifications per user per hour
const MAX_PUSH_PER_HOUR = 5;

// Rate limit window durations in milliseconds
const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

// In-memory rate limit tracking (per user)
interface UserRateLimits {
  dailyCount: number;
  hourlyPushCount: number;
  dailyResetAt: number;
  hourlyResetAt: number;
}

const userRateLimits = new Map<string, UserRateLimits>();

/**
 * Get or create rate limit tracking for a user
 */
function getUserRateLimits(userId: string): UserRateLimits {
  const now = Date.now();
  let limits = userRateLimits.get(userId);

  if (!limits) {
    limits = {
      dailyCount: 0,
      hourlyPushCount: 0,
      dailyResetAt: now + DAY_MS,
      hourlyResetAt: now + HOUR_MS,
    };
    userRateLimits.set(userId, limits);
  }

  // Reset daily counter if window expired
  if (now >= limits.dailyResetAt) {
    limits.dailyCount = 0;
    limits.dailyResetAt = now + DAY_MS;
  }

  // Reset hourly counter if window expired
  if (now >= limits.hourlyResetAt) {
    limits.hourlyPushCount = 0;
    limits.hourlyResetAt = now + HOUR_MS;
  }

  return limits;
}

/**
 * Check if a notification can be sent to a user (daily limit)
 */
export function canSendNotification(userId: string): boolean {
  const limits = getUserRateLimits(userId);
  return limits.dailyCount < MAX_NOTIFICATIONS_PER_DAY;
}

/**
 * Check if a push notification can be sent to a user (hourly limit)
 */
export function canSendPushNotification(userId: string): boolean {
  const limits = getUserRateLimits(userId);
  return limits.hourlyPushCount < MAX_PUSH_PER_HOUR;
}

/**
 * Record that a notification was sent
 */
export function recordNotificationSent(userId: string): void {
  const limits = getUserRateLimits(userId);
  limits.dailyCount++;
}

/**
 * Record that a push notification was sent
 */
export function recordPushNotificationSent(userId: string): void {
  const limits = getUserRateLimits(userId);
  limits.hourlyPushCount++;
}

/**
 * Get current rate limit status for a user
 */
export function getRateLimitStatus(userId: string): {
  dailyCount: number;
  dailyLimit: number;
  hourlyPushCount: number;
  hourlyPushLimit: number;
  canSendNotification: boolean;
  canSendPush: boolean;
} {
  const limits = getUserRateLimits(userId);
  return {
    dailyCount: limits.dailyCount,
    dailyLimit: MAX_NOTIFICATIONS_PER_DAY,
    hourlyPushCount: limits.hourlyPushCount,
    hourlyPushLimit: MAX_PUSH_PER_HOUR,
    canSendNotification: limits.dailyCount < MAX_NOTIFICATIONS_PER_DAY,
    canSendPush: limits.hourlyPushCount < MAX_PUSH_PER_HOUR,
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

// In-memory cache for user activity patterns
const userActivityPatterns = new Map<string, UserActivityPattern>();

/**
 * Get user's optimal notification hours based on their activity
 */
export async function getOptimalNotificationHours(clerkId: string): Promise<number[]> {
  // Check cache first
  const cached = userActivityPatterns.get(clerkId);
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

    // Cache the result
    userActivityPatterns.set(clerkId, {
      userId: clerkId,
      hourlyActivity,
      peakHours,
      timezone: null,
    });

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
 * Clean up stale rate limit entries (for memory management)
 */
export function cleanupRateLimits(): void {
  const now = Date.now();
  const staleThreshold = DAY_MS * 2; // Remove entries older than 2 days

  for (const [userId, limits] of userRateLimits.entries()) {
    if (now - limits.dailyResetAt > staleThreshold) {
      userRateLimits.delete(userId);
    }
  }
}

// Run cleanup periodically
setInterval(cleanupRateLimits, HOUR_MS);

