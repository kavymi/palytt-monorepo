import { z } from 'zod';
import { router, protectedProcedure } from '../trpc.js';
import { prisma, ensureUser } from '../db.js';
import { registerDeviceToken, unregisterDeviceToken } from '../services/pushNotificationService.js';

// Type for notification data JSON field
interface NotificationData {
  senderId?: string;
  postId?: string;
  commentId?: string;
  friendRequestId?: string;
  senderName?: string;
  [key: string]: any;
}

// Helper function to get user UUID from clerkId
async function getUserIdFromClerkId(clerkId: string): Promise<string | null> {
  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { id: true },
  });
  return user?.id || null;
}

// Helper function to get user UUID, creating user if needed
async function ensureUserIdFromClerkId(clerkId: string): Promise<string> {
  const user = await ensureUser(clerkId, `${clerkId}@clerk.local`);
  return user.id;
}

export const notificationsRouter = router({
  // Get notifications for the current user
  getNotifications: protectedProcedure
    .input(z.object({
      limit: z.number().min(1).max(50).default(20),
      cursor: z.string().optional(),
      type: z.enum(['POST_LIKE', 'COMMENT', 'COMMENT_LIKE', 'FOLLOW', 'FRIEND_REQUEST', 'FRIEND_ACCEPTED', 'FRIEND_POST', 'MESSAGE', 'POST_MENTION', 'GENERAL']).optional(),
      types: z.array(z.enum(['POST_LIKE', 'COMMENT', 'COMMENT_LIKE', 'FOLLOW', 'FRIEND_REQUEST', 'FRIEND_ACCEPTED', 'FRIEND_POST', 'MESSAGE', 'POST_MENTION', 'GENERAL'])).optional(),
      unreadOnly: z.boolean().default(false),
    }))
    .query(async ({ input, ctx }) => {
      const { limit, cursor, type, types, unreadOnly } = input;
      const userClerkId = ctx.user.clerkId;

      // Get user UUID
      const userUUID = await getUserIdFromClerkId(userClerkId);

      if (!userUUID) {
        console.log(`⚠️ User not found in database for clerkId: ${userClerkId}`);
        return {
          notifications: [],
          nextCursor: undefined,
        };
      }

      const whereClause: any = {
        userId: userUUID,
      };

      // Support both single type and multiple types filtering
      if (types && types.length > 0) {
        whereClause.type = { in: types };
      } else if (type) {
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
      const transformedNotifications = notifications.map((notification: any) => {
        const data = notification.data as NotificationData | null;
        return {
          _id: notification.id,
          recipientId: userClerkId, // Use the clerkId, not the database ID
          senderId: data?.senderId || null,
          type: notification.type,
          title: notification.title,
          message: notification.message,
          metadata: {
            postId: data?.postId || null,
            commentId: data?.commentId || null,
            friendRequestId: data?.friendRequestId || null,
            userId: data?.senderId || null,
          },
          isRead: notification.read,
          createdAt: Math.floor(notification.createdAt.getTime()),
          updatedAt: Math.floor(notification.createdAt.getTime()),
          sender: data?.senderId ? {
            _id: data.senderId,
            clerkId: data.senderId,
            name: data.senderName || null,
            username: data.senderName || null,
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
        };
      });

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

      // Get user UUID
      const userUUID = await getUserIdFromClerkId(userClerkId);

      if (!userUUID) {
        throw new Error('User not found');
      }

      const whereClause: any = {
        userId: userUUID,
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
      userId: z.string(), // This is the UUID of the user to notify
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

      // Get user UUID
      const userUUID = await getUserIdFromClerkId(userClerkId);

      if (!userUUID) {
        // Return consistent response structure that matches iOS app expectations
        return { count: 0 };
      }

      const count = await prisma.notification.count({
        where: {
          userId: userUUID,
          read: false,
        },
      });

      // Return consistent response structure that matches iOS app expectations
      return { count: count };
    }),

  // Delete notifications
  deleteNotifications: protectedProcedure
    .input(z.object({
      notificationIds: z.array(z.string()),
    }))
    .mutation(async ({ input, ctx }) => {
      const { notificationIds } = input;
      const userClerkId = ctx.user.clerkId;

      // Get user UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);

      const deleted = await prisma.notification.deleteMany({
        where: {
          id: { in: notificationIds },
          userId: userUUID, // Ensure user can only delete their own notifications
        },
      });

      return { success: true, count: deleted.count };
    }),

  // Clear all notifications for user
  clearAll: protectedProcedure
    .mutation(async ({ ctx }) => {
      const userClerkId = ctx.user.clerkId;

      // Get user UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);

      const deleted = await prisma.notification.deleteMany({
        where: {
          userId: userUUID,
        },
      });

      return { success: true, count: deleted.count };
    }),

  // Get notification settings (placeholder for future notification preferences)
  getSettings: protectedProcedure
    .query(async () => {
      // Note: userId available from ctx.user.clerkId for future use

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
    .mutation(async ({ input }) => {
      // Note: userId available from ctx.user.clerkId for future database updates

      // For now, just return success
      // In the future, this would update user notification preferences in the database
      return { success: true, settings: input };
    }),

  // Mark all notifications as read
  markAllAsRead: protectedProcedure
    .mutation(async ({ ctx }) => {
      const userClerkId = ctx.user.clerkId;

      // Get user UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);

      const updated = await prisma.notification.updateMany({
        where: {
          userId: userUUID,
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
      const userClerkId = ctx.user.clerkId;

      // Get user UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);
      
      const since = new Date();
      since.setDate(since.getDate() - days);

      const notifications = await prisma.notification.findMany({
        where: {
          userId: userUUID,
          createdAt: {
            gte: since,
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
      });

      // Group by type
      const grouped = notifications.reduce((acc: any, notification: any) => {
        if (!acc[notification.type]) {
          acc[notification.type] = [];
        }
        acc[notification.type].push(notification);
        return acc;
      }, {} as Record<string, any[]>);

      return { grouped };
    }),

  // ============================================
  // DEVICE TOKEN MANAGEMENT (for Push Notifications)
  // ============================================

  // Register a device token for push notifications
  registerDeviceToken: protectedProcedure
    .input(z.object({
      token: z.string().min(1),
      platform: z.enum(['IOS', 'ANDROID', 'WEB']).default('IOS'),
    }))
    .mutation(async ({ input, ctx }) => {
      const { token, platform } = input;
      const userClerkId = ctx.user.clerkId;

      await registerDeviceToken(userClerkId, token, platform);

      return { success: true, message: 'Device token registered' };
    }),

  // Unregister a device token (e.g., on logout)
  unregisterDeviceToken: protectedProcedure
    .input(z.object({
      token: z.string().min(1),
    }))
    .mutation(async ({ input }) => {
      const { token } = input;

      await unregisterDeviceToken(token);

      return { success: true, message: 'Device token unregistered' };
    }),

  // Get all device tokens for the current user (for debugging)
  getDeviceTokens: protectedProcedure
    .query(async ({ ctx }) => {
      const userClerkId = ctx.user.clerkId;

      const user = await prisma.user.findUnique({
        where: { clerkId: userClerkId },
        select: { id: true },
      });

      if (!user) {
        return { tokens: [] };
      }

      const tokens = await prisma.deviceToken.findMany({
        where: { userId: user.id },
        select: {
          id: true,
          platform: true,
          isActive: true,
          lastUsedAt: true,
          createdAt: true,
        },
        orderBy: { lastUsedAt: 'desc' },
      });

      return { tokens };
    }),
});
