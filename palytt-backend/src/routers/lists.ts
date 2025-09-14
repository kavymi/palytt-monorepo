import { router, protectedProcedure, publicProcedure } from '../trpc.js';
import { z } from 'zod';
import { prisma, ensureUser } from '../db.js';

// Input schemas (for future use)
// const ListSchema = z.object({
//   id: z.string().uuid(),
//   name: z.string(),
//   description: z.string().nullable(),
//   userId: z.string().uuid(),
//   isPrivate: z.boolean(),
//   coverImageUrl: z.string().url().nullable(),
//   createdAt: z.string(),
//   updatedAt: z.string(),
// });

export const listsRouter = router({
  /**
   * Create a new list
   */
  create: protectedProcedure
    .input(
      z.object({
        name: z.string().min(1).max(100),
        description: z.string().optional(),
        isPrivate: z.boolean(),
        userId: z.string(), // Clerk user ID
      })
    )
    .mutation(async ({ input, ctx }) => {
      const { user } = ctx;
      
      // Ensure user exists in database
      const dbUser = await ensureUser(user.clerkId, user.clerkId + '@clerk.local');
      
      // Create the list
      const list = await prisma.list.create({
        data: {
          name: input.name,
          description: input.description || null,
          isPrivate: input.isPrivate,
          userId: dbUser.id,
        },
      });
      
      return {
        listId: list.id,
        success: true,
      };
    }),

  /**
   * Get user lists
   */
  getUserLists: protectedProcedure
    .input(
      z.object({
        userId: z.string(), // Clerk user ID
      })
    )
    .query(async ({ input, ctx }) => {
      const { user } = ctx;
      
      // Ensure user exists in database
      const dbUser = await ensureUser(user.clerkId, user.clerkId + '@clerk.local');
      
      const lists = await prisma.list.findMany({
        where: {
          userId: dbUser.id,
        },
        include: {
          listPosts: {
            include: {
              post: {
                include: {
                  author: true,
                },
              },
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
      });
      
      return lists.map((list) => ({
        _id: list.id,
        name: list.name,
        description: list.description,
        isPrivate: list.isPrivate,
        userId: input.userId,
        postIds: list.listPosts.map(lp => lp.postId),
        createdAt: Math.floor(list.createdAt.getTime() / 1000),
        updatedAt: Math.floor(list.updatedAt.getTime() / 1000),
      }));
    }),

  /**
   * Get a specific list with posts
   */
  getById: publicProcedure
    .input(
      z.object({
        listId: z.string().uuid(),
      })
    )
    .query(async ({ input, ctx }) => {
      const list = await prisma.list.findFirst({
        where: {
          id: input.listId,
          // If the list is private, only allow the owner to see it
          ...(ctx.user ? {} : { isPrivate: false }),
        },
        include: {
          user: true,
          listPosts: {
            include: {
              post: {
                include: {
                  author: true,
                  likes: ctx.user
                    ? {
                        where: {
                          user: {
                            clerkId: ctx.user.clerkId,
                          },
                        },
                      }
                    : false,
                  bookmarks: ctx.user
                    ? {
                        where: {
                          user: {
                            clerkId: ctx.user.clerkId,
                          },
                        },
                      }
                    : false,
                },
              },
            },
            orderBy: {
              addedAt: 'desc',
            },
          },
        },
      });

      if (!list) {
        throw new Error('List not found');
      }

      // If it's a private list, only allow the owner to access it
      if (list.isPrivate && (!ctx.user || list.user.clerkId !== ctx.user.clerkId)) {
        throw new Error('Access denied');
      }

      return {
        _id: list.id,
        name: list.name,
        description: list.description,
        isPrivate: list.isPrivate,
        userId: list.user.clerkId,
        posts: list.listPosts.map(lp => ({
          id: lp.post.id,
          userId: lp.post.userId,
          authorClerkId: lp.post.author.clerkId,
          title: lp.post.title,
          caption: lp.post.caption,
          mediaUrls: lp.post.mediaUrls,
          rating: lp.post.rating,
          menuItems: lp.post.menuItems,
          createdAt: lp.post.createdAt.toISOString(),
          updatedAt: lp.post.updatedAt.toISOString(),
          likesCount: lp.post.likesCount,
          commentsCount: lp.post.commentsCount,
          savesCount: lp.post.savesCount,
          viewsCount: lp.post.viewsCount,
          isLiked: lp.post.likes.length > 0,
          isSaved: lp.post.bookmarks.length > 0,
          isPublic: lp.post.isPublic,
          isDeleted: lp.post.isDeleted,
          location: lp.post.locationName ? {
            id: lp.post.id, // Using post id as location id for now
            name: lp.post.locationName,
            latitude: lp.post.locationLatitude || 0,
            longitude: lp.post.locationLongitude || 0,
            address: lp.post.locationAddress || '',
            city: lp.post.locationCity || '',
            state: lp.post.locationState,
            country: lp.post.locationCountry || '',
            postalCode: lp.post.locationPostalCode,
          } : null,
        })),
        createdAt: Math.floor(list.createdAt.getTime() / 1000),
        updatedAt: Math.floor(list.updatedAt.getTime() / 1000),
      };
    }),

  /**
   * Add a post to a list
   */
  addPost: protectedProcedure
    .input(
      z.object({
        listId: z.string().uuid(),
        postId: z.string().uuid(),
      })
    )
    .mutation(async ({ input, ctx }) => {
      const { user } = ctx;
      
      // Ensure user exists in database
      const dbUser = await ensureUser(user.clerkId, user.clerkId + '@clerk.local');
      
      // Check if list exists and user owns it
      const list = await prisma.list.findFirst({
        where: {
          id: input.listId,
          userId: dbUser.id,
        },
      });

      if (!list) {
        throw new Error('List not found or access denied');
      }

      // Check if post exists
      const post = await prisma.post.findUnique({
        where: {
          id: input.postId,
        },
      });

      if (!post) {
        throw new Error('Post not found');
      }

      // Add post to list (ignore if already exists)
      await prisma.listPost.upsert({
        where: {
          listId_postId: {
            listId: input.listId,
            postId: input.postId,
          },
        },
        create: {
          listId: input.listId,
          postId: input.postId,
        },
        update: {},
      });

      return {
        success: true,
      };
    }),

  /**
   * Remove a post from a list
   */
  removePost: protectedProcedure
    .input(
      z.object({
        listId: z.string().uuid(),
        postId: z.string().uuid(),
      })
    )
    .mutation(async ({ input, ctx }) => {
      const { user } = ctx;
      
      // Ensure user exists in database
      const dbUser = await ensureUser(user.clerkId, user.clerkId + '@clerk.local');
      
      // Check if list exists and user owns it
      const list = await prisma.list.findFirst({
        where: {
          id: input.listId,
          userId: dbUser.id,
        },
      });

      if (!list) {
        throw new Error('List not found or access denied');
      }

      // Remove post from list
      await prisma.listPost.deleteMany({
        where: {
          listId: input.listId,
          postId: input.postId,
        },
      });

      return {
        success: true,
      };
    }),

  /**
   * Update a list
   */
  update: protectedProcedure
    .input(
      z.object({
        listId: z.string().uuid(),
        name: z.string().min(1).max(100).optional(),
        description: z.string().optional(),
        isPrivate: z.boolean().optional(),
      })
    )
    .mutation(async ({ input, ctx }) => {
      const { user } = ctx;
      
      // Ensure user exists in database
      const dbUser = await ensureUser(user.clerkId, user.clerkId + '@clerk.local');
      
      // Check if list exists and user owns it
      const list = await prisma.list.findFirst({
        where: {
          id: input.listId,
          userId: dbUser.id,
        },
      });

      if (!list) {
        throw new Error('List not found or access denied');
      }

      // Update list
      const updatedList = await prisma.list.update({
        where: {
          id: input.listId,
        },
        data: {
          ...(input.name && { name: input.name }),
          ...(input.description !== undefined && { description: input.description || null }),
          ...(input.isPrivate !== undefined && { isPrivate: input.isPrivate }),
        },
      });

      return {
        success: true,
        list: {
          _id: updatedList.id,
          name: updatedList.name,
          description: updatedList.description,
          isPrivate: updatedList.isPrivate,
          userId: user.clerkId,
          createdAt: Math.floor(updatedList.createdAt.getTime() / 1000),
          updatedAt: Math.floor(updatedList.updatedAt.getTime() / 1000),
        },
      };
    }),

  /**
   * Delete a list
   */
  delete: protectedProcedure
    .input(
      z.object({
        listId: z.string().uuid(),
      })
    )
    .mutation(async ({ input, ctx }) => {
      const { user } = ctx;
      
      // Ensure user exists in database
      const dbUser = await ensureUser(user.clerkId, user.clerkId + '@clerk.local');
      
      // Check if list exists and user owns it
      const list = await prisma.list.findFirst({
        where: {
          id: input.listId,
          userId: dbUser.id,
        },
      });

      if (!list) {
        throw new Error('List not found or access denied');
      }

      // Delete list (this will cascade delete list posts)
      await prisma.list.delete({
        where: {
          id: input.listId,
        },
      });

      return {
        success: true,
      };
    }),
});
