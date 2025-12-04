import { z } from 'zod';
import { router, publicProcedure, protectedProcedure } from '../trpc.js';
import { prisma, ensureUser } from '../db.js';

// Helper function to get user UUID from clerkId
async function getUserIdFromClerkId(clerkId: string): Promise<string> {
  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { id: true },
  });
  if (!user) {
    throw new Error('User not found');
  }
  return user.id;
}

// Helper function to get user UUID, creating user if needed
async function ensureUserIdFromClerkId(clerkId: string): Promise<string> {
  const user = await ensureUser(clerkId, `${clerkId}@clerk.local`);
  return user.id;
}

export const followsRouter = router({
  // Follow a user
  follow: protectedProcedure
    .input(z.object({
      userId: z.string(), // The clerkId of the user to follow
    }))
    .mutation(async ({ input, ctx }) => {
      const { userId: targetClerkId } = input;
      const followerClerkId = ctx.user.clerkId;

      // Check if user is trying to follow themselves
      if (followerClerkId === targetClerkId) {
        throw new Error('Cannot follow yourself');
      }

      // Get UUIDs for both users
      const followerUUID = await ensureUserIdFromClerkId(followerClerkId);
      const targetUUID = await getUserIdFromClerkId(targetClerkId);

      // Check if already following
      const existingFollow = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId: followerUUID,
            followingId: targetUUID,
          },
        },
      });

      if (existingFollow) {
        throw new Error('Already following this user');
      }

      // Create follow relationship using UUIDs
      const follow = await prisma.follow.create({
        data: {
          followerId: followerUUID,
          followingId: targetUUID,
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
          where: { id: followerUUID },
          data: { followingCount: { increment: 1 } },
        }),
        prisma.user.update({
          where: { id: targetUUID },
          data: { followerCount: { increment: 1 } },
        }),
      ]);

      return follow;
    }),

  // Unfollow a user
  unfollow: protectedProcedure
    .input(z.object({
      userId: z.string(), // The clerkId of the user to unfollow
    }))
    .mutation(async ({ input, ctx }) => {
      const { userId: targetClerkId } = input;
      const followerClerkId = ctx.user.clerkId;

      // Get UUIDs for both users
      const followerUUID = await ensureUserIdFromClerkId(followerClerkId);
      const targetUUID = await getUserIdFromClerkId(targetClerkId);

      // Find the follow relationship
      const follow = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId: followerUUID,
            followingId: targetUUID,
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
          where: { id: followerUUID },
          data: { followingCount: { decrement: 1 } },
        }),
        prisma.user.update({
          where: { id: targetUUID },
          data: { followerCount: { decrement: 1 } },
        }),
      ]);

      return { success: true };
    }),

  // Get users that the specified user is following
  getFollowing: publicProcedure
    .input(z.object({
      userId: z.string().optional(), // clerkId - If not provided, get current user's following
      limit: z.number().min(1).max(100).default(50),
      cursor: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const { userId: userClerkId, limit, cursor } = input;
      const targetClerkId = userClerkId || ctx.user?.clerkId;

      if (!targetClerkId) {
        throw new Error('User ID required');
      }

      // Get target user's UUID
      const targetUUID = await getUserIdFromClerkId(targetClerkId);

      const following = await prisma.follow.findMany({
        where: {
          followerId: targetUUID,
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

      const followingUsers = following.map((follow: any) => ({
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
      userId: z.string().optional(), // clerkId - If not provided, get current user's followers
      limit: z.number().min(1).max(100).default(50),
      cursor: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const { userId: userClerkId, limit, cursor } = input;
      const targetClerkId = userClerkId || ctx.user?.clerkId;

      if (!targetClerkId) {
        throw new Error('User ID required');
      }

      // Get target user's UUID
      const targetUUID = await getUserIdFromClerkId(targetClerkId);

      const followers = await prisma.follow.findMany({
        where: {
          followingId: targetUUID,
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

      const followerUsers = followers.map((follow: any) => ({
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
      followerId: z.string(), // clerkId
      followingId: z.string(), // clerkId
    }))
    .query(async ({ input }) => {
      const { followerId: followerClerkId, followingId: followingClerkId } = input;

      // Get UUIDs for both users
      let followerUUID: string, followingUUID: string;
      try {
        [followerUUID, followingUUID] = await Promise.all([
          getUserIdFromClerkId(followerClerkId),
          getUserIdFromClerkId(followingClerkId),
        ]);
      } catch {
        // If either user doesn't exist, they can't be following
        return { isFollowing: false };
      }

      const follow = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId: followerUUID,
            followingId: followingUUID,
          },
        },
      });

      return { isFollowing: !!follow };
    }),

  // Get follow stats for a user
  getFollowStats: publicProcedure
    .input(z.object({
      userId: z.string(), // clerkId
    }))
    .query(async ({ input }) => {
      const { userId: clerkId } = input;

      const user = await prisma.user.findUnique({
        where: { clerkId },
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
      userId1: z.string(), // clerkId
      userId2: z.string(), // clerkId
      limit: z.number().min(1).max(50).default(20),
    }))
    .query(async ({ input }) => {
      const { userId1: clerkId1, userId2: clerkId2, limit } = input;

      // Get UUIDs for both users
      let uuid1: string, uuid2: string;
      try {
        [uuid1, uuid2] = await Promise.all([
          getUserIdFromClerkId(clerkId1),
          getUserIdFromClerkId(clerkId2),
        ]);
      } catch {
        // If either user doesn't exist, they have no mutual follows
        return { mutualFollows: [], count: 0 };
      }

      // Get users that both userId1 and userId2 follow
      const mutualFollows = await prisma.follow.findMany({
        where: {
          followerId: uuid1,
          following: {
            followers: {
              some: {
                followerId: uuid2,
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

      const mutualUsers = mutualFollows.map((follow: any) => follow.following);

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
      const userClerkId = ctx.user.clerkId;

      // Get current user's UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);

      // Get users that people you follow are following, but you're not following yet
      const suggestions = await prisma.follow.findMany({
        where: {
          follower: {
            followers: {
              some: {
                followerId: userUUID,
              },
            },
          },
          followingId: {
            not: userUUID, // Don't suggest yourself
          },
          following: {
            followers: {
              none: {
                followerId: userUUID, // Don't suggest users you already follow
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
        .reduce((acc: any[], follow: any) => {
          const exists = acc.find((item: any) => item.clerkId === follow.following.clerkId);
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
