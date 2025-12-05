//
//  convexSync.ts
//  Palytt Backend
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

/**
 * Convex Sync Service
 * 
 * This service handles pushing real-time updates to Convex for:
 * - Live notifications
 * - Friend activity feed
 * - Other real-time features
 * 
 * The Convex deployment URL should be configured via environment variables.
 */

// Notification types matching Convex schema
type ConvexNotificationType = 
  | 'POST_LIKE'
  | 'COMMENT'
  | 'COMMENT_LIKE'
  | 'FOLLOW'
  | 'FRIEND_REQUEST'
  | 'FRIEND_ACCEPTED'
  | 'FRIEND_POST'
  | 'MESSAGE'
  | 'POST_MENTION'
  | 'GENERAL';

// Activity types matching Convex schema
type ConvexActivityType =
  | 'posted'
  | 'liked_post'
  | 'commented'
  | 'followed'
  | 'joined_gathering'
  | 'shared_place';

interface ConvexNotificationPayload {
  recipientClerkId: string;
  senderClerkId?: string;
  senderName?: string;
  senderProfileImage?: string;
  type: ConvexNotificationType;
  title: string;
  message: string;
  metadata?: {
    postId?: string;
    commentId?: string;
    chatroomId?: string;
    friendRequestId?: string;
    userId?: string;
  };
  postgresId?: string; // Reference to PostgreSQL notification ID
}

interface ConvexActivityPayload {
  actorClerkId: string;
  actorName?: string;
  actorProfileImage?: string;
  activityType: ConvexActivityType;
  targetId?: string;
  targetType?: 'post' | 'comment' | 'user' | 'gathering' | 'place';
  targetPreview?: string;
}

// Convex deployment URL from environment
const CONVEX_DEPLOYMENT_URL = process.env.CONVEX_DEPLOYMENT_URL || 'https://clear-goose-685.convex.cloud';

/**
 * Push a notification to Convex for real-time delivery
 */
export async function pushNotificationToConvex(payload: ConvexNotificationPayload): Promise<boolean> {
  try {
    const body = {
      ...payload,
      isRead: false,
      createdAt: Date.now(),
    };

    // Call Convex HTTP action or mutation
    // Note: For production, use Convex's official Node.js client
    const response = await fetch(`${CONVEX_DEPLOYMENT_URL}/api/mutation`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        path: 'notifications:pushNotification',
        args: body,
      }),
    });

    if (!response.ok) {
      console.warn(`⚠️ Convex notification push failed: ${response.status}`);
      return false;
    }

    console.log(`✅ Pushed notification to Convex for ${payload.recipientClerkId}: ${payload.type}`);
    return true;
  } catch (error) {
    console.error('❌ Failed to push notification to Convex:', error);
    return false;
  }
}

/**
 * Push an activity to Convex for the friend activity feed
 */
export async function pushActivityToConvex(payload: ConvexActivityPayload): Promise<boolean> {
  try {
    const body = {
      ...payload,
      createdAt: Date.now(),
      expiresAt: Date.now() + (24 * 60 * 60 * 1000), // 24 hours from now
    };

    const response = await fetch(`${CONVEX_DEPLOYMENT_URL}/api/mutation`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        path: 'friendActivity:recordActivity',
        args: body,
      }),
    });

    if (!response.ok) {
      console.warn(`⚠️ Convex activity push failed: ${response.status}`);
      return false;
    }

    console.log(`✅ Pushed activity to Convex: ${payload.activityType} by ${payload.actorClerkId}`);
    return true;
  } catch (error) {
    console.error('❌ Failed to push activity to Convex:', error);
    return false;
  }
}

/**
 * Sync a PostgreSQL notification to Convex (for real-time + persistence)
 */
export async function syncNotificationToConvex(
  postgresId: string,
  recipientClerkId: string,
  type: ConvexNotificationType,
  title: string,
  message: string,
  senderClerkId?: string,
  senderName?: string,
  metadata?: ConvexNotificationPayload['metadata']
): Promise<void> {
  await pushNotificationToConvex({
    recipientClerkId,
    senderClerkId,
    senderName,
    type,
    title,
    message,
    metadata,
    postgresId,
  });
}

/**
 * Record a friend activity for real-time feed
 */
export async function recordFriendActivity(
  actorClerkId: string,
  actorName: string | undefined,
  activityType: ConvexActivityType,
  targetId?: string,
  targetType?: 'post' | 'comment' | 'user' | 'gathering' | 'place',
  targetPreview?: string
): Promise<void> {
  await pushActivityToConvex({
    actorClerkId,
    actorName,
    activityType,
    targetId,
    targetType,
    targetPreview,
  });
}

// Export types for use in other modules
export type { ConvexNotificationType, ConvexActivityType, ConvexNotificationPayload, ConvexActivityPayload };

