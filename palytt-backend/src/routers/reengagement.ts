//
//  reengagement.ts
//  Palytt Backend
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import { z } from 'zod';
import { router, publicProcedure, protectedProcedure } from '../trpc.js';
import {
  processReengagementNotifications,
  getReengagementStats,
  checkAndSendReengagement,
} from '../services/reengagementService.js';

export const reengagementRouter = router({
  /**
   * Process re-engagement notifications for all inactive users
   * This should be called by a scheduled job (e.g., every hour via cron)
   * 
   * For security, you could add an API key check here in production
   */
  processAll: publicProcedure
    .input(z.object({
      // Optional API key for securing the cron endpoint
      cronSecret: z.string().optional(),
    }).optional())
    .mutation(async ({ input }) => {
      // In production, verify the cron secret
      const expectedSecret = process.env.CRON_SECRET;
      if (expectedSecret && input?.cronSecret !== expectedSecret) {
        // Allow if no secret is configured (development) or if it matches
        if (input?.cronSecret) {
          throw new Error('Invalid cron secret');
        }
      }

      const result = await processReengagementNotifications();
      return {
        success: true,
        ...result,
      };
    }),

  /**
   * Get re-engagement statistics
   * Useful for monitoring user activity levels
   */
  getStats: protectedProcedure
    .query(async () => {
      const stats = await getReengagementStats();
      return stats;
    }),

  /**
   * Manually trigger re-engagement check for a specific user
   * Useful for testing or manual intervention
   */
  checkUser: protectedProcedure
    .input(z.object({
      clerkId: z.string(),
    }))
    .mutation(async ({ input }) => {
      const sent = await checkAndSendReengagement(input.clerkId);
      return {
        success: true,
        notificationSent: sent,
      };
    }),
});

