//
//  notifications.processor.ts
//  Palytt Backend
//
//  Background processor for notification jobs
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import { Job } from 'bullmq';
import { createWorker, NotificationJobData, QueueNames } from '../queue.service.js';
import { canSendPushNotification, recordPushNotificationSent } from '../../services/notificationRateLimiter.js';

/**
 * Process notification jobs
 */
async function processNotificationJob(job: Job<NotificationJobData>): Promise<void> {
  const { type, recipientClerkId, title, body, data, badge } = job.data;

  console.log(`📬 Processing ${type} notification for ${recipientClerkId}: ${title}`);

  try {
    switch (type) {
      case 'push':
        await sendPushNotification(recipientClerkId, title, body, data, badge);
        break;
      case 'in_app':
        await createInAppNotification(recipientClerkId, title, body, data);
        break;
      case 'batch':
        await processBatchNotification(recipientClerkId, title, body, data);
        break;
      default:
        console.warn(`⚠️ Unknown notification type: ${type}`);
    }

    console.log(`✅ Notification sent to ${recipientClerkId}`);
  } catch (error) {
    console.error(`❌ Failed to send notification to ${recipientClerkId}:`, error);
    throw error; // Rethrow to trigger retry
  }
}

/**
 * Send a push notification via APNs/FCM
 */
async function sendPushNotification(
  recipientClerkId: string,
  title: string,
  body: string,
  data?: Record<string, string>,
  badge?: number
): Promise<void> {
  // Check rate limit
  const canSend = await canSendPushNotification(recipientClerkId);
  if (!canSend) {
    console.log(`⏸️ Push rate limit reached for ${recipientClerkId}, skipping`);
    return;
  }

  // TODO: Integrate with actual push notification service (APNs/FCM)
  // For now, just log the notification
  console.log(`📱 Push notification to ${recipientClerkId}:`, {
    title,
    body,
    data,
    badge,
  });

  // Record that we sent a push notification
  await recordPushNotificationSent(recipientClerkId);

  // Placeholder for actual implementation:
  // const pushService = await import('../../services/pushNotificationService.js');
  // await pushService.sendPush(recipientClerkId, { title, body, data, badge });
}

/**
 * Create an in-app notification (stored in database)
 */
async function createInAppNotification(
  recipientClerkId: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  // TODO: Create notification in database
  console.log(`📥 In-app notification for ${recipientClerkId}:`, {
    title,
    body,
    data,
  });

  // Placeholder for actual implementation:
  // const { prisma } = await import('../../db.js');
  // await prisma.notification.create({
  //   data: {
  //     userId: recipientClerkId,
  //     title,
  //     message: body,
  //     type: data?.type || 'GENERAL',
  //     metadata: data,
  //   },
  // });
}

/**
 * Process batched notifications (multiple notifications grouped together)
 */
async function processBatchNotification(
  recipientClerkId: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  // Batch notifications are typically combined into a single notification
  // e.g., "You have 5 new likes" instead of 5 separate notifications
  console.log(`📦 Batch notification for ${recipientClerkId}:`, {
    title,
    body,
    data,
  });

  // Send as a single push notification
  await sendPushNotification(recipientClerkId, title, body, data);
}

/**
 * Initialize the notifications worker
 */
export function initNotificationsWorker(): void {
  createWorker<NotificationJobData>(
    QueueNames.NOTIFICATIONS,
    processNotificationJob,
    {
      concurrency: 10, // Process up to 10 notifications concurrently
      limiter: {
        max: 100, // Max 100 jobs
        duration: 1000, // Per second
      },
    }
  );

  console.log('✅ Notifications worker initialized');
}

