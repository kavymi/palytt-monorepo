import { z } from 'zod';
import { router, publicProcedure } from '../trpc.js';
import { prisma } from '../db.js';

// User model schemas
const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  username: z.string().min(1).max(50).nullable(),
  name: z.string().min(1).max(200).nullable(),
  bio: z.string().max(500).nullable(),
  profileImage: z.string().url().nullable(),
  website: z.string().url().nullable(),
  clerkId: z.string().min(1),
  followerCount: z.number().int().default(0),
  followingCount: z.number().int().default(0),
  postsCount: z.number().int().default(0),
  createdAt: z.string(),
  updatedAt: z.string(),
});

const CreateUserSchema = z.object({
  email: z.string().email(),
  username: z.string().min(1).max(50).nullable(),
  name: z.string().min(1).max(200).nullable(),
  bio: z.string().max(500).nullable(),
  profileImage: z.string().url().nullable(),
  website: z.string().url().nullable(),
  clerkId: z.string().min(1),
});

const UpdateUserSchema = z.object({
  username: z.string().min(1).max(50).nullable(),
  name: z.string().min(1).max(200).nullable(),
  bio: z.string().max(500).nullable(),
  profileImage: z.string().url().nullable(),
  website: z.string().url().nullable(),
});

export const usersRouter = router({
  /**
   * Create a new user
   */
  create: publicProcedure
    .input(CreateUserSchema)
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
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ input }) => {
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
    }),

  /**
   * Get user by Clerk ID
   */
  getByClerkId: publicProcedure
    .input(z.object({ clerkId: z.string().min(1) }))
    .query(async ({ input }) => {
      const user = await prisma.user.findUnique({
        where: { clerkId: input.clerkId },
      });
      
      if (!user) {
        throw new Error('User not found');
      }
      
      return {
        ...user,
        createdAt: user.createdAt.toISOString(),
        updatedAt: user.updatedAt.toISOString(),
      };
    }),

  /**
   * Update user by ID
   */
  update: publicProcedure
    .input(z.object({ 
      id: z.string().uuid(),
      data: UpdateUserSchema,
    }))
    .mutation(async ({ input }) => {
      const updatedUser = await prisma.user.update({
        where: { id: input.id },
        data: input.data,
      });
      
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
    .mutation(async ({ input }) => {
      const updatedUser = await prisma.user.update({
        where: { clerkId: input.clerkId },
        data: input.data,
      });
      
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
    .mutation(async ({ input }) => {
      const user = await prisma.user.upsert({
        where: { clerkId: input.clerkId },
        update: {
          email: input.email,
          username: input.username,
          name: input.name,
          bio: input.bio,
          profileImage: input.profileImage,
          website: input.website,
        },
        create: {
          email: input.email,
          username: input.username,
          name: input.name,
          bio: input.bio,
          profileImage: input.profileImage,
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
    .input(z.object({
      page: z.number().int().positive().default(1),
      limit: z.number().int().positive().max(100).default(10),
      search: z.string().optional(),
    }))
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
    .input(z.object({ clerkId: z.string().min(1) }))
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
    .input(z.object({ clerkId: z.string().min(1) }))
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
   * Alias for upsert - iOS app calls this endpoint name
   */
  upsertByClerkId: publicProcedure
    .input(CreateUserSchema)
    .mutation(async ({ input }) => {
      const user = await prisma.user.upsert({
        where: { clerkId: input.clerkId },
        update: {
          email: input.email,
          username: input.username,
          name: input.name,
          bio: input.bio,
          profileImage: input.profileImage,
          website: input.website,
        },
        create: {
          email: input.email,
          username: input.username,
          name: input.name,
          bio: input.bio,
          profileImage: input.profileImage,
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
});

// Export types for frontend
export type User = z.infer<typeof UserSchema>;
export type CreateUserInput = z.infer<typeof CreateUserSchema>;
export type UpdateUserInput = z.infer<typeof UpdateUserSchema>; 