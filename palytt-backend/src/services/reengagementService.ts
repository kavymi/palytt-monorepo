//
//  reengagementService.ts
//  Palytt Backend
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import { prisma } from '../db.js';
import { createNotification } from './notificationService.js';

// Re-engagement notification thresholds (in hours)
const REENGAGEMENT_THRESHOLDS = {
  FIRST_NUDGE: 24,      // 24 hours inactive
  SECOND_NUDGE: 72,     // 3 days inactive
  THIRD_NUDGE: 168,     // 7 days inactive
};

// Minimum time between re-engagement notifications (in hours)
const MIN_REENGAGEMENT_INTERVAL = 24;

interface ReengagementContext {
  friendPostsCount: number;
  unreadNotificationsCount: number;
  topFriendName: string | null;
}

/**
 * Updates the user's last active timestamp
 * Call this when the user performs any meaningful action in the app
 */
export async function updateUserActivity(clerkId: string): Promise<void> {
  try {
    await prisma.user.update({
      where: { clerkId },
      data: { lastActiveAt: new Date() },
    });
  } catch (error) {
    // Don't fail silently but log for debugging
    console.warn(`⚠️ Failed to update activity for user ${clerkId}:`, error);
  }
}

/**
 * Gets context data for personalizing re-engagement notifications
 */
async function getReengagementContext(userId: string, lastActiveAt: Date): Promise<ReengagementContext> {
  // Get friend posts since user was last active
  const friendPostsCount = await prisma.post.count({
    where: {
      createdAt: { gt: lastActiveAt },
      author: {
        OR: [
          { friendsSent: { some: { receiverId: userId, status: 'ACCEPTED' } } },
          { friendsReceived: { some: { senderId: userId, status: 'ACCEPTED' } } },
        ],
      },
    },
  });

  // Get unread notification count
  const unreadNotificationsCount = await prisma.notification.count({
    where: {
      userId,
      read: false,
    },
  });

  // Get the name of a friend who posted recently (for personalization)
  const recentFriendPost = await prisma.post.findFirst({
    where: {
      createdAt: { gt: lastActiveAt },
      author: {
        OR: [
          { friendsSent: { some: { receiverId: userId, status: 'ACCEPTED' } } },
          { friendsReceived: { some: { senderId: userId, status: 'ACCEPTED' } } },
        ],
      },
    },
    orderBy: { createdAt: 'desc' },
    select: {
      author: {
        select: { name: true, username: true },
      },
    },
  });

  const topFriendName = recentFriendPost?.author?.name || recentFriendPost?.author?.username || null;

  return {
    friendPostsCount,
    unreadNotificationsCount,
    topFriendName,
  };
}

/**
 * Generates the appropriate re-engagement notification message
 */
function generateReengagementMessage(
  hoursInactive: number,
  context: ReengagementContext
): { title: string; message: string } | null {
  // First nudge: 24 hours - Focus on friend activity
  if (hoursInactive >= REENGAGEMENT_THRESHOLDS.FIRST_NUDGE && hoursInactive < REENGAGEMENT_THRESHOLDS.SECOND_NUDGE) {
    if (context.friendPostsCount > 0) {
      const postWord = context.friendPostsCount === 1 ? 'update' : 'updates';
      return {
        title: "Your friends are posting!",
        message: `Your friends posted ${context.friendPostsCount} new ${postWord}. See what they've been up to!`,
      };
    }
    return null; // Don't send if no friend activity
  }

  // Second nudge: 3 days - Focus on unread notifications
  if (hoursInactive >= REENGAGEMENT_THRESHOLDS.SECOND_NUDGE && hoursInactive < REENGAGEMENT_THRESHOLDS.THIRD_NUDGE) {
    if (context.unreadNotificationsCount > 0) {
      const notifWord = context.unreadNotificationsCount === 1 ? 'notification' : 'notifications';
      return {
        title: "You have unread notifications",
        message: `You have ${context.unreadNotificationsCount} unread ${notifWord} waiting for you.`,
      };
    }
    if (context.friendPostsCount > 0) {
      return {
        title: "Catch up with friends",
        message: `${context.friendPostsCount} new posts from your friends since your last visit.`,
      };
    }
    return null;
  }

  // Third nudge: 7 days - Personal touch with friend name
  if (hoursInactive >= REENGAGEMENT_THRESHOLDS.THIRD_NUDGE) {
    if (context.topFriendName) {
      return {
        title: "We miss you!",
        message: `${context.topFriendName} and your friends have been active. Come see what's new!`,
      };
    }
    return {
      title: "It's been a while!",
      message: "Come back and see what's happening on Palytt.",
    };
  }

  return null;
}

/**
 * Checks if a user should receive a re-engagement notification
 * and sends one if appropriate
 */
export async function checkAndSendReengagement(clerkId: string): Promise<boolean> {
  try {
    const user = await prisma.user.findUnique({
      where: { clerkId },
      select: {
        id: true,
        lastActiveAt: true,
        reengagementSentAt: true,
      },
    });

    if (!user) return false;

    const now = new Date();
    const hoursInactive = (now.getTime() - user.lastActiveAt.getTime()) / (1000 * 60 * 60);

    // User is still active, no need for re-engagement
    if (hoursInactive < REENGAGEMENT_THRESHOLDS.FIRST_NUDGE) {
      return false;
    }

    // Check if we've sent a re-engagement notification recently
    if (user.reengagementSentAt) {
      const hoursSinceLastReengagement = (now.getTime() - user.reengagementSentAt.getTime()) / (1000 * 60 * 60);
      if (hoursSinceLastReengagement < MIN_REENGAGEMENT_INTERVAL) {
        return false;
      }
    }

    // Get context for personalized message
    const context = await getReengagementContext(user.id, user.lastActiveAt);
    const notification = generateReengagementMessage(hoursInactive, context);

    if (!notification) {
      return false;
    }

    // Send the notification
    await createNotification(
      clerkId,
      'GENERAL',
      notification.title,
      notification.message,
      {
        reengagement: true,
        hoursInactive: Math.floor(hoursInactive),
        friendPostsCount: context.friendPostsCount,
        unreadCount: context.unreadNotificationsCount,
      }
    );

    // Update the reengagement sent timestamp
    await prisma.user.update({
      where: { clerkId },
      data: { reengagementSentAt: now },
    });

    console.log(`✅ Sent re-engagement notification to user ${clerkId} (${Math.floor(hoursInactive)}h inactive)`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send re-engagement notification to ${clerkId}:`, error);
    return false;
  }
}

/**
 * Batch process all users who might need re-engagement notifications
 * This should be called by a scheduled job (e.g., every hour)
 */
export async function processReengagementNotifications(): Promise<{ processed: number; sent: number }> {
  const cutoffDate = new Date();
  cutoffDate.setHours(cutoffDate.getHours() - REENGAGEMENT_THRESHOLDS.FIRST_NUDGE);

  const minReengagementInterval = new Date();
  minReengagementInterval.setHours(minReengagementInterval.getHours() - MIN_REENGAGEMENT_INTERVAL);

  try {
    // Find users who are inactive and haven't received a recent re-engagement notification
    const inactiveUsers = await prisma.user.findMany({
      where: {
        isActive: true,
        lastActiveAt: { lt: cutoffDate },
        OR: [
          { reengagementSentAt: null },
          { reengagementSentAt: { lt: minReengagementInterval } },
        ],
      },
      select: {
        clerkId: true,
      },
      take: 100, // Process in batches to avoid overwhelming the system
    });

    let sentCount = 0;
    for (const user of inactiveUsers) {
      const sent = await checkAndSendReengagement(user.clerkId);
      if (sent) sentCount++;
    }

    console.log(`📊 Re-engagement batch: processed ${inactiveUsers.length} users, sent ${sentCount} notifications`);
    return { processed: inactiveUsers.length, sent: sentCount };
  } catch (error) {
    console.error('❌ Failed to process re-engagement notifications:', error);
    return { processed: 0, sent: 0 };
  }
}

/**
 * Gets re-engagement stats for monitoring
 */
export async function getReengagementStats(): Promise<{
  totalInactiveUsers: number;
  inactive24h: number;
  inactive3d: number;
  inactive7d: number;
}> {
  const now = new Date();
  
  const cutoff24h = new Date(now.getTime() - REENGAGEMENT_THRESHOLDS.FIRST_NUDGE * 60 * 60 * 1000);
  const cutoff3d = new Date(now.getTime() - REENGAGEMENT_THRESHOLDS.SECOND_NUDGE * 60 * 60 * 1000);
  const cutoff7d = new Date(now.getTime() - REENGAGEMENT_THRESHOLDS.THIRD_NUDGE * 60 * 60 * 1000);

  const [totalInactive, inactive24h, inactive3d, inactive7d] = await Promise.all([
    prisma.user.count({ where: { isActive: true, lastActiveAt: { lt: cutoff24h } } }),
    prisma.user.count({ where: { isActive: true, lastActiveAt: { lt: cutoff24h, gte: cutoff3d } } }),
    prisma.user.count({ where: { isActive: true, lastActiveAt: { lt: cutoff3d, gte: cutoff7d } } }),
    prisma.user.count({ where: { isActive: true, lastActiveAt: { lt: cutoff7d } } }),
  ]);

  return {
    totalInactiveUsers: totalInactive,
    inactive24h,
    inactive3d,
    inactive7d,
  };
}

