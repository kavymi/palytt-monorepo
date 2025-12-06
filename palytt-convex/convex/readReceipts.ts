import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

/**
 * Message Read Receipts Functions
 * 
 * Real-time read receipts for chat messages:
 * - Track when messages are read
 * - Enable "seen" indicators in real-time
 * - Batch operations for efficiency
 */

// ============================================
// MUTATIONS
// ============================================

/**
 * Mark a single message as read
 */
export const markMessageRead = mutation({
  args: {
    messageId: v.string(), // PostgreSQL message UUID
    chatroomId: v.string(), // PostgreSQL chatroom UUID
    readerClerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    // Check if already marked as read
    const existing = await ctx.db
      .query("messageReadReceipts")
      .withIndex("by_message", (q) => q.eq("messageId", args.messageId))
      .filter((q) => q.eq(q.field("readerClerkId"), args.readerClerkId))
      .first();
    
    if (existing) {
      // Already read, no action needed
      return { success: true, action: "already_read" };
    }
    
    // Create new read receipt
    await ctx.db.insert("messageReadReceipts", {
      messageId: args.messageId,
      chatroomId: args.chatroomId,
      readerClerkId: args.readerClerkId,
      readAt: now,
    });
    
    return { success: true, action: "marked_read" };
  },
});

/**
 * Mark multiple messages as read in a chatroom
 * Use this when user scrolls through messages
 */
export const markMessagesRead = mutation({
  args: {
    messageIds: v.array(v.string()),
    chatroomId: v.string(),
    readerClerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    let newCount = 0;
    
    for (const messageId of args.messageIds) {
      // Check if already read
      const existing = await ctx.db
        .query("messageReadReceipts")
        .withIndex("by_message", (q) => q.eq("messageId", messageId))
        .filter((q) => q.eq(q.field("readerClerkId"), args.readerClerkId))
        .first();
      
      if (!existing) {
        await ctx.db.insert("messageReadReceipts", {
          messageId,
          chatroomId: args.chatroomId,
          readerClerkId: args.readerClerkId,
          readAt: now,
        });
        newCount++;
      }
    }
    
    return { success: true, newlyMarked: newCount };
  },
});

/**
 * Mark all messages in a chatroom as read
 * Use this when user opens/focuses a chatroom
 */
export const markChatroomRead = mutation({
  args: {
    chatroomId: v.string(),
    readerClerkId: v.string(),
    messageIds: v.array(v.string()), // All message IDs in the chatroom
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    let newCount = 0;
    
    // Get existing receipts for this reader in this chatroom
    const existingReceipts = await ctx.db
      .query("messageReadReceipts")
      .withIndex("by_chatroom_and_reader", (q) => 
        q.eq("chatroomId", args.chatroomId).eq("readerClerkId", args.readerClerkId)
      )
      .collect();
    
    const existingMessageIds = new Set(existingReceipts.map((r) => r.messageId));
    
    // Mark unread messages as read
    for (const messageId of args.messageIds) {
      if (!existingMessageIds.has(messageId)) {
        await ctx.db.insert("messageReadReceipts", {
          messageId,
          chatroomId: args.chatroomId,
          readerClerkId: args.readerClerkId,
          readAt: now,
        });
        newCount++;
      }
    }
    
    return { success: true, newlyMarked: newCount };
  },
});

// ============================================
// QUERIES
// ============================================

/**
 * Get read receipts for a single message
 * Use this to show "Seen by X, Y, Z" under a message
 */
export const getMessageReadReceipts = query({
  args: {
    messageId: v.string(),
  },
  handler: async (ctx, args) => {
    const receipts = await ctx.db
      .query("messageReadReceipts")
      .withIndex("by_message", (q) => q.eq("messageId", args.messageId))
      .collect();
    
    return receipts.map((r) => ({
      readerClerkId: r.readerClerkId,
      readAt: r.readAt,
    }));
  },
});

/**
 * Get read receipts for multiple messages (batch)
 * Use this for efficient loading of chat view
 */
export const getBatchMessageReadReceipts = query({
  args: {
    messageIds: v.array(v.string()),
  },
  handler: async (ctx, args) => {
    const result: Record<string, Array<{
      readerClerkId: string;
      readAt: number;
    }>> = {};
    
    // Initialize empty arrays
    for (const messageId of args.messageIds) {
      result[messageId] = [];
    }
    
    // Query each message
    for (const messageId of args.messageIds) {
      const receipts = await ctx.db
        .query("messageReadReceipts")
        .withIndex("by_message", (q) => q.eq("messageId", messageId))
        .collect();
      
      result[messageId] = receipts.map((r) => ({
        readerClerkId: r.readerClerkId,
        readAt: r.readAt,
      }));
    }
    
    return result;
  },
});

/**
 * Check if a specific user has read a message
 */
export const hasUserReadMessage = query({
  args: {
    messageId: v.string(),
    readerClerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const receipt = await ctx.db
      .query("messageReadReceipts")
      .withIndex("by_message", (q) => q.eq("messageId", args.messageId))
      .filter((q) => q.eq(q.field("readerClerkId"), args.readerClerkId))
      .first();
    
    return {
      hasRead: !!receipt,
      readAt: receipt?.readAt ?? null,
    };
  },
});

/**
 * Get read status for all messages in a chatroom
 * Returns which users have read which messages
 */
export const getChatroomReadStatus = query({
  args: {
    chatroomId: v.string(),
    participantClerkIds: v.array(v.string()), // All participants to check
  },
  handler: async (ctx, args) => {
    const receipts = await ctx.db
      .query("messageReadReceipts")
      .withIndex("by_chatroom", (q) => q.eq("chatroomId", args.chatroomId))
      .collect();
    
    // Group by message ID
    const byMessage: Record<string, Record<string, number>> = {};
    
    for (const receipt of receipts) {
      if (!byMessage[receipt.messageId]) {
        byMessage[receipt.messageId] = {};
      }
      byMessage[receipt.messageId][receipt.readerClerkId] = receipt.readAt;
    }
    
    return byMessage;
  },
});

/**
 * Get unread count for a user in a chatroom
 * Requires message IDs and sender IDs to filter out user's own messages
 */
export const getUnreadCountInChatroom = query({
  args: {
    chatroomId: v.string(),
    readerClerkId: v.string(),
    allMessageIds: v.array(v.string()),
    senderClerkIds: v.array(v.string()), // Parallel array of who sent each message
  },
  handler: async (ctx, args) => {
    // Get all read receipts for this reader in this chatroom
    const receipts = await ctx.db
      .query("messageReadReceipts")
      .withIndex("by_chatroom_and_reader", (q) => 
        q.eq("chatroomId", args.chatroomId).eq("readerClerkId", args.readerClerkId)
      )
      .collect();
    
    const readMessageIds = new Set(receipts.map((r) => r.messageId));
    
    // Count unread messages (excluding user's own messages)
    let unreadCount = 0;
    for (let i = 0; i < args.allMessageIds.length; i++) {
      const messageId = args.allMessageIds[i];
      const senderClerkId = args.senderClerkIds[i];
      
      // Skip user's own messages
      if (senderClerkId === args.readerClerkId) continue;
      
      // Count if not read
      if (!readMessageIds.has(messageId)) {
        unreadCount++;
      }
    }
    
    return { unreadCount };
  },
});

/**
 * Get the last read message ID for a user in a chatroom
 * Useful for showing read indicator position
 */
export const getLastReadMessage = query({
  args: {
    chatroomId: v.string(),
    readerClerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const receipts = await ctx.db
      .query("messageReadReceipts")
      .withIndex("by_chatroom_and_reader", (q) => 
        q.eq("chatroomId", args.chatroomId).eq("readerClerkId", args.readerClerkId)
      )
      .collect();
    
    if (receipts.length === 0) {
      return { lastReadMessageId: null, lastReadAt: null };
    }
    
    // Find the most recent read
    const sorted = receipts.sort((a, b) => b.readAt - a.readAt);
    
    return {
      lastReadMessageId: sorted[0].messageId,
      lastReadAt: sorted[0].readAt,
    };
  },
});


