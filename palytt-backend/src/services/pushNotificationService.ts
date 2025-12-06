//
//  pushNotificationService.ts
//  Palytt Backend
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import { prisma } from '../db.js';
import type pkg from '@prisma/client';
type NotificationType = pkg.NotificationType;

// APNs configuration - will be used when HTTP/2 APNs is implemented
// For now, these are read from environment but used only for configuration check
const APNS_KEY_ID = process.env.APNS_KEY_ID;
const APNS_TEAM_ID = process.env.APNS_TEAM_ID;
const APNS_KEY_PATH = process.env.APNS_KEY_PATH;

interface PushPayload {
  title: string;
  body: string;
  badge?: number;
  sound?: string;
  category?: string;
  threadId?: string;
  data?: Record<string, any>;
}

interface APNsNotification {
  aps: {
    alert: {
      title: string;
      body: string;
    };
    badge?: number;
    sound?: string;
    category?: string;
    'thread-id'?: string;
    'mutable-content'?: number;
  };
  [key: string]: any;
}

/**
 * Get the notification category for interactive notifications
 */
function getNotificationCategory(type: NotificationType): string {
  switch (type) {
    case 'FRIEND_REQUEST':
      return 'FRIEND_REQUEST';
    case 'POST_LIKE':
    case 'COMMENT':
    case 'COMMENT_LIKE':
      return 'POST_INTERACTION';
    case 'MESSAGE':
      return 'MESSAGE';
    default:
      return 'GENERAL';
  }
}

/**
 * Register or update a device token for a user
 */
export async function registerDeviceToken(
  userClerkId: string,
  token: string,
  platform: 'IOS' | 'ANDROID' | 'WEB' = 'IOS'
): Promise<void> {
  try {
    // Get user from clerkId
    const user = await prisma.user.findUnique({
      where: { clerkId: userClerkId },
      select: { id: true }
    });

    if (!user) {
      console.warn(`User not found for device token registration: ${userClerkId}`);
      return;
    }

    // Upsert the device token
    await prisma.deviceToken.upsert({
      where: { token },
      update: {
        userId: user.id,
        platform,
        isActive: true,
        lastUsedAt: new Date(),
      },
      create: {
        userId: user.id,
        token,
        platform,
        isActive: true,
      },
    });

    console.log(`✅ Device token registered for user ${userClerkId}`);
  } catch (error) {
    console.error('❌ Failed to register device token:', error);
    throw error;
  }
}

/**
 * Unregister a device token (e.g., on logout)
 */
export async function unregisterDeviceToken(token: string): Promise<void> {
  try {
    await prisma.deviceToken.update({
      where: { token },
      data: { isActive: false },
    });
    console.log(`✅ Device token unregistered`);
  } catch (error) {
    // Token might not exist, which is fine
    console.warn('⚠️ Failed to unregister device token:', error);
  }
}

/**
 * Get all active device tokens for a user
 */
export async function getActiveDeviceTokens(userId: string): Promise<string[]> {
  const tokens = await prisma.deviceToken.findMany({
    where: {
      userId,
      isActive: true,
    },
    select: { token: true },
  });

  return tokens.map(t => t.token);
}

/**
 * Build APNs notification payload
 */
function buildAPNsPayload(payload: PushPayload): APNsNotification {
  const notification: APNsNotification = {
    aps: {
      alert: {
        title: payload.title,
        body: payload.body,
      },
      sound: payload.sound || 'default',
      'mutable-content': 1, // Enable notification service extension for rich notifications
    },
  };

  if (payload.badge !== undefined) {
    notification.aps.badge = payload.badge;
  }

  if (payload.category) {
    notification.aps.category = payload.category;
  }

  if (payload.threadId) {
    notification.aps['thread-id'] = payload.threadId;
  }

  // Add custom data
  if (payload.data) {
    Object.assign(notification, payload.data);
  }

  return notification;
}

/**
 * Send a push notification to a single device
 * Note: This is a simplified implementation. For production, use a library like @parse/node-apn
 */
async function sendToDevice(token: string, payload: APNsNotification): Promise<boolean> {
  // Check if APNs is configured
  if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_KEY_PATH) {
    console.log('⚠️ APNs not configured, skipping push notification');
    console.log('📱 Would send push:', JSON.stringify(payload, null, 2));
    return false;
  }

  try {
    // In production, you would use the APNs HTTP/2 API here
    // For now, we'll log the notification that would be sent
    console.log(`📱 Sending push to device: ${token.substring(0, 20)}...`);
    console.log('📱 Payload:', JSON.stringify(payload, null, 2));
    
    // TODO: Implement actual APNs HTTP/2 request
    // This requires:
    // 1. Loading the APNs key file
    // 2. Creating a JWT token
    // 3. Making an HTTP/2 request to APNs
    
    return true;
  } catch (error) {
    console.error('❌ Failed to send push notification:', error);
    return false;
  }
}

/**
 * Send a push notification to a user
 */
export async function sendPushNotification(
  userClerkId: string,
  type: NotificationType,
  title: string,
  message: string,
  data?: Record<string, any>
): Promise<{ sent: number; failed: number }> {
  try {
    // Get user's database ID
    const user = await prisma.user.findUnique({
      where: { clerkId: userClerkId },
      select: { id: true }
    });

    if (!user) {
      console.warn(`User not found for push notification: ${userClerkId}`);
      return { sent: 0, failed: 0 };
    }

    // Get all active device tokens for the user
    const tokens = await getActiveDeviceTokens(user.id);

    if (tokens.length === 0) {
      console.log(`No active device tokens for user ${userClerkId}`);
      return { sent: 0, failed: 0 };
    }

    // Get unread notification count for badge
    const unreadCount = await prisma.notification.count({
      where: {
        userId: user.id,
        read: false,
      },
    });

    // Build the payload
    const payload = buildAPNsPayload({
      title,
      body: message,
      badge: unreadCount,
      category: getNotificationCategory(type),
      threadId: data?.postId || data?.chatroomId,
      data: {
        notificationType: type,
        ...data,
      },
    });

    // Send to all devices
    let sent = 0;
    let failed = 0;

    for (const token of tokens) {
      const success = await sendToDevice(token, payload);
      if (success) {
        sent++;
        // Update last used timestamp
        await prisma.deviceToken.update({
          where: { token },
          data: { lastUsedAt: new Date() },
        });
      } else {
        failed++;
      }
    }

    console.log(`📱 Push notification results: ${sent} sent, ${failed} failed`);
    return { sent, failed };
  } catch (error) {
    console.error('❌ Failed to send push notification:', error);
    return { sent: 0, failed: 1 };
  }
}

/**
 * Send a push notification when creating a notification
 * This is called from notificationService after creating the in-app notification
 */
export async function sendPushForNotification(
  userClerkId: string,
  type: NotificationType,
  title: string,
  message: string,
  data?: Record<string, any>
): Promise<void> {
  try {
    await sendPushNotification(userClerkId, type, title, message, data);
  } catch (error) {
    // Don't throw - push notification failure shouldn't break the main flow
    console.error('❌ Failed to send push for notification:', error);
  }
}

/**
 * Clean up inactive or stale device tokens
 * Should be run periodically (e.g., daily cron job)
 */
export async function cleanupStaleTokens(daysInactive: number = 30): Promise<number> {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - daysInactive);

  const result = await prisma.deviceToken.deleteMany({
    where: {
      OR: [
        { isActive: false },
        { lastUsedAt: { lt: cutoffDate } },
      ],
    },
  });

  console.log(`🧹 Cleaned up ${result.count} stale device tokens`);
  return result.count;
}
