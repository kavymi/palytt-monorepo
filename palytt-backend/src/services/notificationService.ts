//
//  notificationService.ts
//  Palytt Backend
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import { prisma } from '../db.js';
import { syncNotificationToConvex, recordFriendActivity, type ConvexNotificationType } from './convexSync.js';
import { sendPushForNotification } from './pushNotificationService.js';
import {
  canSendNotification,
  canSendPushNotification,
  recordNotificationSent,
  recordPushNotificationSent,
  getNotificationPriority,
} from './notificationRateLimiter.js';
import { addNotificationJob, addAnalyticsJob } from '../jobs/queue.service.js';
import { isRedisAvailable } from '../cache/redis.js';
import type pkg from '@prisma/client';
type NotificationType = pkg.NotificationType;

// Flag to control whether to use background jobs for notifications
const USE_BACKGROUND_JOBS = true;

export interface NotificationData {
  postId?: string;
  commentId?: string;
  friendRequestId?: string;
  senderId?: string;
  senderName?: string;
  [key: string]: any;
}

// ============================================
// NOTIFICATION BATCHING SYSTEM
// ============================================

// Batching window in milliseconds (15 minutes)
const BATCH_WINDOW_MS = 15 * 60 * 1000;

// Types that should be batched
const BATCHABLE_TYPES: NotificationType[] = ['POST_LIKE', 'COMMENT'];

interface BatchedNotification {
  userClerkId: string;
  postId: string;
  type: NotificationType;
  senders: Array<{ senderId: string; senderName: string }>;
  postTitle: string;
  firstCreatedAt: Date;
  timeoutId: NodeJS.Timeout;
}

// In-memory batch storage (keyed by `${userClerkId}:${postId}:${type}`)
const notificationBatches = new Map<string, BatchedNotification>();

/**
 * Generates a batch key for identifying similar notifications
 */
function getBatchKey(userClerkId: string, postId: string, type: NotificationType): string {
  return `${userClerkId}:${postId}:${type}`;
}

/**
 * Generates batched notification message
 * Examples:
 * - "Sarah liked your post"
 * - "Sarah and John liked your post"
 * - "Sarah and 3 others liked your post"
 */
function generateBatchedMessage(
  type: NotificationType,
  senders: Array<{ senderName: string }>,
  postTitle: string
): { title: string; message: string } {
  const count = senders.length;
  const firstName = senders[0]?.senderName || 'Someone';

  if (type === 'POST_LIKE') {
    if (count === 1) {
      return {
        title: `❤️ ${firstName} liked your post`,
        message: `${firstName} loved "${postTitle}"`,
      };
    } else if (count === 2) {
      const secondName = senders[1]?.senderName || 'someone';
      return {
        title: `❤️ ${firstName} and ${secondName} liked your post`,
        message: `Your post is getting love! 🔥`,
      };
    } else {
      const othersCount = count - 1;
      return {
        title: `🔥 ${firstName} and ${othersCount} others liked your post`,
        message: `Your post "${postTitle}" is trending!`,
      };
    }
  }

  if (type === 'COMMENT') {
    if (count === 1) {
      return {
        title: `💬 ${firstName} commented`,
        message: `${firstName} commented on "${postTitle}"`,
      };
    } else if (count === 2) {
      const secondName = senders[1]?.senderName || 'someone';
      return {
        title: `💬 ${firstName} and ${secondName} commented`,
        message: `Join the conversation on "${postTitle}"`,
      };
    } else {
      const othersCount = count - 1;
      return {
        title: `🔥 ${count} new comments`,
        message: `${firstName} and ${othersCount} others are discussing "${postTitle}"`,
      };
    }
  }

  // Fallback for other types
  return {
    title: `✨ New activity`,
    message: `You have ${count} new interactions on "${postTitle}"`,
  };
}

/**
 * Flushes a batched notification - sends the consolidated notification
 */
async function flushBatch(batchKey: string): Promise<void> {
  const batch = notificationBatches.get(batchKey);
  if (!batch) return;

  // Remove from batches
  notificationBatches.delete(batchKey);

  try {
    const { title, message } = generateBatchedMessage(
      batch.type,
      batch.senders,
      batch.postTitle
    );

    // Get user database ID
    const user = await prisma.user.findUnique({
      where: { clerkId: batch.userClerkId },
      select: { id: true },
    });

    if (!user) {
      console.warn(`User not found for batched notification: ${batch.userClerkId}`);
      return;
    }

    // Create consolidated notification
    const notification = await prisma.notification.create({
      data: {
        userId: user.id,
        type: batch.type,
        title,
        message,
        data: {
          postId: batch.postId,
          senderIds: batch.senders.map((s) => s.senderId),
          senderNames: batch.senders.map((s) => s.senderName),
          senderId: batch.senders[0]?.senderId,
          senderName: batch.senders[0]?.senderName,
          batchCount: batch.senders.length,
          postTitle: batch.postTitle,
        },
      },
    });

    console.log(
      `✅ Batched notification sent to ${batch.userClerkId}: ${batch.type} with ${batch.senders.length} senders`
    );

    // Sync to Convex for real-time delivery
    syncNotificationToConvex(
      notification.id,
      batch.userClerkId,
      batch.type as ConvexNotificationType,
      title,
      message,
      batch.senders[0]?.senderId,
      batch.senders[0]?.senderName,
      {
        postId: batch.postId,
        userId: batch.senders[0]?.senderId,
      }
    ).catch((err) => {
      console.warn('⚠️ Failed to sync batched notification to Convex:', err);
    });
  } catch (error) {
    console.error('❌ Failed to flush batched notification:', error);
  }
}

/**
 * Adds a notification to the batch or creates a new batch
 * Returns true if batched, false if sent immediately
 */
async function addToBatchOrSend(
  userClerkId: string,
  type: NotificationType,
  senderId: string,
  senderName: string,
  postId: string,
  postTitle: string
): Promise<boolean> {
  // Only batch certain notification types
  if (!BATCHABLE_TYPES.includes(type)) {
    return false;
  }

  const batchKey = getBatchKey(userClerkId, postId, type);
  const existingBatch = notificationBatches.get(batchKey);

  if (existingBatch) {
    // Add to existing batch (avoid duplicates from same sender)
    const alreadyInBatch = existingBatch.senders.some((s) => s.senderId === senderId);
    if (!alreadyInBatch) {
      existingBatch.senders.push({ senderId, senderName });
    }
    console.log(
      `📦 Added to batch: ${batchKey} (now ${existingBatch.senders.length} senders)`
    );
    return true;
  }

  // Create new batch with timeout
  const timeoutId = setTimeout(() => {
    flushBatch(batchKey);
  }, BATCH_WINDOW_MS);

  const newBatch: BatchedNotification = {
    userClerkId,
    postId,
    type,
    senders: [{ senderId, senderName }],
    postTitle,
    firstCreatedAt: new Date(),
    timeoutId,
  };

  notificationBatches.set(batchKey, newBatch);
  console.log(`📦 Created new batch: ${batchKey}`);

  return true;
}

/**
 * Forces all pending batches to flush immediately
 * Useful for testing or graceful shutdown
 */
export async function flushAllBatches(): Promise<void> {
  const batchKeys = Array.from(notificationBatches.keys());
  for (const batchKey of batchKeys) {
    const batch = notificationBatches.get(batchKey);
    if (batch) {
      clearTimeout(batch.timeoutId);
      await flushBatch(batchKey);
    }
  }
  console.log(`📦 Flushed ${batchKeys.length} notification batches`);
}

/**
 * Gets the current batch status (for debugging/monitoring)
 */
export function getBatchStatus(): { activeBatches: number; totalPending: number } {
  let totalPending = 0;
  for (const batch of notificationBatches.values()) {
    totalPending += batch.senders.length;
  }
  return {
    activeBatches: notificationBatches.size,
    totalPending,
  };
}

/**
 * Creates a notification for a user
 * Includes rate limiting and smart push notification delivery
 * Also syncs to Convex for real-time delivery
 */
export async function createNotification(
  userClerkId: string,
  type: NotificationType,
  title: string,
  message: string,
  data: NotificationData = {}
): Promise<void> {
  try {
    // Don't send notifications to yourself
    if (data.senderId && data.senderId === userClerkId) {
      return;
    }

    // Check daily rate limit
    if (!await canSendNotification(userClerkId)) {
      console.log(`⏸️ Rate limited: skipping notification for ${userClerkId} (daily limit)`);
      return;
    }

    // Check if user exists and get their database ID
    const user = await prisma.user.findUnique({
      where: { clerkId: userClerkId },
      select: { id: true }
    });

    if (!user) {
      console.warn(`User not found for notification: ${userClerkId}`);
      return;
    }

    // Create notification in PostgreSQL
    const notification = await prisma.notification.create({
      data: {
        userId: user.id,
        type,
        title,
        message,
        data: data || {},
      },
    });

    // Record that we sent a notification (for rate limiting)
    await recordNotificationSent(userClerkId);
    
    // Track analytics event in background
    if (USE_BACKGROUND_JOBS && isRedisAvailable()) {
      addAnalyticsJob({
        type: 'engagement',
        userId: userClerkId,
        eventType: 'notification_created',
        eventData: { notificationType: type, title },
        timestamp: Date.now(),
      }).catch(() => {
        // Silently ignore analytics failures
      });
    }

    console.log(`✅ Notification created for user ${userClerkId}: ${type} - ${title}`);

    // Determine if we should send a push notification based on priority
    const priority = getNotificationPriority(type, {
      senderIsFriend: data.isFriend,
    });

    // Send push notification if allowed and within rate limits
    if (priority.shouldSendPush && await canSendPushNotification(userClerkId)) {
      // Use background job if Redis is available, otherwise send directly
      if (USE_BACKGROUND_JOBS && isRedisAvailable()) {
        addNotificationJob({
          type: 'push',
          recipientClerkId: userClerkId,
          title,
          body: message,
          data: {
            type,
            postId: data.postId || '',
            senderId: data.senderId || '',
          },
        }).catch((err) => {
          console.warn('⚠️ Failed to queue push notification, sending directly:', err);
          sendPushForNotification(userClerkId, type, title, message, data);
        });
        await recordPushNotificationSent(userClerkId);
      } else {
        sendPushForNotification(userClerkId, type, title, message, data)
          .then(async () => {
            await recordPushNotificationSent(userClerkId);
          })
          .catch((err) => {
            console.warn('⚠️ Failed to send push notification (non-blocking):', err);
          });
      }
    }

    // Also push to Convex for real-time delivery (always - this is in-app)
    syncNotificationToConvex(
      notification.id,
      userClerkId,
      type as ConvexNotificationType,
      title,
      message,
      data.senderId,
      data.senderName,
      {
        postId: data.postId,
        commentId: data.commentId,
        friendRequestId: data.friendRequestId,
        userId: data.senderId,
      }
    ).catch((err) => {
      console.warn('⚠️ Failed to sync notification to Convex (non-blocking):', err);
    });
  } catch (error) {
    console.error('❌ Failed to create notification:', error);
    // Don't throw error to avoid breaking the main operation
  }
}

/**
 * Creates a notification when someone likes a post
 * Uses batching to consolidate multiple likes into "X and Y others liked your post"
 * Also records activity for real-time friend feed
 */
export async function createPostLikeNotification(
  postId: string,
  likerUserId: string
): Promise<void> {
  try {
    // Get post details and author
    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: {
        title: true,
        caption: true,
        author: {
          select: {
            clerkId: true,
            name: true,
            username: true
          }
        }
      }
    });

    if (!post || !post.author) {
      return;
    }

    // Don't send notifications to yourself
    if (post.author.clerkId === likerUserId) {
      return;
    }

    // Get liker details
    const liker = await prisma.user.findUnique({
      where: { clerkId: likerUserId },
      select: {
        name: true,
        username: true
      }
    });

    if (!liker) {
      return;
    }

    const likerName = liker.name || liker.username || 'Someone';
    const postTitle = post.title || 'your post';

    // Try to add to batch - if batching is enabled for this type
    const batched = await addToBatchOrSend(
      post.author.clerkId,
      'POST_LIKE',
      likerUserId,
      likerName,
      postId,
      postTitle
    );

    // If not batched, send immediately (fallback) with engaging copy
    if (!batched) {
      await createNotification(
        post.author.clerkId,
        'POST_LIKE',
        `❤️ ${likerName} liked your post`,
        `${likerName} loved "${postTitle}"`,
        {
          postId,
          senderId: likerUserId,
          senderName: likerName,
          likerName,
          postTitle
        }
      );
    }

    // Record activity for friend feed (non-blocking, always immediate)
    recordFriendActivity(
      likerUserId,
      likerName,
      'liked_post',
      postId,
      'post',
      postTitle.substring(0, 50)
    ).catch((err) => {
      console.warn('⚠️ Failed to record like activity to Convex:', err);
    });
  } catch (error) {
    console.error('❌ Failed to create post like notification:', error);
  }
}

/**
 * Creates a notification when someone comments on a post
 * Uses batching to consolidate multiple comments into "X and Y others commented on your post"
 * Also records activity for real-time friend feed
 */
export async function createPostCommentNotification(
  postId: string,
  commenterId: string,
  commentContent: string
): Promise<void> {
  try {
    // Get post details and author
    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: {
        title: true,
        caption: true,
        author: {
          select: {
            clerkId: true,
            name: true,
            username: true
          }
        }
      }
    });

    if (!post || !post.author) {
      return;
    }

    // Don't send notifications to yourself
    if (post.author.clerkId === commenterId) {
      return;
    }

    // Get commenter details
    const commenter = await prisma.user.findUnique({
      where: { clerkId: commenterId },
      select: {
        name: true,
        username: true
      }
    });

    if (!commenter) {
      return;
    }

    const commenterName = commenter.name || commenter.username || 'Someone';
    const postTitle = post.title || 'your post';
    const truncatedComment = commentContent.length > 50 
      ? commentContent.substring(0, 50) + '...' 
      : commentContent;

    // Try to add to batch - if batching is enabled for this type
    const batched = await addToBatchOrSend(
      post.author.clerkId,
      'COMMENT',
      commenterId,
      commenterName,
      postId,
      postTitle
    );

    // If not batched, send immediately (fallback)
    if (!batched) {
      await createNotification(
        post.author.clerkId,
        'COMMENT',
        `💬 ${commenterName} commented`,
        `${commenterName}: "${truncatedComment}"`,
        {
          postId,
          senderId: commenterId,
          senderName: commenterName,
          commenterName,
          postTitle,
          commentContent: truncatedComment
        }
      );
    }

    // Record activity for friend feed (non-blocking, always immediate)
    recordFriendActivity(
      commenterId,
      commenterName,
      'commented',
      postId,
      'post',
      truncatedComment
    ).catch((err) => {
      console.warn('⚠️ Failed to record comment activity to Convex:', err);
    });
  } catch (error) {
    console.error('❌ Failed to create post comment notification:', error);
  }
}

/**
 * Creates a notification when someone sends a friend request
 */
export async function createFriendRequestNotification(
  receiverId: string,
  senderId: string,
  friendRequestId: string
): Promise<void> {
  try {
    // Get sender details
    const sender = await prisma.user.findUnique({
      where: { clerkId: senderId },
      select: {
        name: true,
        username: true
      }
    });

    if (!sender) {
      return;
    }

    const senderName = sender.name || sender.username || 'Someone';

    await createNotification(
      receiverId,
      'FRIEND_REQUEST',
      'New friend request',
      `${senderName} sent you a friend request`,
      {
        friendRequestId,
        senderId,
        senderName
      }
    );
  } catch (error) {
    console.error('❌ Failed to create friend request notification:', error);
  }
}

/**
 * Creates a notification when someone accepts a friend request
 */
export async function createFriendRequestAcceptedNotification(
  senderId: string,
  accepterId: string
): Promise<void> {
  try {
    // Get accepter details
    const accepter = await prisma.user.findUnique({
      where: { clerkId: accepterId },
      select: {
        name: true,
        username: true
      }
    });

    if (!accepter) {
      return;
    }

    const accepterName = accepter.name || accepter.username || 'Someone';

    await createNotification(
      senderId,
      'FRIEND_ACCEPTED',
      'Friend request accepted',
      `${accepterName} accepted your friend request`,
      {
        senderId: accepterId,
        accepterName
      }
    );
  } catch (error) {
    console.error('❌ Failed to create friend request accepted notification:', error);
  }
}
