import { router, protectedProcedure, publicProcedure } from '../trpc.js';
import { z } from 'zod';
import { prisma, ensureUser } from '../db.js';
import { createPostLikeNotification } from '../services/notificationService.js';

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

// Location sub-schema (for future use)
// const LocationSchema = z.object({
//   id: z.string().uuid(),
//   name: z.string().nullable(),
//   latitude: z.number(),
//   longitude: z.number(),
//   address: z.string(),
//   city: z.string(),
//   state: z.string().nullable(),
//   country: z.string(),
//   postalCode: z.string().nullable(),
// });

// Input schemas (for future use)
// const PostSchema = z.object({
//   id: z.string().uuid(),
//   userId: z.string().uuid(),
//   authorClerkId: z.string(),
//   title: z.string().nullable(),
//   caption: z.string(),
//   mediaUrls: z.array(z.string().url()),
//   location: LocationSchema.nullable(),
//   menuItems: z.array(z.string()),
//   rating: z.number().min(1).max(5).nullable(),
//   createdAt: z.string(),
//   updatedAt: z.string(),
//   likesCount: z.number().int().default(0),
//   commentsCount: z.number().int().default(0),
//   savesCount: z.number().int().default(0),
//   viewsCount: z.number().int().default(0),
//   isLiked: z.boolean().default(false),
//   isSaved: z.boolean().default(false),
//   isPublic: z.boolean().default(true),
//   isDeleted: z.boolean().default(false),
// });

// const CommentSchema = z.object({
//   id: z.string().uuid(),
//   postId: z.string().uuid(),
//   authorId: z.string().uuid(),
//   authorClerkId: z.string(),
//   content: z.string(),
//   createdAt: z.string(),
//   updatedAt: z.string(),
// });

export const postsRouter = router({
  /**
   * Create a new post
   */
  create: protectedProcedure
    .input(
      z.object({
        shopName: z.string(),
        foodItem: z.string(),
        description: z.string().optional(),
        rating: z.number().min(1).max(5),
        imageUrl: z.string().url().optional(),
        imageUrls: z.array(z.string().url()),
        tags: z.array(z.string()),
        location: z.object({
          latitude: z.number(),
          longitude: z.number(),
          address: z.string(),
          name: z.string().optional(),
        }).optional(),
        isPublic: z.boolean().default(true),
      })
    )
    .mutation(async ({ input, ctx }) => {
      const { user } = ctx;
      
      // Ensure user exists in database
      const dbUser = await ensureUser(user.clerkId, user.clerkId + '@clerk.local'); // Using temporary email
      
      // Map frontend fields to backend fields
      const mediaUrls = [];
      if (input.imageUrl) {
        mediaUrls.push(input.imageUrl);
      }
      if (input.imageUrls && input.imageUrls.length > 0) {
        mediaUrls.push(...input.imageUrls);
      }
      
      // Create the post
      const post = await prisma.post.create({
        data: {
          userId: dbUser.id,
          title: input.shopName,  // Using shopName as title
          caption: input.description || input.foodItem,  // Using description or foodItem as caption
          mediaUrls: mediaUrls,
          rating: input.rating,
          menuItems: [input.foodItem],  // Store foodItem in menuItems array
          locationName: input.location?.name || input.location?.address,
          locationAddress: input.location?.address,
          locationCity: null,
          locationState: null,
          locationCountry: null,
          locationPostalCode: null,
          locationLatitude: input.location?.latitude,
          locationLongitude: input.location?.longitude,
          isPublic: input.isPublic,
        },
        include: {
          author: true,
        },
      });
      
      // Update user's post count and streak
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const userStreak = await prisma.user.findUnique({
        where: { id: dbUser.id },
        select: {
          currentStreak: true,
          longestStreak: true,
          lastPostDate: true,
        },
      });
      
      let newStreak = 1;
      let newLongestStreak = userStreak?.longestStreak || 0;
      
      if (userStreak?.lastPostDate) {
        const lastPost = new Date(userStreak.lastPostDate);
        lastPost.setHours(0, 0, 0, 0);
        
        const daysDiff = Math.floor((today.getTime() - lastPost.getTime()) / (1000 * 60 * 60 * 24));
        
        if (daysDiff === 0) {
          // Same day - keep current streak
          newStreak = userStreak.currentStreak || 1;
        } else if (daysDiff === 1) {
          // Consecutive day - increment streak
          newStreak = (userStreak.currentStreak || 0) + 1;
        }
        // If daysDiff > 1, streak resets to 1
      }
      
      // Update longest streak if current is higher
      if (newStreak > newLongestStreak) {
        newLongestStreak = newStreak;
      }
      
      await prisma.user.update({
        where: { id: dbUser.id },
        data: {
          postsCount: {
            increment: 1,
          },
          currentStreak: newStreak,
          longestStreak: newLongestStreak,
          lastPostDate: new Date(),
        },
      });
      
      // Transform to match frontend schema
      const transformedPost = {
        id: post.id,
        authorId: post.userId,
        authorClerkId: post.author.clerkId,
        shopId: null,
        shopName: post.title || '',  // Map title back to shopName
        foodItem: post.menuItems[0] || '',  // Map first menuItem back to foodItem
        description: post.caption,
        rating: post.rating || 5,
        imageUrl: post.mediaUrls[0] || null,
        imageUrls: post.mediaUrls,
        tags: input.tags,
        location: input.location,
        isPublic: post.isPublic,
        likesCount: post.likesCount,
        commentsCount: post.commentsCount,
        createdAt: post.createdAt.toISOString(),
        updatedAt: post.updatedAt.toISOString(),
      };
      
      return {
        success: true,
        post: transformedPost,
      };
    }),

  /**
   * Get all posts (with pagination)
   */
  list: publicProcedure
    .input(
      z.object({
        page: z.number().int().positive().default(1),
        limit: z.number().int().positive().max(100).default(20),
      })
    )
    .query(async ({ input, ctx }) => {
      const skip = (input.page - 1) * input.limit;
      
      const [posts, totalCount] = await Promise.all([
        prisma.post.findMany({
          where: {
            isPublic: true,
            isDeleted: false,
          },
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
          orderBy: {
            createdAt: 'desc',
          },
          skip,
          take: input.limit,
        }),
        prisma.post.count({
          where: {
            isPublic: true,
            isDeleted: false,
          },
        }),
      ]);
      
      // Transform posts to match frontend schema
      const transformedPosts = posts.map((post: any) => ({
        id: post.id,
        authorId: post.userId,
        authorClerkId: post.author.clerkId,
        shopId: null,
        shopName: post.title || '',  // Map title to shopName
        foodItem: post.menuItems?.[0] || '',  // Map first menuItem to foodItem
        description: post.caption,
        rating: post.rating || 5,
        imageUrl: post.mediaUrls?.[0] || null,
        imageUrls: post.mediaUrls || [],
        tags: [],  // TODO: Add tags to database schema
        location: post.locationName && post.locationLatitude && post.locationLongitude
          ? {
              latitude: post.locationLatitude,
              longitude: post.locationLongitude,
              address: post.locationAddress || '',
              name: post.locationName,
            }
          : null,
        isPublic: post.isPublic,
        likesCount: post.likesCount,
        commentsCount: post.commentsCount,
        createdAt: post.createdAt.toISOString(),
        updatedAt: post.updatedAt.toISOString(),
      }));
      
      return {
        posts: transformedPosts,
        pagination: {
          page: input.page,
          limit: input.limit,
          total: totalCount,
          totalPages: Math.ceil(totalCount / input.limit),
        },
      };
    }),

  /**
   * Get a single post by ID
   */
  getById: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ input, ctx }) => {
      const post = await prisma.post.findUnique({
        where: {
          id: input.id,
          isDeleted: false,
        },
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
      });
      
      if (!post) {
        throw new Error('Post not found');
      }
      
      if (!post.isPublic && post.author.clerkId !== ctx.user?.clerkId) {
        throw new Error('This post is private');
      }
      
      // Transform to match frontend schema
      return {
        id: post.id,
        authorId: post.userId,
        authorClerkId: post.author.clerkId,
        shopId: null,
        shopName: post.title || '',  // Map title to shopName
        foodItem: post.menuItems?.[0] || '',  // Map first menuItem to foodItem
        description: post.caption,
        rating: post.rating || 5,
        imageUrl: post.mediaUrls?.[0] || null,
        imageUrls: post.mediaUrls || [],
        tags: [],  // TODO: Add tags to database schema
        location: post.locationName && post.locationLatitude && post.locationLongitude
          ? {
              latitude: post.locationLatitude,
              longitude: post.locationLongitude,
              address: post.locationAddress || '',
              name: post.locationName,
            }
          : null,
        isPublic: post.isPublic,
        likesCount: post.likesCount,
        commentsCount: post.commentsCount,
        createdAt: post.createdAt.toISOString(),
        updatedAt: post.updatedAt.toISOString(),
      };
    }),

  /**
   * Like/unlike a post
   */
  toggleLike: protectedProcedure
    .input(z.object({ postId: z.string().uuid() }))
    .mutation(async ({ input, ctx }) => {
      const dbUser = await ensureUser(ctx.user.clerkId, ctx.user.clerkId + '@clerk.local');
      
      // Check if post exists
      const post = await prisma.post.findUnique({
        where: {
          id: input.postId,
          isDeleted: false,
        },
      });
      
      if (!post) {
        throw new Error('Post not found');
      }
      
      if (!post.isPublic) {
        throw new Error('Cannot like a private post');
      }
      
      // Check if already liked
      const existingLike = await prisma.like.findUnique({
        where: {
          postId_userId: {
            postId: input.postId,
            userId: dbUser.id,
          },
        },
      });
      
      let isLiked: boolean;
      
      if (existingLike) {
        // Unlike
        await prisma.$transaction([
          prisma.like.delete({
            where: {
              id: existingLike.id,
            },
          }),
          prisma.post.update({
            where: {
              id: input.postId,
            },
            data: {
              likesCount: {
                decrement: 1,
              },
            },
          }),
        ]);
        isLiked = false;
      } else {
        // Like
        await prisma.$transaction([
          prisma.like.create({
            data: {
              postId: input.postId,
              userId: dbUser.id,
            },
          }),
          prisma.post.update({
            where: {
              id: input.postId,
            },
            data: {
              likesCount: {
                increment: 1,
              },
            },
          }),
        ]);
        isLiked = true;
        
        // Create notification for post like
        await createPostLikeNotification(input.postId, dbUser.clerkId);
      }
      
      return {
        success: true,
        isLiked,
        likesCount: post.likesCount + (isLiked ? 1 : -1),
      };
    }),

  /**
   * Add a comment to a post
   */
  addComment: protectedProcedure
    .input(
      z.object({
        postId: z.string().uuid(),
        comment: z.object({
          content: z.string().min(1),
        }),
      })
    )
    .mutation(async ({ input, ctx }) => {
      const dbUser = await ensureUser(ctx.user.clerkId, ctx.user.clerkId + '@clerk.local');
      
      // Check if post exists
      const post = await prisma.post.findUnique({
        where: {
          id: input.postId,
          isDeleted: false,
        },
      });
      
      if (!post) {
        throw new Error('Post not found');
      }
      
      if (!post.isPublic) {
        throw new Error('Cannot comment on a private post');
      }
      
      // Create comment and update count in a transaction
      const [comment, updatedPost] = await prisma.$transaction([
        prisma.comment.create({
          data: {
            postId: input.postId,
            authorId: dbUser.id,
            content: input.comment.content,
          },
          include: {
            author: true,
          },
        }),
        prisma.post.update({
          where: {
            id: input.postId,
          },
          data: {
            commentsCount: {
              increment: 1,
            },
          },
        }),
      ]);
      
      return {
        success: true,
        comment: {
          id: comment.id,
          postId: comment.postId,
          authorId: comment.authorId,
          authorClerkId: comment.author.clerkId,
          content: comment.content,
          createdAt: comment.createdAt.toISOString(),
          updatedAt: comment.updatedAt.toISOString(),
        },
        commentsCount: updatedPost.commentsCount,
      };
    }),

  /**
   * Get comments for a post
   */
  getComments: publicProcedure
    .input(
      z.object({
        postId: z.string().uuid(),
        page: z.number().int().positive().default(1),
        limit: z.number().int().positive().max(50).default(20),
      })
    )
    .query(async ({ input }) => {
      const skip = (input.page - 1) * input.limit;
      
      const [comments, totalCount] = await Promise.all([
        prisma.comment.findMany({
          where: {
            postId: input.postId,
          },
          include: {
            author: true,
          },
          orderBy: {
            createdAt: 'desc',
          },
          skip,
          take: input.limit,
        }),
        prisma.comment.count({
          where: {
            postId: input.postId,
          },
        }),
      ]);
      
      return {
        comments: comments.map((comment: any) => ({
          id: comment.id,
          postId: comment.postId,
          authorId: comment.authorId,
          authorClerkId: comment.author.clerkId,
          content: comment.content,
          createdAt: comment.createdAt.toISOString(),
          updatedAt: comment.updatedAt.toISOString(),
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
   * Bookmark/unbookmark a post
   */
  toggleBookmark: protectedProcedure
    .input(z.object({ postId: z.string().uuid() }))
    .mutation(async ({ input, ctx }) => {
      const dbUser = await ensureUser(ctx.user.clerkId, ctx.user.clerkId + '@clerk.local');
      
      // Check if post exists
      const post = await prisma.post.findUnique({
        where: {
          id: input.postId,
          isDeleted: false,
        },
      });
      
      if (!post) {
        throw new Error('Post not found');
      }
      
      if (!post.isPublic) {
        throw new Error('Cannot bookmark a private post');
      }
      
      // Check if already bookmarked
      const existingBookmark = await prisma.bookmark.findUnique({
        where: {
          postId_userId: {
            postId: input.postId,
            userId: dbUser.id,
          },
        },
      });
      
      let isBookmarked: boolean;
      
      if (existingBookmark) {
        // Remove bookmark
        await prisma.$transaction([
          prisma.bookmark.delete({
            where: {
              id: existingBookmark.id,
            },
          }),
          prisma.post.update({
            where: {
              id: input.postId,
            },
            data: {
              savesCount: {
                decrement: 1,
              },
            },
          }),
        ]);
        isBookmarked = false;
      } else {
        // Add bookmark
        await prisma.$transaction([
          prisma.bookmark.create({
            data: {
              postId: input.postId,
              userId: dbUser.id,
            },
          }),
          prisma.post.update({
            where: {
              id: input.postId,
            },
            data: {
              savesCount: {
                increment: 1,
              },
            },
          }),
        ]);
        isBookmarked = true;
      }
      
      return {
        success: true,
        isBookmarked,
        bookmarksCount: post.savesCount + (isBookmarked ? 1 : -1),
      };
    }),

  /**
   * Get posts by a specific user (by clerkId)
   */
  getByUser: publicProcedure
    .input(
      z.object({
        userId: z.string(), // clerkId
        limit: z.number().int().positive().max(100).default(20),
        cursor: z.string().optional(),
      })
    )
    .query(async ({ input, ctx }) => {
      const { userId: clerkId, limit, cursor } = input;
      
      // Get user's UUID from clerk ID
      const user = await prisma.user.findUnique({
        where: { clerkId },
        select: { id: true },
      });
      
      if (!user) {
        return [];
      }
      
      // Get current user's UUID for checking likes/bookmarks
      let currentUserUUID: string | null = null;
      if (ctx.user?.clerkId) {
        const currentUser = await prisma.user.findUnique({
          where: { clerkId: ctx.user.clerkId },
          select: { id: true },
        });
        currentUserUUID = currentUser?.id || null;
      }
      
      const posts = await prisma.post.findMany({
        where: {
          userId: user.id,
          isDeleted: false,
          OR: [
            { isPublic: true },
            // Include private posts if viewing own profile
            ...(ctx.user?.clerkId === clerkId ? [{ isPublic: false }] : []),
          ],
        },
        include: {
          author: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
            },
          },
          likes: currentUserUUID
            ? {
                where: {
                  userId: currentUserUUID,
                },
              }
            : false,
          bookmarks: currentUserUUID
            ? {
                where: {
                  userId: currentUserUUID,
                },
              }
            : false,
        },
        orderBy: {
          createdAt: 'desc',
        },
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
      });
      
      // Check if there are more posts
      let nextCursor: string | null = null;
      if (posts.length > limit) {
        const nextItem = posts.pop();
        nextCursor = nextItem!.id;
      }
      
      // Transform posts to match frontend schema
      return posts.map((post: any) => ({
        id: post.id,
        authorId: post.userId,
        authorClerkId: post.author.clerkId,
        authorDisplayName: post.author.name || post.author.username,
        authorUsername: post.author.username,
        authorAvatarUrl: post.author.profileImage,
        shopId: null,
        shopName: post.title || '',
        foodItem: post.menuItems?.[0] || '',
        description: post.caption,
        rating: post.rating || null,
        imageUrl: post.mediaUrls?.[0] || null,
        imageUrls: post.mediaUrls || [],
        tags: [],
        location: post.locationName && post.locationLatitude && post.locationLongitude
          ? {
              latitude: post.locationLatitude,
              longitude: post.locationLongitude,
              address: post.locationAddress || '',
              name: post.locationName,
            }
          : null,
        isPublic: post.isPublic,
        likesCount: post.likesCount,
        commentsCount: post.commentsCount,
        isLiked: Array.isArray(post.likes) && post.likes.length > 0,
        isBookmarked: Array.isArray(post.bookmarks) && post.bookmarks.length > 0,
        createdAt: post.createdAt.toISOString(),
        updatedAt: post.updatedAt.toISOString(),
      }));
    }),

  /**
   * Get recent posts (alias for list - for iOS app compatibility)
   */
  getRecentPosts: publicProcedure
    .input(
      z.object({
        page: z.number().int().positive().default(1),
        limit: z.number().int().positive().max(100).default(20),
      })
    )
    .query(async ({ input, ctx }) => {
      // Reuse the logic from the list procedure
      const skip = (input.page - 1) * input.limit;
      
      const [posts, totalCount] = await Promise.all([
        prisma.post.findMany({
          where: {
            isPublic: true,
            isDeleted: false,
          },
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
          orderBy: {
            createdAt: 'desc',
          },
          skip,
          take: input.limit,
        }),
        prisma.post.count({
          where: {
            isPublic: true,
            isDeleted: false,
          },
        }),
      ]);
      
      // Transform posts to match frontend schema
      const transformedPosts = posts.map((post: any) => ({
        id: post.id,
        authorId: post.userId,
        authorClerkId: post.author.clerkId,
        shopId: null,
        shopName: post.title || '',  // Map title to shopName
        foodItem: post.menuItems?.[0] || '',  // Map first menuItem to foodItem
        description: post.caption,
        rating: post.rating || 5,
        imageUrl: post.mediaUrls?.[0] || null,
        imageUrls: post.mediaUrls || [],
        tags: [],  // TODO: Add tags to database schema
        location: post.locationName && post.locationLatitude && post.locationLongitude
          ? {
              latitude: post.locationLatitude,
              longitude: post.locationLongitude,
              address: post.locationAddress || '',
              name: post.locationName,
            }
          : null,
        isPublic: post.isPublic,
        likesCount: post.likesCount,
        commentsCount: post.commentsCount,
        createdAt: post.createdAt.toISOString(),
        updatedAt: post.updatedAt.toISOString(),
      }));
      
      return {
        posts: transformedPosts,
        pagination: {
          page: input.page,
          limit: input.limit,
          total: totalCount,
          totalPages: Math.ceil(totalCount / input.limit),
        },
      };
    }),

  /**
   * Get personalized feed for a user
   */
  getPersonalizedFeed: publicProcedure
    .input(
      z.object({
        userId: z.string(),
        userLatitude: z.number(),
        userLongitude: z.number(),
        limit: z.number().int().positive().max(100).default(20),
        cursor: z.string().optional(),
      })
    )
    .query(async ({ input, ctx }) => {
      // For now, return the same as recent posts but potentially filtered by location
      // TODO: Implement actual personalization algorithm
      const [posts, totalCount] = await Promise.all([
        prisma.post.findMany({
          where: {
            isPublic: true,
            isDeleted: false,
          },
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
          orderBy: {
            createdAt: 'desc',
          },
          take: input.limit,
        }),
        prisma.post.count({
          where: {
            isPublic: true,
            isDeleted: false,
          },
        }),
      ]);
      
      // Transform posts to match frontend schema
      const transformedPosts = posts.map((post: any) => ({
        id: post.id,
        authorId: post.userId,
        authorClerkId: post.author.clerkId,
        shopId: null,
        shopName: post.title || '',  // Map title to shopName
        foodItem: post.menuItems?.[0] || '',  // Map first menuItem to foodItem
        description: post.caption,
        rating: post.rating || 5,
        imageUrl: post.mediaUrls?.[0] || null,
        imageUrls: post.mediaUrls || [],
        tags: [],  // TODO: Add tags to database schema
        location: post.locationName && post.locationLatitude && post.locationLongitude
          ? {
              latitude: post.locationLatitude,
              longitude: post.locationLongitude,
              address: post.locationAddress || '',
              name: post.locationName,
            }
          : null,
        isPublic: post.isPublic,
        likesCount: post.likesCount,
        commentsCount: post.commentsCount,
        createdAt: post.createdAt.toISOString(),
        updatedAt: post.updatedAt.toISOString(),
      }));
      
      return {
        posts: transformedPosts,
        hasMore: posts.length === input.limit,
        nextCursor: posts.length === input.limit ? posts[posts.length - 1].id : null,
        totalCount, // Include total count for pagination
      };
    }),

  /**
   * Get posts from friends only
   * This is the primary feed for the home view - shows only posts from accepted friends
   */
  getFriendsPosts: protectedProcedure
    .input(
      z.object({
        limit: z.number().int().positive().max(50).default(20),
        cursor: z.string().optional(),
      })
    )
    .query(async ({ input, ctx }) => {
      const { limit, cursor } = input;
      
      // Get user's UUID from clerk ID
      const userUUID = await getUserIdFromClerkId(ctx.user.clerkId);
      
      // Get accepted friends (from both directions of friendship)
      const friendships = await prisma.friend.findMany({
        where: {
          OR: [
            { senderId: userUUID, status: 'ACCEPTED' },
            { receiverId: userUUID, status: 'ACCEPTED' },
          ],
        },
        select: {
          senderId: true,
          receiverId: true,
        },
      });
      
      // Extract friend IDs (the other person in each friendship)
      const friendIds = friendships.map((f) =>
        f.senderId === userUUID ? f.receiverId : f.senderId
      );
      
      // If user has no friends, return empty result
      if (friendIds.length === 0) {
        return {
          posts: [],
          hasMore: false,
          nextCursor: null,
          friendsCount: 0,
        };
      }
      
      // Get posts from friends only
      const posts = await prisma.post.findMany({
        where: {
          userId: { in: friendIds },
          isPublic: true,
          isDeleted: false,
        },
        include: {
          author: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
            },
          },
          likes: {
            where: {
              userId: userUUID,
            },
          },
          bookmarks: {
            where: {
              userId: userUUID,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
      });
      
      // Check if there are more posts
      let nextCursor: string | null = null;
      if (posts.length > limit) {
        const nextItem = posts.pop();
        nextCursor = nextItem!.id;
      }
      
      // Transform posts to match frontend schema
      const transformedPosts = posts.map((post: any) => ({
        id: post.id,
        authorId: post.userId,
        authorClerkId: post.author.clerkId,
        authorDisplayName: post.author.name || post.author.username,
        authorUsername: post.author.username,
        authorAvatarUrl: post.author.profileImage,
        shopId: null,
        shopName: post.title || '',
        foodItem: post.menuItems?.[0] || '',
        description: post.caption,
        rating: post.rating || null,
        imageUrl: post.mediaUrls?.[0] || null,
        imageUrls: post.mediaUrls || [],
        tags: [],
        location: post.locationName && post.locationLatitude && post.locationLongitude
          ? {
              latitude: post.locationLatitude,
              longitude: post.locationLongitude,
              address: post.locationAddress || '',
              name: post.locationName,
            }
          : null,
        isPublic: post.isPublic,
        likesCount: post.likesCount,
        commentsCount: post.commentsCount,
        isLiked: post.likes.length > 0,
        isBookmarked: post.bookmarks.length > 0,
        createdAt: post.createdAt.toISOString(),
        updatedAt: post.updatedAt.toISOString(),
      }));
      
      return {
        posts: transformedPosts,
        hasMore: nextCursor !== null,
        nextCursor,
        friendsCount: friendIds.length,
      };
    }),

  /**
   * Get user's bookmarked posts
   */
  getBookmarks: protectedProcedure
    .input(
      z.object({
        page: z.number().int().positive().default(1),
        limit: z.number().int().positive().max(100).default(20),
      })
    )
    .query(async ({ input, ctx }) => {
      const dbUser = await ensureUser(ctx.user.clerkId, ctx.user.clerkId + '@clerk.local');
      const skip = (input.page - 1) * input.limit;
      
      const [bookmarks, totalCount] = await Promise.all([
        prisma.bookmark.findMany({
          where: {
            userId: dbUser.id,
          },
          include: {
            post: {
              include: {
                author: true,
                likes: {
                  where: {
                    userId: dbUser.id,
                  },
                },
              },
            },
          },
          orderBy: {
            createdAt: 'desc',
          },
          skip,
          take: input.limit,
        }),
        prisma.bookmark.count({
          where: {
            userId: dbUser.id,
          },
        }),
      ]);
      
      // Transform posts
      const posts = bookmarks.map((bookmark: any) => {
        const post = bookmark.post;
        return {
          id: post.id,
          authorId: post.userId,
          authorClerkId: post.author.clerkId,
          shopId: null,
          shopName: post.title || '',  // Map title to shopName
          foodItem: post.menuItems?.[0] || '',  // Map first menuItem to foodItem
          description: post.caption,
          rating: post.rating || 5,
          imageUrl: post.mediaUrls?.[0] || null,
          imageUrls: post.mediaUrls || [],
          tags: [],  // TODO: Add tags to database schema
          location: post.locationName && post.locationLatitude && post.locationLongitude
            ? {
                latitude: post.locationLatitude,
                longitude: post.locationLongitude,
                address: post.locationAddress || '',
                name: post.locationName,
              }
            : null,
          isPublic: post.isPublic,
          likesCount: post.likesCount,
          commentsCount: post.commentsCount,
          createdAt: post.createdAt.toISOString(),
          updatedAt: post.updatedAt.toISOString(),
        };
      });
      
      return {
        posts,
        pagination: {
          page: input.page,
          limit: input.limit,
          total: totalCount,
          totalPages: Math.ceil(totalCount / input.limit),
        },
      };
    }),

  /**
   * Get recent comments for a post (latest 2)
   */
  getRecentComments: publicProcedure
    .input(
      z.object({
        postId: z.string().uuid(),
        limit: z.number().int().positive().max(10).default(2),
      })
    )
    .query(async ({ input }) => {
      const comments = await prisma.comment.findMany({
        where: {
          postId: input.postId,
        },
        include: {
          author: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        take: input.limit,
      });
      
      return {
        comments: comments.map((comment: any) => ({
          id: comment.id,
          postId: comment.postId,
          authorId: comment.authorId,
          authorClerkId: comment.author.clerkId,
          content: comment.content,
          createdAt: comment.createdAt.toISOString(),
          updatedAt: comment.updatedAt.toISOString(),
          author: {
            _id: comment.author.id,
            clerkId: comment.author.clerkId,
            username: comment.author.username,
            displayName: comment.author.name,
            firstName: comment.author.name?.split(' ')[0],
            lastName: comment.author.name?.split(' ').slice(1).join(' '),
            avatarUrl: comment.author.profileImage,
          },
        })),
      };
    }),

  /**
   * Get users who liked a post
   */
  getPostLikes: publicProcedure
    .input(
      z.object({
        postId: z.string().uuid(),
        limit: z.number().int().positive().max(100).default(20),
        cursor: z.string().optional(),
      })
    )
    .query(async ({ input }) => {
      const { postId, limit, cursor } = input;
      
      const likes = await prisma.like.findMany({
        where: {
          postId,
        },
        include: {
          user: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
      });

      let nextCursor: typeof cursor | undefined = undefined;
      if (likes.length > limit) {
        const nextItem = likes.pop();
        nextCursor = nextItem!.id;
      }
      
      return {
        likes: likes.map((like: any) => ({
          id: like.id,
          postId: like.postId,
          userId: like.userId,
          createdAt: like.createdAt.toISOString(),
          user: {
            _id: like.user.id,
            clerkId: like.user.clerkId,
            username: like.user.username,
            displayName: like.user.name,
            firstName: like.user.name?.split(' ')[0],
            lastName: like.user.name?.split(' ').slice(1).join(' '),
            email: '', // Not needed for likes display
            avatarUrl: like.user.profileImage,
          },
        })),
        nextCursor,
      };
    }),
}); 