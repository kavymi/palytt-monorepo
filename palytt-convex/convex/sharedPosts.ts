import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

/**
 * Shared Posts Functions
 * 
 * Post-only messaging between friends:
 * - Share posts with friends (no free-form text)
 * - Real-time delivery via Convex subscriptions
 * - Read receipts and unread counts
 */

// ============================================
// MUTATIONS
// ============================================

/**
 * Share a post with a friend
 * Creates a new shared post entry and optionally triggers a notification
 */
export const sharePost = mutation({
  args: {
    senderClerkId: v.string(),
    senderName: v.optional(v.string()),
    senderProfileImage: v.optional(v.string()),
    recipientClerkId: v.string(),
    postId: v.string(),
    postPreview: v.object({
      title: v.optional(v.string()),
      imageUrl: v.optional(v.string()),
      shopName: v.optional(v.string()),
      authorName: v.optional(v.string()),
      authorClerkId: v.optional(v.string()),
    }),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    // Create the shared post entry
    const sharedPostId = await ctx.db.insert("sharedPosts", {
      senderClerkId: args.senderClerkId,
      senderName: args.senderName,
      senderProfileImage: args.senderProfileImage,
      recipientClerkId: args.recipientClerkId,
      postId: args.postId,
      postPreview: args.postPreview,
      isRead: false,
      createdAt: now,
    });
    
    // Also create a live notification for the recipient
    await ctx.db.insert("liveNotifications", {
      recipientClerkId: args.recipientClerkId,
      senderClerkId: args.senderClerkId,
      senderName: args.senderName,
      senderProfileImage: args.senderProfileImage,
      type: "MESSAGE",
      title: "New Post Share",
      message: `${args.senderName ?? "Someone"} shared a post with you`,
      metadata: {
        postId: args.postId,
        userId: args.senderClerkId,
      },
      isRead: false,
      createdAt: now,
    });
    
    return { success: true, sharedPostId };
  },
});

/**
 * Mark a shared post as read
 */
export const markAsRead = mutation({
  args: {
    sharedPostId: v.id("sharedPosts"),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.sharedPostId, {
      isRead: true,
    });
    return { success: true };
  },
});

/**
 * Mark all shared posts from a specific sender as read
 * Used when opening a conversation with a friend
 */
export const markConversationAsRead = mutation({
  args: {
    recipientClerkId: v.string(),
    senderClerkId: v.string(),
  },
  handler: async (ctx, args) => {
    // Get all unread shared posts from this sender to this recipient
    const unreadPosts = await ctx.db
      .query("sharedPosts")
      .withIndex("by_recipient_unread", (q) => 
        q.eq("recipientClerkId", args.recipientClerkId).eq("isRead", false)
      )
      .filter((q) => q.eq(q.field("senderClerkId"), args.senderClerkId))
      .collect();
    
    // Mark all as read
    for (const post of unreadPosts) {
      await ctx.db.patch(post._id, { isRead: true });
    }
    
    return { success: true, count: unreadPosts.length };
  },
});

/**
 * Delete a shared post
 */
export const deleteSharedPost = mutation({
  args: {
    sharedPostId: v.id("sharedPosts"),
    clerkId: v.string(), // Must be sender or recipient
  },
  handler: async (ctx, args) => {
    const sharedPost = await ctx.db.get(args.sharedPostId);
    
    if (!sharedPost) {
      return { success: false, error: "Shared post not found" };
    }
    
    // Only sender or recipient can delete
    if (sharedPost.senderClerkId !== args.clerkId && 
        sharedPost.recipientClerkId !== args.clerkId) {
      return { success: false, error: "Not authorized" };
    }
    
    await ctx.db.delete(args.sharedPostId);
    return { success: true };
  },
});

// ============================================
// QUERIES
// ============================================

/**
 * Get shared posts between two users (conversation)
 * This is a reactive query - UI updates in real-time when new posts are shared
 */
export const getConversation = query({
  args: {
    userClerkId: v.string(),
    friendClerkId: v.string(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 50;
    
    // Get posts sent by user to friend
    const sentPosts = await ctx.db
      .query("sharedPosts")
      .withIndex("by_conversation", (q) => 
        q.eq("senderClerkId", args.userClerkId).eq("recipientClerkId", args.friendClerkId)
      )
      .collect();
    
    // Get posts sent by friend to user
    const receivedPosts = await ctx.db
      .query("sharedPosts")
      .withIndex("by_conversation", (q) => 
        q.eq("senderClerkId", args.friendClerkId).eq("recipientClerkId", args.userClerkId)
      )
      .collect();
    
    // Combine and sort by createdAt
    const allPosts = [...sentPosts, ...receivedPosts]
      .sort((a, b) => a.createdAt - b.createdAt)
      .slice(-limit);
    
    return allPosts;
  },
});

/**
 * Get all conversations for a user (list of friends with recent shared posts)
 * Returns the most recent shared post per friend
 */
export const getConversationsList = query({
  args: {
    clerkId: v.string(),
  },
  handler: async (ctx, args) => {
    // Get all posts where user is sender or recipient
    const sentPosts = await ctx.db
      .query("sharedPosts")
      .withIndex("by_sender", (q) => q.eq("senderClerkId", args.clerkId))
      .collect();
    
    const receivedPosts = await ctx.db
      .query("sharedPosts")
      .withIndex("by_recipient", (q) => q.eq("recipientClerkId", args.clerkId))
      .collect();
    
    // Group by friend and get most recent
    const conversationsMap = new Map<string, {
      friendClerkId: string;
      friendName: string | undefined;
      friendProfileImage: string | undefined;
      lastPost: typeof sentPosts[0];
      unreadCount: number;
    }>();
    
    // Process sent posts
    for (const post of sentPosts) {
      const friendId = post.recipientClerkId;
      const existing = conversationsMap.get(friendId);
      
      if (!existing || post.createdAt > existing.lastPost.createdAt) {
        conversationsMap.set(friendId, {
          friendClerkId: friendId,
          friendName: existing?.friendName, // Will be filled by received posts
          friendProfileImage: existing?.friendProfileImage,
          lastPost: post,
          unreadCount: existing?.unreadCount ?? 0,
        });
      }
    }
    
    // Process received posts
    for (const post of receivedPosts) {
      const friendId = post.senderClerkId;
      const existing = conversationsMap.get(friendId);
      
      const unreadIncrement = post.isRead ? 0 : 1;
      
      if (!existing || post.createdAt > existing.lastPost.createdAt) {
        conversationsMap.set(friendId, {
          friendClerkId: friendId,
          friendName: post.senderName,
          friendProfileImage: post.senderProfileImage,
          lastPost: post,
          unreadCount: (existing?.unreadCount ?? 0) + unreadIncrement,
        });
      } else {
        // Update unread count even if this isn't the latest post
        existing.unreadCount += unreadIncrement;
      }
    }
    
    // Convert to array and sort by most recent
    const conversations = Array.from(conversationsMap.values())
      .sort((a, b) => b.lastPost.createdAt - a.lastPost.createdAt);
    
    return conversations;
  },
});

/**
 * Get unread count for a user (total unread shared posts)
 */
export const getUnreadCount = query({
  args: {
    clerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const unread = await ctx.db
      .query("sharedPosts")
      .withIndex("by_recipient_unread", (q) => 
        q.eq("recipientClerkId", args.clerkId).eq("isRead", false)
      )
      .collect();
    
    return { count: unread.length };
  },
});

/**
 * Get unread count from a specific friend
 */
export const getUnreadCountFromFriend = query({
  args: {
    recipientClerkId: v.string(),
    senderClerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const unread = await ctx.db
      .query("sharedPosts")
      .withIndex("by_recipient_unread", (q) => 
        q.eq("recipientClerkId", args.recipientClerkId).eq("isRead", false)
      )
      .filter((q) => q.eq(q.field("senderClerkId"), args.senderClerkId))
      .collect();
    
    return { count: unread.length };
  },
});

/**
 * Check if a specific post has been shared with a friend
 */
export const hasSharedPost = query({
  args: {
    senderClerkId: v.string(),
    recipientClerkId: v.string(),
    postId: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("sharedPosts")
      .withIndex("by_conversation", (q) => 
        q.eq("senderClerkId", args.senderClerkId).eq("recipientClerkId", args.recipientClerkId)
      )
      .filter((q) => q.eq(q.field("postId"), args.postId))
      .first();
    
    return { hasShared: existing !== null };
  },
});

