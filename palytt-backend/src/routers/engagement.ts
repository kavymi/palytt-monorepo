//
//  engagement.ts
//  Palytt Backend
//
//  Router for engagement-related notification triggers and stats
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import { router, protectedProcedure } from '../trpc.js';
import {
  getStreakStatus,
  processStreakReminders,
  updateStreakOnPost,
} from '../services/streakNotificationService.js';
import {
  getWeeklyEngagementSummary,
  sendWeeklyRecapNotification,
} from '../services/socialProofNotificationService.js';

export const engagementRouter = router({
  /**
   * Get current user's streak status
   */
  getStreakStatus: protectedProcedure
    .query(async ({ ctx }) => {
      const status = await getStreakStatus(ctx.user.clerkId);
      return status || {
        currentStreak: 0,
        longestStreak: 0,
        lastPostDate: null,
        isAtRisk: false,
        hoursUntilStreakLoss: 0,
      };
    }),

  /**
   * Update streak when user creates a post (called internally)
   */
  updateStreakOnPost: protectedProcedure
    .mutation(async ({ ctx }) => {
      return await updateStreakOnPost(ctx.user.clerkId);
    }),

  /**
   * Process streak reminders for all users (admin/cron endpoint)
   */
  processStreakReminders: protectedProcedure
    .mutation(async () => {
      return await processStreakReminders();
    }),

  /**
   * Get weekly engagement summary for current user
   */
  getWeeklyEngagementSummary: protectedProcedure
    .query(async ({ ctx }) => {
      return await getWeeklyEngagementSummary(ctx.user.clerkId);
    }),

  /**
   * Trigger weekly recap notification for current user (for testing)
   */
  sendWeeklyRecap: protectedProcedure
    .mutation(async ({ ctx }) => {
      await sendWeeklyRecapNotification(ctx.user.clerkId);
      return { success: true };
    }),

  /**
   * Get engagement stats for dashboard
   */
  getEngagementDashboard: protectedProcedure
    .query(async ({ ctx }) => {
      const [streakStatus, weeklySummary] = await Promise.all([
        getStreakStatus(ctx.user.clerkId),
        getWeeklyEngagementSummary(ctx.user.clerkId),
      ]);

      return {
        streak: streakStatus,
        weekly: weeklySummary,
      };
    }),
});

