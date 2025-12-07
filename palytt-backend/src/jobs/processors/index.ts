//
//  index.ts
//  Palytt Backend
//
//  Initialize all job processors
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import { isRedisAvailable } from '../../cache/redis.js';
import { scheduleRecurringJobs } from '../queue.service.js';
import { initNotificationsWorker } from './notifications.processor.js';
import { initAnalyticsWorker } from './analytics.processor.js';
import { initCleanupWorker } from './cleanup.processor.js';

/**
 * Initialize all job processors
 * Call this on server startup after Redis is connected
 */
export async function initializeJobProcessors(): Promise<void> {
  if (!isRedisAvailable()) {
    console.warn('⚠️ Redis not available, skipping job processor initialization');
    return;
  }

  console.log('🚀 Initializing job processors...');

  try {
    // Initialize workers
    initNotificationsWorker();
    initAnalyticsWorker();
    initCleanupWorker();

    // Schedule recurring jobs
    await scheduleRecurringJobs();

    console.log('✅ All job processors initialized');
  } catch (error) {
    console.error('❌ Failed to initialize job processors:', error);
    // Don't throw - allow server to start without job processing
  }
}

// Re-export individual initializers for testing
export { initNotificationsWorker } from './notifications.processor.js';
export { initAnalyticsWorker } from './analytics.processor.js';
export { initCleanupWorker } from './cleanup.processor.js';

