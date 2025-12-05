/**
 * Convex functions for real-time gathering voting
 * 
 * This module provides real-time updates for group gathering venues, dates, and times voting.
 * Votes are synced instantly across all participants without polling.
 */

import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

// ===========================================
// SCHEMA (for reference - actual schema in schema.ts)
// ===========================================
// gatheringVotes table structure:
// - gatheringId: string (Postgres gathering ID)
// - clerkId: string (voter's Clerk ID)
// - voterName: string?
// - voteType: "venue" | "date" | "time"
// - optionId: string (the option being voted for)
// - createdAt: number
// - updatedAt: number

// ===========================================
// MUTATIONS
// ===========================================

/**
 * Cast or update a vote for a gathering option
 */
export const castVote = mutation({
  args: {
    gatheringId: v.string(),
    clerkId: v.string(),
    voterName: v.optional(v.string()),
    voteType: v.union(v.literal("venue"), v.literal("date"), v.literal("time")),
    optionId: v.string(),
  },
  handler: async (ctx, args) => {
    const { gatheringId, clerkId, voterName, voteType, optionId } = args;
    const now = Date.now();

    // Check if user already voted for this type in this gathering
    const existingVote = await ctx.db
      .query("gatheringVotes")
      .withIndex("by_gathering_voter_type", (q) =>
        q.eq("gatheringId", gatheringId).eq("clerkId", clerkId).eq("voteType", voteType)
      )
      .first();

    if (existingVote) {
      // Update existing vote
      await ctx.db.patch(existingVote._id, {
        optionId,
        voterName,
        updatedAt: now,
      });
      return existingVote._id;
    }

    // Create new vote
    return await ctx.db.insert("gatheringVotes", {
      gatheringId,
      clerkId,
      voterName,
      voteType,
      optionId,
      createdAt: now,
      updatedAt: now,
    });
  },
});

/**
 * Remove a vote
 */
export const removeVote = mutation({
  args: {
    gatheringId: v.string(),
    clerkId: v.string(),
    voteType: v.union(v.literal("venue"), v.literal("date"), v.literal("time")),
  },
  handler: async (ctx, args) => {
    const { gatheringId, clerkId, voteType } = args;

    const existingVote = await ctx.db
      .query("gatheringVotes")
      .withIndex("by_gathering_voter_type", (q) =>
        q.eq("gatheringId", gatheringId).eq("clerkId", clerkId).eq("voteType", voteType)
      )
      .first();

    if (existingVote) {
      await ctx.db.delete(existingVote._id);
      return true;
    }

    return false;
  },
});

/**
 * Remove all votes for a gathering (when gathering is deleted)
 */
export const clearGatheringVotes = mutation({
  args: {
    gatheringId: v.string(),
  },
  handler: async (ctx, args) => {
    const votes = await ctx.db
      .query("gatheringVotes")
      .withIndex("by_gathering", (q) => q.eq("gatheringId", args.gatheringId))
      .collect();

    for (const vote of votes) {
      await ctx.db.delete(vote._id);
    }

    return votes.length;
  },
});

// ===========================================
// QUERIES
// ===========================================

/**
 * Subscribe to all votes for a gathering (real-time)
 */
export const subscribeToGatheringVotes = query({
  args: {
    gatheringId: v.string(),
  },
  handler: async (ctx, args) => {
    const votes = await ctx.db
      .query("gatheringVotes")
      .withIndex("by_gathering", (q) => q.eq("gatheringId", args.gatheringId))
      .collect();

    // Group votes by type
    const venueVotes = votes.filter((v) => v.voteType === "venue");
    const dateVotes = votes.filter((v) => v.voteType === "date");
    const timeVotes = votes.filter((v) => v.voteType === "time");

    // Calculate vote counts per option
    const calculateCounts = (voteList: typeof votes) => {
      const counts: Record<string, { count: number; voters: string[] }> = {};
      for (const vote of voteList) {
        if (!counts[vote.optionId]) {
          counts[vote.optionId] = { count: 0, voters: [] };
        }
        counts[vote.optionId].count++;
        if (vote.voterName) {
          counts[vote.optionId].voters.push(vote.voterName);
        }
      }
      return counts;
    };

    return {
      venueVotes: calculateCounts(venueVotes),
      dateVotes: calculateCounts(dateVotes),
      timeVotes: calculateCounts(timeVotes),
      totalVoters: new Set(votes.map((v) => v.clerkId)).size,
      lastUpdated: Math.max(...votes.map((v) => v.updatedAt), 0),
    };
  },
});

/**
 * Get votes by type for a gathering
 */
export const getVotesByType = query({
  args: {
    gatheringId: v.string(),
    voteType: v.union(v.literal("venue"), v.literal("date"), v.literal("time")),
  },
  handler: async (ctx, args) => {
    const votes = await ctx.db
      .query("gatheringVotes")
      .withIndex("by_gathering", (q) => q.eq("gatheringId", args.gatheringId))
      .filter((q) => q.eq(q.field("voteType"), args.voteType))
      .collect();

    // Group by optionId
    const voteCounts: Record<string, { count: number; voters: { clerkId: string; name?: string }[] }> = {};
    
    for (const vote of votes) {
      if (!voteCounts[vote.optionId]) {
        voteCounts[vote.optionId] = { count: 0, voters: [] };
      }
      voteCounts[vote.optionId].count++;
      voteCounts[vote.optionId].voters.push({
        clerkId: vote.clerkId,
        name: vote.voterName,
      });
    }

    return voteCounts;
  },
});

/**
 * Check if a user has voted
 */
export const getUserVote = query({
  args: {
    gatheringId: v.string(),
    clerkId: v.string(),
    voteType: v.union(v.literal("venue"), v.literal("date"), v.literal("time")),
  },
  handler: async (ctx, args) => {
    const vote = await ctx.db
      .query("gatheringVotes")
      .withIndex("by_gathering_voter_type", (q) =>
        q.eq("gatheringId", args.gatheringId).eq("clerkId", args.clerkId).eq("voteType", args.voteType)
      )
      .first();

    return vote ? vote.optionId : null;
  },
});

/**
 * Get all votes by a user for a gathering
 */
export const getUserVotes = query({
  args: {
    gatheringId: v.string(),
    clerkId: v.string(),
  },
  handler: async (ctx, args) => {
    const votes = await ctx.db
      .query("gatheringVotes")
      .withIndex("by_gathering", (q) => q.eq("gatheringId", args.gatheringId))
      .filter((q) => q.eq(q.field("clerkId"), args.clerkId))
      .collect();

    return {
      venue: votes.find((v) => v.voteType === "venue")?.optionId ?? null,
      date: votes.find((v) => v.voteType === "date")?.optionId ?? null,
      time: votes.find((v) => v.voteType === "time")?.optionId ?? null,
    };
  },
});

/**
 * Get the leading options for a gathering
 */
export const getLeadingOptions = query({
  args: {
    gatheringId: v.string(),
  },
  handler: async (ctx, args) => {
    const votes = await ctx.db
      .query("gatheringVotes")
      .withIndex("by_gathering", (q) => q.eq("gatheringId", args.gatheringId))
      .collect();

    const findLeader = (voteType: "venue" | "date" | "time") => {
      const typeVotes = votes.filter((v) => v.voteType === voteType);
      const counts: Record<string, number> = {};
      
      for (const vote of typeVotes) {
        counts[vote.optionId] = (counts[vote.optionId] || 0) + 1;
      }

      let maxCount = 0;
      let leader: string | null = null;
      
      for (const [optionId, count] of Object.entries(counts)) {
        if (count > maxCount) {
          maxCount = count;
          leader = optionId;
        }
      }

      return { optionId: leader, count: maxCount };
    };

    return {
      venue: findLeader("venue"),
      date: findLeader("date"),
      time: findLeader("time"),
    };
  },
});

