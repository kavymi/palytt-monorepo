//
//  queue.service.ts
//  Palytt Backend
//
//  BullMQ job queue management for background task processing
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import { Queue, Worker, Job, QueueEvents } from 'bullmq';
import { isRedisAvailable } from '../cache/redis.js';

// Redis connection for BullMQ
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

// Parse Redis URL for BullMQ connection
function getRedisConnection() {
  const url = new URL(REDIS_URL);
  return {
    host: url.hostname,
    port: parseInt(url.port) || 6379,
    password: url.password || undefined,
  };
}

// Queue names
export const QueueNames = {
  NOTIFICATIONS: 'notifications',
  ANALYTICS: 'analytics',
  CLEANUP: 'cleanup',
  EMAIL: 'email',
} as const;

export type QueueName = (typeof QueueNames)[keyof typeof QueueNames];

// Job types
export interface NotificationJobData {
  type: 'push' | 'in_app' | 'batch';
  recipientClerkId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  badge?: number;
}

export interface AnalyticsJobData {
  type: 'engagement' | 'user_activity' | 'post_view';
  userId: string;
  eventType: string;
  eventData: Record<string, unknown>;
  timestamp: number;
}

export interface CleanupJobData {
  type: 'expired_tokens' | 'old_notifications' | 'stale_cache';
  olderThanDays?: number;
}

export interface EmailJobData {
  to: string;
  subject: string;
  template: string;
  data: Record<string, unknown>;
}

// Store queues and workers
const queues = new Map<QueueName, Queue>();
const workers = new Map<QueueName, Worker>();
const queueEvents = new Map<QueueName, QueueEvents>();

/**
 * Create or get a queue
 */
export function getQueue<T>(name: QueueName): Queue<T> {
  if (queues.has(name)) {
    return queues.get(name) as Queue<T>;
  }

  const queue = new Queue<T>(name, {
    connection: getRedisConnection(),
    defaultJobOptions: {
      attempts: 3,
      backoff: {
        type: 'exponential',
        delay: 1000,
      },
      removeOnComplete: {
        count: 1000, // Keep last 1000 completed jobs
        age: 24 * 3600, // Keep for 24 hours
      },
      removeOnFail: {
        count: 5000, // Keep last 5000 failed jobs
        age: 7 * 24 * 3600, // Keep for 7 days
      },
    },
  });

  queues.set(name, queue);
  return queue;
}

/**
 * Create a worker for a queue
 */
export function createWorker<T>(
  name: QueueName,
  processor: (job: Job<T>) => Promise<void>,
  options?: {
    concurrency?: number;
    limiter?: {
      max: number;
      duration: number;
    };
  }
): Worker<T> {
  if (workers.has(name)) {
    console.warn(`⚠️ Worker for ${name} already exists`);
    return workers.get(name) as Worker<T>;
  }

  const worker = new Worker<T>(name, processor, {
    connection: getRedisConnection(),
    concurrency: options?.concurrency ?? 5,
    limiter: options?.limiter,
  });

  // Event handlers
  worker.on('completed', (job) => {
    console.log(`✅ Job ${job.id} completed in queue ${name}`);
  });

  worker.on('failed', (job, err) => {
    console.error(`❌ Job ${job?.id} failed in queue ${name}:`, err.message);
  });

  worker.on('error', (err) => {
    console.error(`❌ Worker error in queue ${name}:`, err);
  });

  workers.set(name, worker);
  return worker;
}

/**
 * Add a job to a queue
 */
export async function addJob<T>(
  queueName: QueueName,
  data: T,
  options?: {
    delay?: number;
    priority?: number;
    jobId?: string;
    repeat?: {
      pattern?: string; // Cron pattern
      every?: number; // Repeat every X milliseconds
      limit?: number; // Maximum number of times to repeat
    };
  }
): Promise<Job<T> | null> {
  if (!isRedisAvailable()) {
    console.warn(`⚠️ Redis not available, skipping job for queue ${queueName}`);
    return null;
  }

  try {
    const queue = getQueue<T>(queueName);
    // Use type assertion for job name to satisfy BullMQ's strict typing
    const job = await (queue as Queue).add('job', data, {
      delay: options?.delay,
      priority: options?.priority,
      jobId: options?.jobId,
      repeat: options?.repeat,
    });
    console.log(`📥 Job ${job.id} added to queue ${queueName}`);
    return job as Job<T>;
  } catch (error) {
    console.error(`❌ Failed to add job to queue ${queueName}:`, error);
    return null;
  }
}

/**
 * Add a notification job
 */
export async function addNotificationJob(
  data: NotificationJobData,
  options?: { delay?: number; priority?: number }
): Promise<Job<NotificationJobData> | null> {
  return addJob(QueueNames.NOTIFICATIONS, data, {
    ...options,
    priority: data.type === 'push' ? 1 : 10, // Push notifications have higher priority
  });
}

/**
 * Add an analytics job
 */
export async function addAnalyticsJob(
  data: AnalyticsJobData
): Promise<Job<AnalyticsJobData> | null> {
  return addJob(QueueNames.ANALYTICS, data, {
    priority: 100, // Low priority
  });
}

/**
 * Add a cleanup job
 */
export async function addCleanupJob(
  data: CleanupJobData,
  options?: { delay?: number }
): Promise<Job<CleanupJobData> | null> {
  return addJob(QueueNames.CLEANUP, data, options);
}

/**
 * Schedule recurring cleanup jobs
 */
export async function scheduleRecurringJobs(): Promise<void> {
  if (!isRedisAvailable()) {
    console.warn('⚠️ Redis not available, skipping recurring job scheduling');
    return;
  }

  try {
    // Clean up old notifications daily at 3 AM
    await addJob(
      QueueNames.CLEANUP,
      { type: 'old_notifications', olderThanDays: 30 } as CleanupJobData,
      {
        repeat: {
          pattern: '0 3 * * *', // Every day at 3 AM
        },
        jobId: 'cleanup-old-notifications',
      }
    );

    // Clean up stale cache every hour
    await addJob(
      QueueNames.CLEANUP,
      { type: 'stale_cache' } as CleanupJobData,
      {
        repeat: {
          pattern: '0 * * * *', // Every hour
        },
        jobId: 'cleanup-stale-cache',
      }
    );

    console.log('✅ Recurring jobs scheduled');
  } catch (error) {
    console.error('❌ Failed to schedule recurring jobs:', error);
  }
}

/**
 * Get queue statistics
 */
export async function getQueueStats(queueName: QueueName): Promise<{
  waiting: number;
  active: number;
  completed: number;
  failed: number;
  delayed: number;
}> {
  const queue = getQueue(queueName);
  const [waiting, active, completed, failed, delayed] = await Promise.all([
    queue.getWaitingCount(),
    queue.getActiveCount(),
    queue.getCompletedCount(),
    queue.getFailedCount(),
    queue.getDelayedCount(),
  ]);

  return { waiting, active, completed, failed, delayed };
}

/**
 * Get all queue statistics
 */
export async function getAllQueueStats(): Promise<
  Record<QueueName, { waiting: number; active: number; completed: number; failed: number; delayed: number }>
> {
  const stats: Record<string, { waiting: number; active: number; completed: number; failed: number; delayed: number }> = {};

  for (const name of Object.values(QueueNames)) {
    stats[name] = await getQueueStats(name);
  }

  return stats as Record<QueueName, { waiting: number; active: number; completed: number; failed: number; delayed: number }>;
}

/**
 * Pause a queue
 */
export async function pauseQueue(queueName: QueueName): Promise<void> {
  const queue = getQueue(queueName);
  await queue.pause();
  console.log(`⏸️ Queue ${queueName} paused`);
}

/**
 * Resume a queue
 */
export async function resumeQueue(queueName: QueueName): Promise<void> {
  const queue = getQueue(queueName);
  await queue.resume();
  console.log(`▶️ Queue ${queueName} resumed`);
}

/**
 * Clean completed/failed jobs from a queue
 */
export async function cleanQueue(
  queueName: QueueName,
  grace: number = 3600000, // 1 hour default
  status: 'completed' | 'failed' | 'delayed' | 'wait' = 'completed'
): Promise<string[]> {
  const queue = getQueue(queueName);
  const cleaned = await queue.clean(grace, 1000, status);
  console.log(`🧹 Cleaned ${cleaned.length} ${status} jobs from queue ${queueName}`);
  return cleaned;
}

/**
 * Close all queues and workers gracefully
 */
export async function closeAllQueues(): Promise<void> {
  console.log('🔌 Closing all job queues...');

  // Close workers first
  for (const [name, worker] of workers) {
    try {
      await worker.close();
      console.log(`✅ Worker ${name} closed`);
    } catch (error) {
      console.error(`❌ Error closing worker ${name}:`, error);
    }
  }

  // Close queue events
  for (const [name, events] of queueEvents) {
    try {
      await events.close();
      console.log(`✅ Queue events ${name} closed`);
    } catch (error) {
      console.error(`❌ Error closing queue events ${name}:`, error);
    }
  }

  // Close queues
  for (const [name, queue] of queues) {
    try {
      await queue.close();
      console.log(`✅ Queue ${name} closed`);
    } catch (error) {
      console.error(`❌ Error closing queue ${name}:`, error);
    }
  }

  workers.clear();
  queueEvents.clear();
  queues.clear();

  console.log('✅ All job queues closed');
}

