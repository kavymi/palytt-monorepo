import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

/**
 * Presence Tracking Functions
 * 
 * These functions handle real-time user presence:
 * - Heartbeat updates (call every 30 seconds)
 * - Status changes (online/away/offline)
 * - Friend presence subscriptions
 */

// ============================================
// MUTATIONS
// ============================================

/**
 * Update user's presence status
 * Called when:
 * - App launches (status: online)
 * - App goes to background (status: away)
 * - App terminates (status: offline)
 * - Periodic heartbeat (every 30s, status: online)
 */
export const updatePresence = mutation({
  args: {
    clerkId: v.string(),
    status: v.union(
      v.literal("online"),
      v.literal("away"),
      v.literal("offline")
    ),
    currentScreen: v.optional(v.string()),
    deviceId: v.optional(v.string()),
    deviceType: v.optional(v.union(
      v.literal("ios"),
      v.literal("android"),
      v.literal("web")
    )),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    // Check if presence record exists
    const existing = await ctx.db
      .query("presence")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", args.clerkId))
      .first();
    
    if (existing) {
      // Update existing presence
      await ctx.db.patch(existing._id, {
        status: args.status,
        lastSeen: now,
        currentScreen: args.currentScreen,
        deviceId: args.deviceId,
        deviceType: args.deviceType,
      });
      return existing._id;
    } else {
      // Create new presence record
      return await ctx.db.insert("presence", {
        clerkId: args.clerkId,
        status: args.status,
        lastSeen: now,
        currentScreen: args.currentScreen,
        deviceId: args.deviceId,
        deviceType: args.deviceType ?? "ios",
      });
    }
  },
});

/**
 * Heartbeat - lightweight presence update
 * Call every 30 seconds to maintain online status
 */
export const heartbeat = mutation({
  args: {
    clerkId: v.string(),
    currentScreen: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    const existing = await ctx.db
      .query("presence")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", args.clerkId))
      .first();
    
    if (existing) {
      await ctx.db.patch(existing._id, {
        lastSeen: now,
        status: "online",
        currentScreen: args.currentScreen,
      });
      return { success: true, updated: true };
    } else {
      // Auto-create presence record if doesn't exist
      await ctx.db.insert("presence", {
        clerkId: args.clerkId,
        status: "online",
        lastSeen: now,
        currentScreen: args.currentScreen,
        deviceType: "ios",
      });
      return { success: true, updated: false, created: true };
    }
  },
});

/**
 * Set user as offline
 * Called when app terminates or user logs out
 */
export const setOffline = mutation({
  args: {
    clerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("presence")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", args.clerkId))
      .first();
    
    if (existing) {
      await ctx.db.patch(existing._id, {
        status: "offline",
        lastSeen: Date.now(),
        currentScreen: undefined,
      });
      return { success: true };
    }
    return { success: false, error: "Presence record not found" };
  },
});

/**
 * Cleanup stale presence records
 * Mark users as offline if no heartbeat for 2 minutes
 * Should be called by a scheduled function
 */
export const cleanupStalePresence = mutation({
  args: {},
  handler: async (ctx) => {
    const twoMinutesAgo = Date.now() - 2 * 60 * 1000;
    
    // Find all online/away users with stale lastSeen
    const staleUsers = await ctx.db
      .query("presence")
      .filter((q) => 
        q.and(
          q.neq(q.field("status"), "offline"),
          q.lt(q.field("lastSeen"), twoMinutesAgo)
        )
      )
      .collect();
    
    // Mark them as offline
    let updatedCount = 0;
    for (const user of staleUsers) {
      await ctx.db.patch(user._id, {
        status: "offline",
      });
      updatedCount++;
    }
    
    return { updatedCount };
  },
});

// ============================================
// QUERIES
// ============================================

/**
 * Get current user's presence
 */
export const getMyPresence = query({
  args: {
    clerkId: v.string(),
  },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("presence")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", args.clerkId))
      .first();
  },
});

/**
 * Get presence for a single user
 * Use this for profile views
 */
export const getUserPresence = query({
  args: {
    clerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const presence = await ctx.db
      .query("presence")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", args.clerkId))
      .first();
    
    if (!presence) {
      return {
        clerkId: args.clerkId,
        status: "offline" as const,
        lastSeen: null,
      };
    }
    
    // Check if presence is stale (no heartbeat for 2 minutes)
    const isStale = Date.now() - presence.lastSeen > 2 * 60 * 1000;
    
    return {
      clerkId: presence.clerkId,
      status: isStale ? "offline" as const : presence.status,
      lastSeen: presence.lastSeen,
      currentScreen: presence.currentScreen,
    };
  },
});

/**
 * Get presence for multiple users (batch query)
 * Use this for friend lists, chatroom participants, etc.
 */
export const getBatchPresence = query({
  args: {
    clerkIds: v.array(v.string()),
  },
  handler: async (ctx, args) => {
    const results: Record<string, {
      clerkId: string;
      status: "online" | "away" | "offline";
      lastSeen: number | null;
      currentScreen?: string;
    }> = {};
    
    const now = Date.now();
    const staleThreshold = 2 * 60 * 1000;
    
    for (const clerkId of args.clerkIds) {
      const presence = await ctx.db
        .query("presence")
        .withIndex("by_clerk_id", (q) => q.eq("clerkId", clerkId))
        .first();
      
      if (presence) {
        const isStale = now - presence.lastSeen > staleThreshold;
        results[clerkId] = {
          clerkId: presence.clerkId,
          status: isStale ? "offline" : presence.status,
          lastSeen: presence.lastSeen,
          currentScreen: presence.currentScreen,
        };
      } else {
        results[clerkId] = {
          clerkId,
          status: "offline",
          lastSeen: null,
        };
      }
    }
    
    return results;
  },
});

/**
 * Get all online friends
 * Returns list of currently online users from provided friend list
 */
export const getOnlineFriends = query({
  args: {
    friendClerkIds: v.array(v.string()),
  },
  handler: async (ctx, args) => {
    const onlineFriends: Array<{
      clerkId: string;
      status: "online" | "away";
      lastSeen: number;
      currentScreen?: string;
    }> = [];
    
    const now = Date.now();
    const staleThreshold = 2 * 60 * 1000;
    
    for (const clerkId of args.friendClerkIds) {
      const presence = await ctx.db
        .query("presence")
        .withIndex("by_clerk_id", (q) => q.eq("clerkId", clerkId))
        .first();
      
      if (presence && presence.status !== "offline") {
        const isStale = now - presence.lastSeen > staleThreshold;
        if (!isStale) {
          onlineFriends.push({
            clerkId: presence.clerkId,
            status: presence.status as "online" | "away",
            lastSeen: presence.lastSeen,
            currentScreen: presence.currentScreen,
          });
        }
      }
    }
    
    return onlineFriends;
  },
});

/**
 * Get count of online users (for stats/debugging)
 */
export const getOnlineCount = query({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    const staleThreshold = 2 * 60 * 1000;
    
    const allPresence = await ctx.db
      .query("presence")
      .withIndex("by_status", (q) => q.eq("status", "online"))
      .collect();
    
    // Filter out stale records
    const activeCount = allPresence.filter(
      (p) => now - p.lastSeen <= staleThreshold
    ).length;
    
    return { online: activeCount, total: allPresence.length };
  },
});

