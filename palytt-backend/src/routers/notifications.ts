import { z } from 'zod';
import { router, publicProcedure, protectedProcedure } from '../trpc';
import { prisma } from '../db';

export const notificationsRouter = router({
  // Get notifications for the current user
  getNotifications: protectedProcedure
    .input(z.object({
      limit: z.number().min(1).max(50).default(20),
      cursor: z.string().optional(),
      type: z.enum(['POST_LIKE', 'COMMENT', 'COMMENT_LIKE', 'FOLLOW', 'FRIEND_REQUEST', 'FRIEND_ACCEPTED', 'FRIEND_POST', 'MESSAGE', 'POST_MENTION', 'GENERAL']).optional(),
      unreadOnly: z.boolean().default(false),
    }))
    .query(async ({ input, ctx }) => {
      const { limit, cursor, type, unreadOnly } = input;
      const userClerkId = ctx.user.clerkId;

      // Find user by clerkId to get their database ID
      const user = await prisma.user.findUnique({
        where: { clerkId: userClerkId },
        select: { id: true }
      });

      if (!user) {
        return {
          notifications: [],
          nextCursor: undefined,
        };
      }

      const whereClause: any = {
        userId: user.id,
      };

      if (type) {
        whereClause.type = type;
      }

      if (unreadOnly) {
        whereClause.read = false;
      }

      const notifications = await prisma.notification.findMany({
        where: whereClause,
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: {
          createdAt: 'desc',
        },
        include: {
          user: {
            select: {
              id: true,
              clerkId: true,
              name: true,
              username: true,
              profileImage: true,
            },
          },
        },
      });

      let nextCursor: typeof cursor | undefined = undefined;
      if (notifications.length > limit) {
        const nextItem = notifications.pop();
        nextCursor = nextItem!.id;
      }

      // Transform to match frontend BackendNotification structure
      const transformedNotifications = notifications.map(notification => ({
        _id: notification.id,
        recipientId: userClerkId, // Use the clerkId, not the database ID
        senderId: notification.data?.senderId || null,
        type: notification.type,
        title: notification.title,
        message: notification.message,
        metadata: {
          postId: notification.data?.postId || null,
          commentId: notification.data?.commentId || null,
          friendRequestId: notification.data?.friendRequestId || null,
          userId: notification.data?.senderId || null,
        },
        isRead: notification.read,
        createdAt: Math.floor(notification.createdAt.getTime()),
        updatedAt: Math.floor(notification.createdAt.getTime()),
        sender: notification.data?.senderId ? {
          _id: notification.data.senderId,
          clerkId: notification.data.senderId,
          name: notification.data.senderName || null,
          username: notification.data.senderName || null,
          email: null,
          bio: null,
          profileImage: null,
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
          isVerified: false,
          isActive: true,
          createdAt: Math.floor(notification.createdAt.getTime()),
          updatedAt: Math.floor(notification.createdAt.getTime()),
        } : null,
      }));

      return {
        notifications: transformedNotifications,
        nextCursor,
      };
    }),

  // Mark notifications as read
  markAsRead: protectedProcedure
    .input(z.object({
      notificationIds: z.array(z.string()).optional(), // If not provided, mark all as read
    }))
    .mutation(async ({ input, ctx }) => {
      const { notificationIds } = input;
      const userClerkId = ctx.user.clerkId;

      // Find user by clerkId to get their database ID
      const user = await prisma.user.findUnique({
        where: { clerkId: userClerkId },
        select: { id: true }
      });

      if (!user) {
        throw new Error('User not found');
      }

      const whereClause: any = {
        userId: user.id,
        read: false,
      };

      if (notificationIds && notificationIds.length > 0) {
        whereClause.id = { in: notificationIds };
      }

      const updated = await prisma.notification.updateMany({
        where: whereClause,
        data: {
          read: true,
        },
      });

      return { success: true, count: updated.count };
    }),

  // Create a new notification (typically called by other services)
  createNotification: protectedProcedure
    .input(z.object({
      userId: z.string(),
      type: z.enum(['POST_LIKE', 'COMMENT', 'COMMENT_LIKE', 'FOLLOW', 'FRIEND_REQUEST', 'FRIEND_ACCEPTED', 'FRIEND_POST', 'MESSAGE', 'POST_MENTION', 'GENERAL']),
      title: z.string(),
      message: z.string(),
      data: z.record(z.any()).optional(), // Additional data as JSON
    }))
    .mutation(async ({ input }) => {
      const { userId, type, title, message, data } = input;

      const notification = await prisma.notification.create({
        data: {
          userId,
          type,
          title,
          message,
          data: data || {},
        },
      });

      return notification;
    }),

  // Get unread notification count
  getUnreadCount: protectedProcedure
    .query(async ({ ctx }) => {
      const userClerkId = ctx.user.clerkId;

      // Find user by clerkId to get their database ID
      const user = await prisma.user.findUnique({
        where: { clerkId: userClerkId },
        select: { id: true }
      });

      if (!user) {
        return { unreadCount: 0 };
      }

      const count = await prisma.notification.count({
        where: {
          userId: user.id,
          read: false,
        },
      });

      return { unreadCount: count };
    }),

  // Delete notifications
  deleteNotifications: protectedProcedure
    .input(z.object({
      notificationIds: z.array(z.string()),
    }))
    .mutation(async ({ input, ctx }) => {
      const { notificationIds } = input;
      const userId = ctx.user.clerkId;

      const deleted = await prisma.notification.deleteMany({
        where: {
          id: { in: notificationIds },
          userId, // Ensure user can only delete their own notifications
        },
      });

      return { success: true, count: deleted.count };
    }),

  // Clear all notifications for user
  clearAll: protectedProcedure
    .mutation(async ({ ctx }) => {
      const userId = ctx.user.clerkId;

      const deleted = await prisma.notification.deleteMany({
        where: {
          userId,
        },
      });

      return { success: true, count: deleted.count };
    }),

  // Get notification settings (placeholder for future notification preferences)
  getSettings: protectedProcedure
    .query(async ({ ctx }) => {
      const userId = ctx.user.clerkId;

      // For now, return default settings
      // This can be expanded to include user-specific notification preferences
      return {
        emailNotifications: true,
        pushNotifications: true,
        likes: true,
        comments: true,
        follows: true,
        friendRequests: true,
        messages: true,
      };
    }),

  // Update notification settings (placeholder for future implementation)
  updateSettings: protectedProcedure
    .input(z.object({
      emailNotifications: z.boolean().optional(),
      pushNotifications: z.boolean().optional(),
      likes: z.boolean().optional(),
      comments: z.boolean().optional(),
      follows: z.boolean().optional(),
      friendRequests: z.boolean().optional(),
      messages: z.boolean().optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      const userId = ctx.user.clerkId;

      // For now, just return success
      // In the future, this would update user notification preferences in the database
      return { success: true, settings: input };
    }),

  // Mark all notifications as read
  markAllAsRead: protectedProcedure
    .mutation(async ({ ctx }) => {
      const userId = ctx.user.clerkId;

      const updated = await prisma.notification.updateMany({
        where: {
          userId,
          read: false,
        },
        data: {
          read: true,
        },
      });

      return { success: true, count: updated.count };
    }),

  // Get notifications grouped by type
  getNotificationsByType: protectedProcedure
    .input(z.object({
      days: z.number().min(1).max(30).default(7), // Last N days
    }))
    .query(async ({ input, ctx }) => {
      const { days } = input;
      const userId = ctx.user.clerkId;
      
      const since = new Date();
      since.setDate(since.getDate() - days);

      const notifications = await prisma.notification.findMany({
        where: {
          userId,
          createdAt: {
            gte: since,
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
      });

      // Group by type
      const grouped = notifications.reduce((acc, notification) => {
        if (!acc[notification.type]) {
          acc[notification.type] = [];
        }
        acc[notification.type].push(notification);
        return acc;
      }, {} as Record<string, any[]>);

      return { grouped };
    }),
});
