import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

/**
 * Typing Indicator Functions
 * 
 * Real-time typing status in chatrooms:
 * - Start typing (creates/updates indicator)
 * - Stop typing (removes indicator)
 * - Auto-expire after 5 seconds of inactivity
 * - Subscribe to typing in a chatroom
 */

// Constants
const TYPING_EXPIRY_MS = 5000; // 5 seconds

// ============================================
// MUTATIONS
// ============================================

/**
 * Start or update typing indicator
 * Call this when user starts typing or continues typing
 * The indicator auto-expires after 5 seconds
 */
export const startTyping = mutation({
  args: {
    clerkId: v.string(),
    chatroomId: v.string(),
    userName: v.optional(v.string()),
    userProfileImage: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const expiresAt = now + TYPING_EXPIRY_MS;
    
    // Check if typing indicator already exists
    const existing = await ctx.db
      .query("typingIndicators")
      .withIndex("by_chatroom_and_clerk", (q) => 
        q.eq("chatroomId", args.chatroomId).eq("clerkId", args.clerkId)
      )
      .first();
    
    if (existing) {
      // Update existing indicator
      await ctx.db.patch(existing._id, {
        startedAt: now,
        expiresAt,
        userName: args.userName,
        userProfileImage: args.userProfileImage,
      });
      return { success: true, action: "updated" };
    } else {
      // Create new indicator
      await ctx.db.insert("typingIndicators", {
        clerkId: args.clerkId,
        chatroomId: args.chatroomId,
        userName: args.userName,
        userProfileImage: args.userProfileImage,
        startedAt: now,
        expiresAt,
      });
      return { success: true, action: "created" };
    }
  },
});

/**
 * Stop typing indicator
 * Call this when user stops typing (e.g., sends message, clears text)
 */
export const stopTyping = mutation({
  args: {
    clerkId: v.string(),
    chatroomId: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("typingIndicators")
      .withIndex("by_chatroom_and_clerk", (q) => 
        q.eq("chatroomId", args.chatroomId).eq("clerkId", args.clerkId)
      )
      .first();
    
    if (existing) {
      await ctx.db.delete(existing._id);
      return { success: true, deleted: true };
    }
    return { success: true, deleted: false };
  },
});

/**
 * Stop all typing indicators for a user
 * Call this when user goes offline or leaves all chatrooms
 */
export const stopAllTyping = mutation({
  args: {
    clerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const indicators = await ctx.db
      .query("typingIndicators")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", args.clerkId))
      .collect();
    
    for (const indicator of indicators) {
      await ctx.db.delete(indicator._id);
    }
    
    return { success: true, deletedCount: indicators.length };
  },
});

/**
 * Cleanup expired typing indicators
 * Should be called by a scheduled function every few seconds
 */
export const cleanupExpiredIndicators = mutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    
    // Find all expired indicators
    const expired = await ctx.db
      .query("typingIndicators")
      .filter((q) => q.lt(q.field("expiresAt"), now))
      .collect();
    
    // Delete them
    for (const indicator of expired) {
      await ctx.db.delete(indicator._id);
    }
    
    return { deletedCount: expired.length };
  },
});

// ============================================
// QUERIES
// ============================================

/**
 * Get all users currently typing in a chatroom
 * This is a reactive query - UI will update in real-time
 */
export const getTypingInChatroom = query({
  args: {
    chatroomId: v.string(),
    excludeClerkId: v.optional(v.string()), // Exclude current user
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    const indicators = await ctx.db
      .query("typingIndicators")
      .withIndex("by_chatroom", (q) => q.eq("chatroomId", args.chatroomId))
      .collect();
    
    // Filter out expired and excluded users
    const activeTyping = indicators
      .filter((indicator) => {
        // Filter out expired
        if (indicator.expiresAt < now) return false;
        // Filter out current user if specified
        if (args.excludeClerkId && indicator.clerkId === args.excludeClerkId) return false;
        return true;
      })
      .map((indicator) => ({
        clerkId: indicator.clerkId,
        userName: indicator.userName,
        userProfileImage: indicator.userProfileImage,
        startedAt: indicator.startedAt,
      }));
    
    return activeTyping;
  },
});

/**
 * Get typing indicators for multiple chatrooms at once
 * Useful for the messages list view
 */
export const getTypingInMultipleChatrooms = query({
  args: {
    chatroomIds: v.array(v.string()),
    excludeClerkId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const result: Record<string, Array<{
      clerkId: string;
      userName?: string;
      userProfileImage?: string;
    }>> = {};
    
    // Initialize empty arrays for all chatrooms
    for (const chatroomId of args.chatroomIds) {
      result[chatroomId] = [];
    }
    
    // Query each chatroom
    for (const chatroomId of args.chatroomIds) {
      const indicators = await ctx.db
        .query("typingIndicators")
        .withIndex("by_chatroom", (q) => q.eq("chatroomId", chatroomId))
        .collect();
      
      result[chatroomId] = indicators
        .filter((indicator) => {
          if (indicator.expiresAt < now) return false;
          if (args.excludeClerkId && indicator.clerkId === args.excludeClerkId) return false;
          return true;
        })
        .map((indicator) => ({
          clerkId: indicator.clerkId,
          userName: indicator.userName,
          userProfileImage: indicator.userProfileImage,
        }));
    }
    
    return result;
  },
});

/**
 * Check if a specific user is typing in a chatroom
 */
export const isUserTyping = query({
  args: {
    clerkId: v.string(),
    chatroomId: v.string(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    const indicator = await ctx.db
      .query("typingIndicators")
      .withIndex("by_chatroom_and_clerk", (q) => 
        q.eq("chatroomId", args.chatroomId).eq("clerkId", args.clerkId)
      )
      .first();
    
    if (!indicator) return false;
    
    // Check if expired
    return indicator.expiresAt > now;
  },
});

/**
 * Get count of users typing in a chatroom
 * Useful for showing "3 people are typing..."
 */
export const getTypingCount = query({
  args: {
    chatroomId: v.string(),
    excludeClerkId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    const indicators = await ctx.db
      .query("typingIndicators")
      .withIndex("by_chatroom", (q) => q.eq("chatroomId", args.chatroomId))
      .collect();
    
    const count = indicators.filter((indicator) => {
      if (indicator.expiresAt < now) return false;
      if (args.excludeClerkId && indicator.clerkId === args.excludeClerkId) return false;
      return true;
    }).length;
    
    return { count };
  },
});


