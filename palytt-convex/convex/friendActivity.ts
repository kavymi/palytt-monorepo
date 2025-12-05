import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

/**
 * Friend Activity Feed Functions
 * 
 * Real-time activity feed showing friend actions:
 * - Posts, likes, comments from friends
 * - Activity auto-expires after 24 hours
 * - Real-time updates to activity feed
 */

// Constants
const ACTIVITY_EXPIRY_MS = 24 * 60 * 60 * 1000; // 24 hours

// ============================================
// MUTATIONS
// ============================================

/**
 * Record a friend activity
 * Call this when a user performs an action (post, like, comment, etc.)
 */
export const recordActivity = mutation({
  args: {
    actorClerkId: v.string(),
    actorName: v.optional(v.string()),
    actorProfileImage: v.optional(v.string()),
    activityType: v.union(
      v.literal("posted"),
      v.literal("liked_post"),
      v.literal("commented"),
      v.literal("followed"),
      v.literal("joined_gathering"),
      v.literal("shared_place")
    ),
    targetId: v.optional(v.string()),
    targetType: v.optional(v.union(
      v.literal("post"),
      v.literal("comment"),
      v.literal("user"),
      v.literal("gathering"),
      v.literal("place")
    )),
    targetPreview: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const expiresAt = now + ACTIVITY_EXPIRY_MS;
    
    const activityId = await ctx.db.insert("friendActivity", {
      actorClerkId: args.actorClerkId,
      actorName: args.actorName,
      actorProfileImage: args.actorProfileImage,
      activityType: args.activityType,
      targetId: args.targetId,
      targetType: args.targetType,
      targetPreview: args.targetPreview,
      createdAt: now,
      expiresAt,
    });
    
    return { success: true, activityId };
  },
});

/**
 * Delete an activity
 * Use this when the underlying action is undone (unlike, delete post, etc.)
 */
export const deleteActivity = mutation({
  args: {
    activityId: v.id("friendActivity"),
  },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.activityId);
    return { success: true };
  },
});

/**
 * Delete activity by actor and target
 * Use this when undoing an action (e.g., unliking a post)
 */
export const deleteActivityByTarget = mutation({
  args: {
    actorClerkId: v.string(),
    activityType: v.union(
      v.literal("posted"),
      v.literal("liked_post"),
      v.literal("commented"),
      v.literal("followed"),
      v.literal("joined_gathering"),
      v.literal("shared_place")
    ),
    targetId: v.string(),
  },
  handler: async (ctx, args) => {
    const activities = await ctx.db
      .query("friendActivity")
      .withIndex("by_actor", (q) => q.eq("actorClerkId", args.actorClerkId))
      .filter((q) => 
        q.and(
          q.eq(q.field("activityType"), args.activityType),
          q.eq(q.field("targetId"), args.targetId)
        )
      )
      .collect();
    
    for (const activity of activities) {
      await ctx.db.delete(activity._id);
    }
    
    return { success: true, deletedCount: activities.length };
  },
});

/**
 * Cleanup expired activities
 * Should be called by a scheduled function
 */
export const cleanupExpiredActivities = mutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    
    const expired = await ctx.db
      .query("friendActivity")
      .filter((q) => q.lt(q.field("expiresAt"), now))
      .collect();
    
    for (const activity of expired) {
      await ctx.db.delete(activity._id);
    }
    
    return { deletedCount: expired.length };
  },
});

// ============================================
// QUERIES
// ============================================

/**
 * Get activity feed for friends
 * Pass the list of friend Clerk IDs to see their activity
 */
export const getFriendActivityFeed = query({
  args: {
    friendClerkIds: v.array(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 50;
    const now = Date.now();
    
    // Collect activities from all friends
    const allActivities = [];
    
    for (const clerkId of args.friendClerkIds) {
      const activities = await ctx.db
        .query("friendActivity")
        .withIndex("by_actor", (q) => q.eq("actorClerkId", clerkId))
        .filter((q) => q.gt(q.field("expiresAt"), now))
        .collect();
      
      allActivities.push(...activities);
    }
    
    // Sort by creation time (newest first) and limit
    const sorted = allActivities
      .sort((a, b) => b.createdAt - a.createdAt)
      .slice(0, limit);
    
    return sorted;
  },
});

/**
 * Get a user's recent activity
 * Use this for profile views
 */
export const getUserActivity = query({
  args: {
    clerkId: v.string(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 20;
    const now = Date.now();
    
    const activities = await ctx.db
      .query("friendActivity")
      .withIndex("by_actor", (q) => q.eq("actorClerkId", args.clerkId))
      .filter((q) => q.gt(q.field("expiresAt"), now))
      .order("desc")
      .take(limit);
    
    return activities;
  },
});

/**
 * Get activity by type
 * E.g., get all recent posts from friends
 */
export const getActivityByType = query({
  args: {
    friendClerkIds: v.array(v.string()),
    activityType: v.union(
      v.literal("posted"),
      v.literal("liked_post"),
      v.literal("commented"),
      v.literal("followed"),
      v.literal("joined_gathering"),
      v.literal("shared_place")
    ),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 50;
    const now = Date.now();
    
    const allActivities = [];
    
    for (const clerkId of args.friendClerkIds) {
      const activities = await ctx.db
        .query("friendActivity")
        .withIndex("by_actor", (q) => q.eq("actorClerkId", clerkId))
        .filter((q) => 
          q.and(
            q.eq(q.field("activityType"), args.activityType),
            q.gt(q.field("expiresAt"), now)
          )
        )
        .collect();
      
      allActivities.push(...activities);
    }
    
    const sorted = allActivities
      .sort((a, b) => b.createdAt - a.createdAt)
      .slice(0, limit);
    
    return sorted;
  },
});

/**
 * Get activity count for a user (stats)
 */
export const getActivityCount = query({
  args: {
    clerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    const activities = await ctx.db
      .query("friendActivity")
      .withIndex("by_actor", (q) => q.eq("actorClerkId", args.clerkId))
      .filter((q) => q.gt(q.field("expiresAt"), now))
      .collect();
    
    // Group by type
    const counts: Record<string, number> = {};
    for (const activity of activities) {
      counts[activity.activityType] = (counts[activity.activityType] || 0) + 1;
    }
    
    return {
      total: activities.length,
      byType: counts,
    };
  },
});

/**
 * Check if there's new activity since a timestamp
 * Use this for "New activity" indicator
 */
export const hasNewActivity = query({
  args: {
    friendClerkIds: v.array(v.string()),
    sinceTimestamp: v.number(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    for (const clerkId of args.friendClerkIds) {
      const activity = await ctx.db
        .query("friendActivity")
        .withIndex("by_actor", (q) => q.eq("actorClerkId", clerkId))
        .filter((q) => 
          q.and(
            q.gt(q.field("createdAt"), args.sinceTimestamp),
            q.gt(q.field("expiresAt"), now)
          )
        )
        .first();
      
      if (activity) {
        return { hasNew: true };
      }
    }
    
    return { hasNew: false };
  },
});

