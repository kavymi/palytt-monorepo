import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

/**
 * Live Notifications Functions
 * 
 * Real-time notification delivery:
 * - Push notifications to connected clients instantly
 * - Sync with PostgreSQL notifications for persistence
 * - Mark as read in real-time
 */

// ============================================
// MUTATIONS
// ============================================

/**
 * Push a new notification to a user
 * This provides instant delivery to connected clients
 * The backend should also save to PostgreSQL for persistence
 */
export const pushNotification = mutation({
  args: {
    recipientClerkId: v.string(),
    senderClerkId: v.optional(v.string()),
    senderName: v.optional(v.string()),
    senderProfileImage: v.optional(v.string()),
    type: v.union(
      v.literal("POST_LIKE"),
      v.literal("COMMENT"),
      v.literal("COMMENT_LIKE"),
      v.literal("FOLLOW"),
      v.literal("FRIEND_REQUEST"),
      v.literal("FRIEND_ACCEPTED"),
      v.literal("FRIEND_POST"),
      v.literal("MESSAGE"),
      v.literal("POST_MENTION"),
      v.literal("GENERAL")
    ),
    title: v.string(),
    message: v.string(),
    metadata: v.optional(v.object({
      postId: v.optional(v.string()),
      commentId: v.optional(v.string()),
      chatroomId: v.optional(v.string()),
      friendRequestId: v.optional(v.string()),
      userId: v.optional(v.string()),
    })),
    postgresId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    const notificationId = await ctx.db.insert("liveNotifications", {
      recipientClerkId: args.recipientClerkId,
      senderClerkId: args.senderClerkId,
      senderName: args.senderName,
      senderProfileImage: args.senderProfileImage,
      type: args.type,
      title: args.title,
      message: args.message,
      metadata: args.metadata,
      isRead: false,
      postgresId: args.postgresId,
      createdAt: now,
    });
    
    return { success: true, notificationId };
  },
});

/**
 * Mark a notification as read
 */
export const markAsRead = mutation({
  args: {
    notificationId: v.id("liveNotifications"),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.notificationId, {
      isRead: true,
    });
    return { success: true };
  },
});

/**
 * Mark multiple notifications as read
 */
export const markMultipleAsRead = mutation({
  args: {
    notificationIds: v.array(v.id("liveNotifications")),
  },
  handler: async (ctx, args) => {
    for (const id of args.notificationIds) {
      await ctx.db.patch(id, { isRead: true });
    }
    return { success: true, count: args.notificationIds.length };
  },
});

/**
 * Mark all notifications as read for a user
 */
export const markAllAsRead = mutation({
  args: {
    clerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const unread = await ctx.db
      .query("liveNotifications")
      .withIndex("by_recipient_unread", (q) => 
        q.eq("recipientClerkId", args.clerkId).eq("isRead", false)
      )
      .collect();
    
    for (const notification of unread) {
      await ctx.db.patch(notification._id, { isRead: true });
    }
    
    return { success: true, count: unread.length };
  },
});

/**
 * Delete a notification
 */
export const deleteNotification = mutation({
  args: {
    notificationId: v.id("liveNotifications"),
  },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.notificationId);
    return { success: true };
  },
});

/**
 * Clear all notifications for a user
 */
export const clearAllNotifications = mutation({
  args: {
    clerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const notifications = await ctx.db
      .query("liveNotifications")
      .withIndex("by_recipient", (q) => q.eq("recipientClerkId", args.clerkId))
      .collect();
    
    for (const notification of notifications) {
      await ctx.db.delete(notification._id);
    }
    
    return { success: true, count: notifications.length };
  },
});

/**
 * Cleanup old notifications (older than 30 days)
 * Should be called by a scheduled function
 */
export const cleanupOldNotifications = mutation({
  args: {},
  handler: async (ctx) => {
    const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
    
    const old = await ctx.db
      .query("liveNotifications")
      .filter((q) => q.lt(q.field("createdAt"), thirtyDaysAgo))
      .collect();
    
    for (const notification of old) {
      await ctx.db.delete(notification._id);
    }
    
    return { deletedCount: old.length };
  },
});

// ============================================
// QUERIES
// ============================================

/**
 * Subscribe to notifications for a user
 * This is a reactive query - UI updates in real-time when new notifications arrive
 */
export const subscribeToNotifications = query({
  args: {
    clerkId: v.string(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 50;
    
    const notifications = await ctx.db
      .query("liveNotifications")
      .withIndex("by_recipient", (q) => q.eq("recipientClerkId", args.clerkId))
      .order("desc")
      .take(limit);
    
    return notifications;
  },
});

/**
 * Get unread notifications only
 */
export const getUnreadNotifications = query({
  args: {
    clerkId: v.string(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 50;
    
    const notifications = await ctx.db
      .query("liveNotifications")
      .withIndex("by_recipient_unread", (q) => 
        q.eq("recipientClerkId", args.clerkId).eq("isRead", false)
      )
      .order("desc")
      .take(limit);
    
    return notifications;
  },
});

/**
 * Get unread notification count
 * Use this for badge counts
 */
export const getUnreadCount = query({
  args: {
    clerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const unread = await ctx.db
      .query("liveNotifications")
      .withIndex("by_recipient_unread", (q) => 
        q.eq("recipientClerkId", args.clerkId).eq("isRead", false)
      )
      .collect();
    
    return { count: unread.length };
  },
});

/**
 * Get notifications by type
 */
export const getNotificationsByType = query({
  args: {
    clerkId: v.string(),
    type: v.union(
      v.literal("POST_LIKE"),
      v.literal("COMMENT"),
      v.literal("COMMENT_LIKE"),
      v.literal("FOLLOW"),
      v.literal("FRIEND_REQUEST"),
      v.literal("FRIEND_ACCEPTED"),
      v.literal("FRIEND_POST"),
      v.literal("MESSAGE"),
      v.literal("POST_MENTION"),
      v.literal("GENERAL")
    ),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 50;
    
    // Get all notifications for user, then filter by type
    const allNotifications = await ctx.db
      .query("liveNotifications")
      .withIndex("by_recipient", (q) => q.eq("recipientClerkId", args.clerkId))
      .order("desc")
      .collect();
    
    const filtered = allNotifications
      .filter((n) => n.type === args.type)
      .slice(0, limit);
    
    return filtered;
  },
});

/**
 * Check if notification exists by PostgreSQL ID
 * Used for sync/deduplication
 */
export const getByPostgresId = query({
  args: {
    postgresId: v.string(),
  },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("liveNotifications")
      .withIndex("by_postgres_id", (q) => q.eq("postgresId", args.postgresId))
      .first();
  },
});


