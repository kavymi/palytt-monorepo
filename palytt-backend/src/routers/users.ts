import { z } from 'zod';
import { router, publicProcedure, protectedProcedure } from '../trpc.js';
import { prisma } from '../db.js';
import {
  cacheSet,
  cacheGetOrSet,
  CacheKeys,
  CacheTTL,
  invalidateUserCache,
  invalidateUserCacheByClerkId,
} from '../cache/cache.service.js';
import {
  UserSchema,
  CreateUserSchema,
  UpdateUserSchema,
  UserResponseSchema,
  UserListResponseSchema,
  UserStatsResponseSchema,
  StreakInfoResponseSchema,
  PhoneHashSearchResponseSchema,
  UserSearchResponseSchema,
  ClerkIdParamSchema,
  UuidParamSchema,
  PaginationInputSchema,
} from '../schemas/index.js';

export const usersRouter = router({
  /**
   * Create a new user
   */
  create: publicProcedure
    .input(CreateUserSchema)
    .output(UserResponseSchema)
    .mutation(async ({ input }) => {
      const newUser = await prisma.user.create({
        data: {
          email: input.email,
          username: input.username,
          name: input.name,
          bio: input.bio,
          profileImage: input.profileImage,
          website: input.website,
          clerkId: input.clerkId,
        },
      });
      
      return {
        success: true,
        user: {
          ...newUser,
          createdAt: newUser.createdAt.toISOString(),
          updatedAt: newUser.updatedAt.toISOString(),
        },
      };
    }),

  /**
   * Get user by ID
   */
  getById: publicProcedure
    .input(UuidParamSchema)
    .output(UserSchema)
    .query(async ({ input }) => {
      const cacheKey = `${CacheKeys.USER_PROFILE}${input.id}`;
      
      return cacheGetOrSet(
        cacheKey,
        async () => {
          const user = await prisma.user.findUnique({
            where: { id: input.id },
          });
          
          if (!user) {
            throw new Error('User not found');
          }
          
          return {
            ...user,
            createdAt: user.createdAt.toISOString(),
            updatedAt: user.updatedAt.toISOString(),
          };
        },
        CacheTTL.USER_PROFILE
      );
    }),

  /**
   * Get user by Clerk ID
   */
  getByClerkId: publicProcedure
    .input(ClerkIdParamSchema)
    .output(UserSchema)
    .query(async ({ input }) => {
      const cacheKey = `${CacheKeys.USER_BY_CLERK}${input.clerkId}`;
      
      return cacheGetOrSet(
        cacheKey,
        async () => {
          const user = await prisma.user.findUnique({
            where: { clerkId: input.clerkId },
          });
          
          if (!user) {
            throw new Error('User not found');
          }
          
          // Also cache the user ID mapping for future invalidation
          await cacheSet(`${CacheKeys.USER_PROFILE}${user.id}`, {
            ...user,
            createdAt: user.createdAt.toISOString(),
            updatedAt: user.updatedAt.toISOString(),
          }, CacheTTL.USER_PROFILE);
          
          return {
            ...user,
            createdAt: user.createdAt.toISOString(),
            updatedAt: user.updatedAt.toISOString(),
          };
        },
        CacheTTL.USER_PROFILE
      );
    }),

  /**
   * Update user by ID
   */
  update: publicProcedure
    .input(z.object({ 
      id: z.string().uuid(),
      data: UpdateUserSchema,
    }))
    .output(UserResponseSchema)
    .mutation(async ({ input }) => {
      const updatedUser = await prisma.user.update({
        where: { id: input.id },
        data: input.data,
      });
      
      // Invalidate user cache
      await invalidateUserCache(input.id);
      
      return {
        success: true,
        user: {
          ...updatedUser,
          createdAt: updatedUser.createdAt.toISOString(),
          updatedAt: updatedUser.updatedAt.toISOString(),
        },
      };
    }),

  /**
   * Update user by Clerk ID
   */
  updateByClerkId: publicProcedure
    .input(z.object({ 
      clerkId: z.string().min(1),
      data: UpdateUserSchema,
    }))
    .output(UserResponseSchema)
    .mutation(async ({ input }) => {
      // Map iOS field names to backend field names
      // iOS sends: firstName, lastName, avatarUrl
      // Backend expects: name, profileImage
      const { firstName, lastName, avatarUrl, dietaryPreferences, ...restData } = input.data;
      
      // Build name from firstName/lastName if provided
      let name = restData.name;
      if (!name && (firstName || lastName)) {
        name = [firstName, lastName].filter(Boolean).join(' ').trim() || null;
      }
      
      // Use avatarUrl if profileImage not provided
      const profileImage = restData.profileImage ?? avatarUrl ?? undefined;
      
      const updatedUser = await prisma.user.update({
        where: { clerkId: input.clerkId },
        data: {
          ...restData,
          name: name ?? undefined,
          profileImage: profileImage ?? undefined,
        },
      });
      
      // Invalidate user cache by Clerk ID
      await invalidateUserCacheByClerkId(input.clerkId);
      
      return {
        success: true,
        user: {
          ...updatedUser,
          createdAt: updatedUser.createdAt.toISOString(),
          updatedAt: updatedUser.updatedAt.toISOString(),
        },
      };
    }),

  /**
   * Create or update user (upsert by Clerk ID)
   * Also aliased as upsertByClerkId for iOS compatibility
   */
  upsert: publicProcedure
    .input(CreateUserSchema)
    .output(UserResponseSchema.extend({ created: z.boolean().optional() }))
    .mutation(async ({ input }) => {
      // Map iOS field names to backend field names
      // iOS sends: firstName, lastName, avatarUrl
      // Backend expects: name, profileImage
      const name = input.name ?? (input.firstName && input.lastName 
        ? `${input.firstName} ${input.lastName}`.trim()
        : input.firstName ?? input.lastName ?? null);
      const profileImage = input.profileImage ?? input.avatarUrl ?? null;
      
      const user = await prisma.user.upsert({
        where: { clerkId: input.clerkId },
        update: {
          email: input.email,
          username: input.username ?? undefined,
          name: name ?? undefined,
          bio: input.bio ?? undefined,
          profileImage: profileImage ?? undefined,
          website: input.website ?? undefined,
        },
        create: {
          email: input.email,
          username: input.username,
          name: name,
          bio: input.bio,
          profileImage: profileImage,
          website: input.website,
          clerkId: input.clerkId,
        },
      });
      
      const isNew = user.createdAt.getTime() === user.updatedAt.getTime();
      
      return {
        success: true,
        user: {
          ...user,
          createdAt: user.createdAt.toISOString(),
          updatedAt: user.updatedAt.toISOString(),
        },
        created: isNew,
      };
    }),

  /**
   * List all users (with pagination)
   */
  list: publicProcedure
    .input(PaginationInputSchema.extend({
      search: z.string().optional(),
    }))
    .output(UserListResponseSchema)
    .query(async ({ input }) => {
      const skip = (input.page - 1) * input.limit;
      
      const where = input.search
        ? {
            OR: [
              { name: { contains: input.search, mode: 'insensitive' as const } },
              { username: { contains: input.search, mode: 'insensitive' as const } },
              { email: { contains: input.search, mode: 'insensitive' as const } },
            ],
          }
        : {};
      
      const [users, totalCount] = await Promise.all([
        prisma.user.findMany({
          where,
          skip,
          take: input.limit,
          orderBy: { createdAt: 'desc' },
        }),
        prisma.user.count({ where }),
      ]);

      return {
        users: users.map((user: any) => ({
          ...user,
          createdAt: user.createdAt.toISOString(),
          updatedAt: user.updatedAt.toISOString(),
        })),
        pagination: {
          page: input.page,
          limit: input.limit,
          total: totalCount,
          totalPages: Math.ceil(totalCount / input.limit),
        },
      };
    }),

  /**
   * Get user statistics
   */
  getStats: publicProcedure
    .input(ClerkIdParamSchema)
    .output(UserStatsResponseSchema)
    .query(async ({ input }) => {
      const user = await prisma.user.findUnique({
        where: { clerkId: input.clerkId },
        include: {
          _count: {
            select: {
              posts: true,
              comments: true,
              likes: true,
              bookmarks: true,
            },
          },
        },
      });
      
      if (!user) {
        throw new Error('User not found');
      }
      
      return {
        postsCount: user._count.posts,
        commentsCount: user._count.comments,
        likesCount: user._count.likes,
        bookmarksCount: user._count.bookmarks,
        followerCount: user.followerCount,
        followingCount: user.followingCount,
      };
    }),

  /**
   * Get user's posting streak information
   */
  getStreakInfo: publicProcedure
    .input(ClerkIdParamSchema)
    .output(StreakInfoResponseSchema)
    .query(async ({ input }) => {
      const user = await prisma.user.findUnique({
        where: { clerkId: input.clerkId },
        select: {
          currentStreak: true,
          longestStreak: true,
          lastPostDate: true,
          streakFreezeCount: true,
        },
      });
      
      if (!user) {
        throw new Error('User not found');
      }
      
      // Check if streak is still active (posted within last 2 days)
      const now = new Date();
      let isStreakActive = false;
      let daysSinceLastPost = 0;
      
      if (user.lastPostDate) {
        const lastPost = new Date(user.lastPostDate);
        const diffTime = now.getTime() - lastPost.getTime();
        daysSinceLastPost = Math.floor(diffTime / (1000 * 60 * 60 * 24));
        isStreakActive = daysSinceLastPost <= 1;
      }
      
      // If streak is broken, return 0 for current streak
      const effectiveStreak = isStreakActive ? user.currentStreak : 0;
      
      // Calculate streak milestones
      const milestones = [7, 14, 30, 60, 100, 365];
      const nextMilestone = milestones.find(m => m > effectiveStreak) || null;
      const achievedMilestones = milestones.filter(m => m <= user.longestStreak);
      
      return {
        currentStreak: effectiveStreak,
        longestStreak: user.longestStreak || 0,
        lastPostDate: user.lastPostDate?.toISOString() || null,
        isStreakActive,
        daysSinceLastPost,
        streakFreezeCount: user.streakFreezeCount || 0,
        nextMilestone,
        achievedMilestones,
      };
    }),

  /**
   * Find users by hashed phone numbers (for contacts sync)
   * This endpoint receives SHA256 hashes of normalized phone numbers
   * and returns matching users who have those phone hashes stored.
   * 
   * Privacy: We never store or receive actual phone numbers - only hashes.
   */
  findByPhoneHashes: publicProcedure
    .input(z.object({
      phoneHashes: z.array(z.string()).max(500), // Limit to 500 hashes per request
    }))
    .output(PhoneHashSearchResponseSchema)
    .query(async ({ input }) => {
      const { phoneHashes } = input;
      
      if (phoneHashes.length === 0) {
        return {
          users: [],
          matchedHashes: [],
        };
      }
      
      // Find users with matching phone hashes
      const users = await prisma.user.findMany({
        where: {
          phoneHash: {
            in: phoneHashes,
          },
        },
        select: {
          id: true,
          clerkId: true,
          username: true,
          name: true,
          profileImage: true,
          bio: true,
          phoneHash: true,
          followerCount: true,
          followingCount: true,
          postsCount: true,
          isVerified: true,
          isActive: true,
          createdAt: true,
          updatedAt: true,
        },
      });
      
      // Get the matched hashes
      const matchedHashes = users.map((u: any) => u.phoneHash).filter(Boolean);
      
      // Transform users for response
      const transformedUsers = users.map((user: any) => ({
        id: user.id,
        clerkId: user.clerkId,
        username: user.username,
        name: user.name,
        profileImage: user.profileImage,
        bio: user.bio,
        phoneHash: user.phoneHash,
        followerCount: user.followerCount,
        followingCount: user.followingCount,
        postsCount: user.postsCount,
        isVerified: user.isVerified || false,
        isActive: user.isActive || true,
        createdAt: user.createdAt.toISOString(),
        updatedAt: user.updatedAt.toISOString(),
      }));
      
      return {
        users: transformedUsers,
        matchedHashes,
      };
    }),

  /**
   * Search users by query string
   * Used by iOS app for @mentions autocomplete
   */
  search: publicProcedure
    .input(z.object({
      query: z.string().min(1),
      limit: z.number().int().positive().max(20).default(10),
    }))
    .output(UserSearchResponseSchema)
    .query(async ({ input }) => {
      const { query, limit } = input;
      
      const users = await prisma.user.findMany({
        where: {
          OR: [
            { name: { contains: query, mode: 'insensitive' as const } },
            { username: { contains: query, mode: 'insensitive' as const } },
          ],
        },
        take: limit,
        orderBy: { followerCount: 'desc' },
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
          isVerified: true,
          createdAt: true,
          updatedAt: true,
        },
      });
      
      // Return array of users directly for iOS compatibility
      return users.map((user: any) => ({
        _id: user.id,
        id: user.id,
        clerkId: user.clerkId,
        username: user.username,
        displayName: user.name,
        name: user.name,
        firstName: user.name?.split(' ')[0] || null,
        lastName: user.name?.split(' ').slice(1).join(' ') || null,
        avatarUrl: user.profileImage,
        profileImage: user.profileImage,
        bio: user.bio,
        followerCount: user.followerCount,
        followingCount: user.followingCount,
        postsCount: user.postsCount,
        isVerified: user.isVerified || false,
        createdAt: user.createdAt.toISOString(),
        updatedAt: user.updatedAt.toISOString(),
      }));
    }),

  /**
   * Get suggested users for discovery
   */
  getSuggested: publicProcedure
    .input(z.object({
      limit: z.number().int().positive().max(50).default(10),
      excludeUserId: z.string().optional(),
    }))
    .output(UserSearchResponseSchema)
    .query(async ({ input }) => {
      const { limit, excludeUserId } = input;
      
      const users = await prisma.user.findMany({
        where: excludeUserId ? {
          clerkId: { not: excludeUserId },
        } : undefined,
        take: limit,
        orderBy: { followerCount: 'desc' },
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
          isVerified: true,
          createdAt: true,
          updatedAt: true,
        },
      });
      
      // Return array of users directly for iOS compatibility
      return users.map((user: any) => ({
        _id: user.id,
        id: user.id,
        clerkId: user.clerkId,
        username: user.username,
        displayName: user.name,
        name: user.name,
        firstName: user.name?.split(' ')[0] || null,
        lastName: user.name?.split(' ').slice(1).join(' ') || null,
        avatarUrl: user.profileImage,
        profileImage: user.profileImage,
        bio: user.bio,
        followerCount: user.followerCount,
        followingCount: user.followingCount,
        postsCount: user.postsCount,
        isVerified: user.isVerified || false,
        createdAt: user.createdAt.toISOString(),
        updatedAt: user.updatedAt.toISOString(),
      }));
    }),

  /**
   * Alias for upsert - iOS app calls this endpoint name
   */
  upsertByClerkId: publicProcedure
    .input(CreateUserSchema)
    .output(UserResponseSchema.extend({ created: z.boolean().optional() }))
    .mutation(async ({ input }) => {
      // Map iOS field names to backend field names
      // iOS sends: firstName, lastName, avatarUrl
      // Backend expects: name, profileImage
      const name = input.name ?? (input.firstName && input.lastName 
        ? `${input.firstName} ${input.lastName}`.trim()
        : input.firstName ?? input.lastName ?? null);
      const profileImage = input.profileImage ?? input.avatarUrl ?? null;
      
      const user = await prisma.user.upsert({
        where: { clerkId: input.clerkId },
        update: {
          email: input.email,
          username: input.username ?? undefined,
          name: name ?? undefined,
          bio: input.bio ?? undefined,
          profileImage: profileImage ?? undefined,
          website: input.website ?? undefined,
        },
        create: {
          email: input.email,
          username: input.username,
          name: name,
          bio: input.bio,
          profileImage: profileImage,
          website: input.website,
          clerkId: input.clerkId,
        },
      });
      
      const isNew = user.createdAt.getTime() === user.updatedAt.getTime();
      
      return {
        success: true,
        user: {
          ...user,
          createdAt: user.createdAt.toISOString(),
          updatedAt: user.updatedAt.toISOString(),
        },
        created: isNew,
      };
    }),

  /**
   * Delete user account and all associated data
   * This is a protected endpoint that requires authentication
   * The user can only delete their own account
   */
  deleteAccount: protectedProcedure
    .output(z.object({
      success: z.boolean(),
      message: z.string(),
    }))
    .mutation(async ({ ctx }) => {
      const { user } = ctx;
      const clerkId = user.clerkId;
      
      console.log(`🗑️ Starting account deletion for user: ${clerkId}`);
      
      // Find the user in the database
      const dbUser = await prisma.user.findUnique({
        where: { clerkId },
        select: { id: true, email: true, username: true },
      });
      
      if (!dbUser) {
        throw new Error('User not found');
      }
      
      const userId = dbUser.id;
      
      // Delete all user-related data in the correct order (respecting foreign key constraints)
      // Using a transaction to ensure atomicity
      await prisma.$transaction(async (tx) => {
        // 1. Delete notifications (both sent and received)
        await tx.notification.deleteMany({
          where: { OR: [{ userId }, { actorId: userId }] },
        });
        
        // 2. Delete messages sent by user
        await tx.message.deleteMany({
          where: { senderId: userId },
        });
        
        // 3. Delete chatroom memberships
        await tx.chatroomMember.deleteMany({
          where: { userId },
        });
        
        // 4. Delete comment reactions
        await tx.commentReaction.deleteMany({
          where: { userId },
        });
        
        // 5. Delete comments
        await tx.comment.deleteMany({
          where: { authorId: userId },
        });
        
        // 6. Delete likes
        await tx.like.deleteMany({
          where: { userId },
        });
        
        // 7. Delete bookmarks
        await tx.bookmark.deleteMany({
          where: { userId },
        });
        
        // 8. Delete list posts and lists
        await tx.listPost.deleteMany({
          where: { list: { userId } },
        });
        await tx.list.deleteMany({
          where: { userId },
        });
        
        // 9. Delete follows (both as follower and following)
        await tx.follow.deleteMany({
          where: { OR: [{ followerId: userId }, { followingId: userId }] },
        });
        
        // 10. Delete friend requests (both sent and received)
        await tx.friendRequest.deleteMany({
          where: { OR: [{ senderId: userId }, { receiverId: userId }] },
        });
        
        // 11. Delete friendships
        await tx.friendship.deleteMany({
          where: { OR: [{ userId }, { friendId: userId }] },
        });
        
        // 12. Delete user blocks (both as blocker and blocked)
        await tx.userBlock.deleteMany({
          where: { OR: [{ blockerId: userId }, { blockedId: userId }] },
        });
        
        // 13. Delete posts by the user
        // First delete all related data for user's posts
        const userPostIds = await tx.post.findMany({
          where: { authorId: userId },
          select: { id: true },
        });
        const postIds = userPostIds.map(p => p.id);
        
        if (postIds.length > 0) {
          await tx.comment.deleteMany({ where: { postId: { in: postIds } } });
          await tx.like.deleteMany({ where: { postId: { in: postIds } } });
          await tx.bookmark.deleteMany({ where: { postId: { in: postIds } } });
          await tx.listPost.deleteMany({ where: { postId: { in: postIds } } });
        }
        
        await tx.post.deleteMany({
          where: { authorId: userId },
        });
        
        // 14. Finally, delete the user
        await tx.user.delete({
          where: { id: userId },
        });
      });
      
      console.log(`✅ Successfully deleted account for user: ${clerkId}`);
      
      return {
        success: true,
        message: 'Account deleted successfully',
      };
    }),
});

// Export types for frontend (re-exported from schemas for backward compatibility)
export type User = z.infer<typeof UserSchema>;
export type CreateUserInput = z.infer<typeof CreateUserSchema>;
export type UpdateUserInput = z.infer<typeof UpdateUserSchema>; 