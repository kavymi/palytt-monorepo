//
//  cleanup.processor.ts
//  Palytt Backend
//
//  Background processor for cleanup/maintenance jobs
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import { Job } from 'bullmq';
import { createWorker, CleanupJobData, QueueNames } from '../queue.service.js';
import { prisma } from '../../db.js';
import { cacheDeletePattern } from '../../cache/cache.service.js';

/**
 * Process cleanup jobs
 */
async function processCleanupJob(job: Job<CleanupJobData>): Promise<void> {
  const { type, olderThanDays } = job.data;

  console.log(`🧹 Processing cleanup job: ${type}`);

  try {
    switch (type) {
      case 'old_notifications':
        await cleanupOldNotifications(olderThanDays ?? 30);
        break;
      case 'expired_tokens':
        await cleanupExpiredTokens();
        break;
      case 'stale_cache':
        await cleanupStaleCache();
        break;
      default:
        console.warn(`⚠️ Unknown cleanup type: ${type}`);
    }

    console.log(`✅ Cleanup job completed: ${type}`);
  } catch (error) {
    console.error(`❌ Failed to process cleanup job ${type}:`, error);
    throw error; // Rethrow to trigger retry
  }
}

/**
 * Clean up old read notifications
 */
async function cleanupOldNotifications(olderThanDays: number): Promise<void> {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - olderThanDays);

  console.log(`🗑️ Cleaning up notifications older than ${cutoffDate.toISOString()}`);

  try {
    const result = await prisma.notification.deleteMany({
      where: {
        read: true,
        createdAt: {
          lt: cutoffDate,
        },
      },
    });

    console.log(`✅ Deleted ${result.count} old notifications`);
  } catch (error) {
    console.error('❌ Error cleaning up old notifications:', error);
    throw error;
  }
}

/**
 * Clean up expired authentication tokens/sessions
 */
async function cleanupExpiredTokens(): Promise<void> {
  console.log('🔑 Cleaning up expired tokens...');

  // TODO: Implement token cleanup if storing refresh tokens
  // For Clerk, tokens are managed externally, so this might not be needed
  
  console.log('✅ Token cleanup completed (no action needed with Clerk)');
}

/**
 * Clean up stale cache entries
 */
async function cleanupStaleCache(): Promise<void> {
  console.log('🧹 Cleaning up stale cache entries...');

  try {
    // Clean up any temporary cache keys that might have been orphaned
    const patterns = [
      'temp:*',
      'session:expired:*',
    ];

    let totalDeleted = 0;
    for (const pattern of patterns) {
      const deleted = await cacheDeletePattern(pattern);
      totalDeleted += deleted;
    }

    console.log(`✅ Cleaned up ${totalDeleted} stale cache entries`);
  } catch (error) {
    console.error('❌ Error cleaning up stale cache:', error);
    throw error;
  }
}

/**
 * Initialize the cleanup worker
 */
export function initCleanupWorker(): void {
  createWorker<CleanupJobData>(
    QueueNames.CLEANUP,
    processCleanupJob,
    {
      concurrency: 1, // Only process one cleanup job at a time
    }
  );

  console.log('✅ Cleanup worker initialized');
}

