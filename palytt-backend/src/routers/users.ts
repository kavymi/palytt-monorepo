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
});

// Export types for frontend
export type User = z.infer<typeof UserSchema>;
export type CreateUserInput = z.infer<typeof CreateUserSchema>;
export type UpdateUserInput = z.infer<typeof UpdateUserSchema>; 