import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

/**
 * Referral Leaderboard Functions
 * 
 * Real-time leaderboard for tracking referral achievements.
 * Supports weekly, monthly, and all-time rankings.
 */

// Helper to get current ISO week number
function getISOWeek(date: Date): number {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil((((d.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
}

/**
 * Get the weekly referral leaderboard
 */
export const getWeeklyLeaderboard = query({
  args: { 
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 10;
    
    const entries = await ctx.db
      .query("referralLeaderboard")
      .withIndex("by_weekly")
      .order("desc")
      .take(limit);
    
    return entries.map((entry, index) => ({
      rank: index + 1,
      clerkId: entry.clerkId,
      displayName: entry.displayName,
      profileImage: entry.profileImage,
      referralCount: entry.weeklyReferrals,
      lastUpdated: entry.lastUpdated,
    }));
  },
});

/**
 * Get the monthly referral leaderboard
 */
export const getMonthlyLeaderboard = query({
  args: { 
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 10;
    
    const entries = await ctx.db
      .query("referralLeaderboard")
      .withIndex("by_monthly")
      .order("desc")
      .take(limit);
    
    return entries.map((entry, index) => ({
      rank: index + 1,
      clerkId: entry.clerkId,
      displayName: entry.displayName,
      profileImage: entry.profileImage,
      referralCount: entry.monthlyReferrals,
      lastUpdated: entry.lastUpdated,
    }));
  },
});

/**
 * Get the all-time referral leaderboard
 */
export const getAllTimeLeaderboard = query({
  args: { 
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 10;
    
    const entries = await ctx.db
      .query("referralLeaderboard")
      .withIndex("by_total")
      .order("desc")
      .take(limit);
    
    return entries.map((entry, index) => ({
      rank: index + 1,
      clerkId: entry.clerkId,
      displayName: entry.displayName,
      profileImage: entry.profileImage,
      referralCount: entry.totalReferrals,
      lastUpdated: entry.lastUpdated,
    }));
  },
});

/**
 * Get a user's leaderboard position
 */
export const getUserRank = query({
  args: { 
    clerkId: v.string(),
    period: v.union(v.literal("weekly"), v.literal("monthly"), v.literal("allTime")),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("referralLeaderboard")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", args.clerkId))
      .first();
    
    if (!user) {
      return null;
    }
    
    // Count users with more referrals to determine rank
    let countField: "weeklyReferrals" | "monthlyReferrals" | "totalReferrals";
    let userCount: number;
    
    switch (args.period) {
      case "weekly":
        countField = "weeklyReferrals";
        userCount = user.weeklyReferrals;
        break;
      case "monthly":
        countField = "monthlyReferrals";
        userCount = user.monthlyReferrals;
        break;
      default:
        countField = "totalReferrals";
        userCount = user.totalReferrals;
    }
    
    // Get all entries with more referrals than this user
    const allEntries = await ctx.db.query("referralLeaderboard").collect();
    const higherRanked = allEntries.filter(e => e[countField] > userCount);
    
    return {
      rank: higherRanked.length + 1,
      clerkId: user.clerkId,
      displayName: user.displayName,
      profileImage: user.profileImage,
      referralCount: userCount,
      totalReferrals: user.totalReferrals,
      weeklyReferrals: user.weeklyReferrals,
      monthlyReferrals: user.monthlyReferrals,
    };
  },
});

/**
 * Update a user's referral count (called when a referral is completed)
 */
export const updateUserReferralCount = mutation({
  args: {
    clerkId: v.string(),
    displayName: v.string(),
    profileImage: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const currentDate = new Date();
    const currentWeek = getISOWeek(currentDate);
    const currentMonth = currentDate.getMonth() + 1;
    
    // Find existing entry
    const existing = await ctx.db
      .query("referralLeaderboard")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", args.clerkId))
      .first();
    
    if (existing) {
      // Check if we need to reset weekly/monthly counts
      let weeklyReferrals = existing.weeklyReferrals;
      let monthlyReferrals = existing.monthlyReferrals;
      
      // Reset weekly count if it's a new week
      if (existing.currentWeek !== currentWeek) {
        weeklyReferrals = 0;
      }
      
      // Reset monthly count if it's a new month
      if (existing.currentMonth !== currentMonth) {
        monthlyReferrals = 0;
      }
      
      await ctx.db.patch(existing._id, {
        displayName: args.displayName,
        profileImage: args.profileImage,
        totalReferrals: existing.totalReferrals + 1,
        weeklyReferrals: weeklyReferrals + 1,
        monthlyReferrals: monthlyReferrals + 1,
        lastUpdated: now,
        currentWeek,
        currentMonth,
      });
      
      return {
        success: true,
        totalReferrals: existing.totalReferrals + 1,
      };
    } else {
      // Create new entry
      await ctx.db.insert("referralLeaderboard", {
        clerkId: args.clerkId,
        displayName: args.displayName,
        profileImage: args.profileImage,
        totalReferrals: 1,
        weeklyReferrals: 1,
        monthlyReferrals: 1,
        lastUpdated: now,
        currentWeek,
        currentMonth,
      });
      
      return {
        success: true,
        totalReferrals: 1,
      };
    }
  },
});

/**
 * Reset weekly referral counts (should be called by a cron job)
 */
export const resetWeeklyLeaderboard = mutation({
  args: {},
  handler: async (ctx) => {
    const currentWeek = getISOWeek(new Date());
    const entries = await ctx.db.query("referralLeaderboard").collect();
    
    let resetCount = 0;
    for (const entry of entries) {
      if (entry.currentWeek !== currentWeek) {
        await ctx.db.patch(entry._id, {
          weeklyReferrals: 0,
          currentWeek,
        });
        resetCount++;
      }
    }
    
    return { resetCount };
  },
});

/**
 * Reset monthly referral counts (should be called by a cron job)
 */
export const resetMonthlyLeaderboard = mutation({
  args: {},
  handler: async (ctx) => {
    const currentMonth = new Date().getMonth() + 1;
    const entries = await ctx.db.query("referralLeaderboard").collect();
    
    let resetCount = 0;
    for (const entry of entries) {
      if (entry.currentMonth !== currentMonth) {
        await ctx.db.patch(entry._id, {
          monthlyReferrals: 0,
          currentMonth,
        });
        resetCount++;
      }
    }
    
    return { resetCount };
  },
});

