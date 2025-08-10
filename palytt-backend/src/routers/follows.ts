import { z } from 'zod';
import { router, publicProcedure, protectedProcedure } from '../trpc';
import { prisma } from '../db';

export const followsRouter = router({
  // Follow a user
  follow: protectedProcedure
    .input(z.object({
      userId: z.string(), // The user to follow
    }))
    .mutation(async ({ input, ctx }) => {
      const { userId } = input;
      const followerId = ctx.user.clerkId;

      // Check if user is trying to follow themselves
      if (followerId === userId) {
        throw new Error('Cannot follow yourself');
      }

      // Check if target user exists
      const targetUser = await prisma.user.findUnique({
        where: { clerkId: userId },
        select: { id: true },
      });

      if (!targetUser) {
        throw new Error('User not found');
      }

      // Check if already following
      const existingFollow = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId,
            followingId: userId,
          },
        },
      });

      if (existingFollow) {
        throw new Error('Already following this user');
      }

      // Create follow relationship
      const follow = await prisma.follow.create({
        data: {
          followerId,
          followingId: userId,
        },
        include: {
          follower: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
            },
          },
          following: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
            },
          },
        },
      });

      // Update follower and following counts
      await prisma.$transaction([
        prisma.user.update({
          where: { clerkId: followerId },
          data: { followingCount: { increment: 1 } },
        }),
        prisma.user.update({
          where: { clerkId: userId },
          data: { followerCount: { increment: 1 } },
        }),
      ]);

      return follow;
    }),

  // Unfollow a user
  unfollow: protectedProcedure
    .input(z.object({
      userId: z.string(), // The user to unfollow
    }))
    .mutation(async ({ input, ctx }) => {
      const { userId } = input;
      const followerId = ctx.user.clerkId;

      // Find the follow relationship
      const follow = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId,
            followingId: userId,
          },
        },
      });

      if (!follow) {
        throw new Error('Not following this user');
      }

      // Delete follow relationship
      await prisma.follow.delete({
        where: { id: follow.id },
      });

      // Update follower and following counts
      await prisma.$transaction([
        prisma.user.update({
          where: { clerkId: followerId },
          data: { followingCount: { decrement: 1 } },
        }),
        prisma.user.update({
          where: { clerkId: userId },
          data: { followerCount: { decrement: 1 } },
        }),
      ]);

      return { success: true };
    }),

  // Get users that the specified user is following
  getFollowing: publicProcedure
    .input(z.object({
      userId: z.string().optional(), // If not provided, get current user's following
      limit: z.number().min(1).max(100).default(50),
      cursor: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const { userId, limit, cursor } = input;
      const targetUserId = userId || ctx.user?.clerkId;

      if (!targetUserId) {
        throw new Error('User ID required');
      }

      const following = await prisma.follow.findMany({
        where: {
          followerId: targetUserId,
        },
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: {
          createdAt: 'desc',
        },
        include: {
          following: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
              bio: true,
              followerCount: true,
              followingCount: true,
              postsCount: true,
            },
          },
        },
      });

      let nextCursor: typeof cursor | undefined = undefined;
      if (following.length > limit) {
        const nextItem = following.pop();
        nextCursor = nextItem!.id;
      }

      const followingUsers = following.map(follow => ({
        ...follow.following,
        followedAt: follow.createdAt,
      }));

      return {
        following: followingUsers,
        nextCursor,
      };
    }),

  // Get followers of the specified user
  getFollowers: publicProcedure
    .input(z.object({
      userId: z.string().optional(), // If not provided, get current user's followers
      limit: z.number().min(1).max(100).default(50),
      cursor: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const { userId, limit, cursor } = input;
      const targetUserId = userId || ctx.user?.clerkId;

      if (!targetUserId) {
        throw new Error('User ID required');
      }

      const followers = await prisma.follow.findMany({
        where: {
          followingId: targetUserId,
        },
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: {
          createdAt: 'desc',
        },
        include: {
          follower: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
              bio: true,
              followerCount: true,
              followingCount: true,
              postsCount: true,
            },
          },
        },
      });

      let nextCursor: typeof cursor | undefined = undefined;
      if (followers.length > limit) {
        const nextItem = followers.pop();
        nextCursor = nextItem!.id;
      }

      const followerUsers = followers.map(follow => ({
        ...follow.follower,
        followedAt: follow.createdAt,
      }));

      return {
        followers: followerUsers,
        nextCursor,
      };
    }),

  // Check if user1 is following user2
  isFollowing: publicProcedure
    .input(z.object({
      followerId: z.string(),
      followingId: z.string(),
    }))
    .query(async ({ input }) => {
      const { followerId, followingId } = input;

      const follow = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId,
            followingId,
          },
        },
      });

      return { isFollowing: !!follow };
    }),

  // Get follow stats for a user
  getFollowStats: publicProcedure
    .input(z.object({
      userId: z.string(),
    }))
    .query(async ({ input }) => {
      const { userId } = input;

      const user = await prisma.user.findUnique({
        where: { clerkId: userId },
        select: {
          followerCount: true,
          followingCount: true,
          postsCount: true,
        },
      });

      if (!user) {
        throw new Error('User not found');
      }

      return user;
    }),

  // Get mutual follows (users that both user1 and user2 follow)
  getMutualFollows: publicProcedure
    .input(z.object({
      userId1: z.string(),
      userId2: z.string(),
      limit: z.number().min(1).max(50).default(20),
    }))
    .query(async ({ input }) => {
      const { userId1, userId2, limit } = input;

      // Get users that both userId1 and userId2 follow
      const mutualFollows = await prisma.follow.findMany({
        where: {
          followerId: userId1,
          following: {
            followers: {
              some: {
                followerId: userId2,
              },
            },
          },
        },
        take: limit,
        include: {
          following: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
              bio: true,
            },
          },
        },
      });

      const mutualUsers = mutualFollows.map(follow => follow.following);

      return {
        mutualFollows: mutualUsers,
        count: mutualUsers.length,
      };
    }),

  // Get suggested users to follow (users followed by people you follow)
  getSuggestedFollows: protectedProcedure
    .input(z.object({
      limit: z.number().min(1).max(20).default(10),
    }))
    .query(async ({ input, ctx }) => {
      const { limit } = input;
      const userId = ctx.user.clerkId;

      // Get users that people you follow are following, but you're not following yet
      const suggestions = await prisma.follow.findMany({
        where: {
          follower: {
            followers: {
              some: {
                followerId: userId,
              },
            },
          },
          followingId: {
            not: userId, // Don't suggest yourself
          },
          following: {
            followers: {
              none: {
                followerId: userId, // Don't suggest users you already follow
              },
            },
          },
        },
        take: limit * 3, // Get more to filter duplicates
        include: {
          following: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
              bio: true,
              followerCount: true,
              postsCount: true,
            },
          },
        },
        orderBy: {
          following: {
            followerCount: 'desc', // Prioritize popular users
          },
        },
      });

      // Remove duplicates and limit results
      const uniqueSuggestions = suggestions
        .reduce((acc, follow) => {
          const exists = acc.find(item => item.clerkId === follow.following.clerkId);
          if (!exists) {
            acc.push(follow.following);
          }
          return acc;
        }, [] as any[])
        .slice(0, limit);

      return {
        suggestions: uniqueSuggestions,
      };
    }),
});
