import { z } from 'zod';
import { router, publicProcedure, protectedProcedure, type Context } from '../trpc.js';
import { prisma, ensureUser } from '../db.js';
import { createPostCommentNotification } from '../services/notificationService.js';

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

// Helper function to get reaction counts for a comment
async function getReactionCounts(commentId: string): Promise<Record<string, number>> {
  const reactions = await prisma.commentReaction.groupBy({
    by: ['emoji'],
    where: { commentId },
    _count: { emoji: true },
  });

  const reactionCounts: Record<string, number> = {
    fire: 0,
    love: 0,
    laugh: 0,
    sad: 0,
    wow: 0,
  };

  for (const reaction of reactions) {
    reactionCounts[reaction.emoji] = reaction._count.emoji;
  }

  return reactionCounts;
}

export const commentsRouter = router({
  // Get comments for a specific post
  getComments: publicProcedure
    .input(z.object({
      postId: z.string(),
      limit: z.number().min(1).max(50).default(20),
      cursor: z.string().optional(), // For pagination
    }))
    .query(async ({ input }: { input: { postId: string; limit: number; cursor?: string } }) => {
      const { postId, limit, cursor } = input;
      
      // Get all comments for the post (both top-level and replies)
      const comments = await prisma.comment.findMany({
        where: {
          postId,
        },
        take: limit + 1, // Take one extra to determine if there are more
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: {
          createdAt: 'desc',
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
      });

      let nextCursor: typeof cursor | undefined = undefined;
      if (comments.length > limit) {
        const nextItem = comments.pop(); // Remove the extra item
        nextCursor = nextItem!.id;
      }

      // Transform comments to iOS expected format
      const transformedComments = comments.map((comment: any) => ({
        id: comment.id,
        _id: comment.id,
        postId: comment.postId,
        authorId: comment.authorId,
        authorClerkId: comment.author.clerkId,
        content: comment.content,
        parentCommentId: comment.parentId || null,
        likes: 0, // TODO: implement comment likes count
        isActive: true,
        createdAt: comment.createdAt.getTime(),
        updatedAt: comment.updatedAt.getTime(),
        author: {
          _id: comment.author.id,
          id: comment.author.id,
          clerkId: comment.author.clerkId,
          username: comment.author.username,
          displayName: comment.author.name,
          name: comment.author.name,
          firstName: comment.author.name?.split(' ')[0] || null,
          lastName: comment.author.name?.split(' ').slice(1).join(' ') || null,
          avatarUrl: comment.author.profileImage,
          profileImage: comment.author.profileImage,
        },
        replies: [], // Replies will be handled separately by iOS app
      }));

      // Return as array directly for iOS compatibility
      return transformedComments;
    }),

  // Add a new comment to a post
  addComment: protectedProcedure
    .input(z.object({
      postId: z.string(),
      content: z.string().min(1).max(500),
      parentCommentId: z.string().optional(),
    }))
    .mutation(async ({ input, ctx }: { input: { postId: string; content: string; parentCommentId?: string }; ctx: Context & { user: NonNullable<Context['user']> } }) => {
      const { postId, content, parentCommentId } = input;
      const userClerkId = ctx.user.clerkId;

      // Get current user's UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);

      // First, verify the post exists
      const post = await prisma.post.findUnique({
        where: { id: postId },
        select: { id: true },
      });

      if (!post) {
        throw new Error('Post not found');
      }

      // Create the comment using UUID
      const comment = await prisma.comment.create({
        data: {
          postId,
          authorId: userUUID,
          content,
          parentId: parentCommentId || null,
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
      });

      // Update the post's comment count
      await prisma.post.update({
        where: { id: postId },
        data: {
          commentsCount: {
            increment: 1,
          },
        },
      });

      // Create notification for post comment (using clerkId for notification service)
      await createPostCommentNotification(postId, userClerkId, content);

      // Return in the format expected by iOS app (ConvexCommentResponse)
      return {
        success: true,
        comment: {
          _id: comment.id,
          postId: comment.postId,
          userId: comment.authorId,
          authorClerkId: comment.author.clerkId,
          content: comment.content,
          parentCommentId: parentCommentId || null,
          likes: 0,
          isActive: true,
          createdAt: comment.createdAt.getTime(),
          updatedAt: comment.updatedAt.getTime(),
          author: {
            _id: comment.author.id,
            clerkId: comment.author.clerkId,
            username: comment.author.username,
            displayName: comment.author.name,
            avatarUrl: comment.author.profileImage,
          },
        },
      };
    }),

  // Delete a comment (only by the author)
  deleteComment: protectedProcedure
    .input(z.object({
      commentId: z.string(),
    }))
    .mutation(async ({ input, ctx }: { input: { commentId: string }; ctx: Context & { user: NonNullable<Context['user']> } }) => {
      const { commentId } = input;
      const userClerkId = ctx.user.clerkId;

      // Get current user's UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);

      // Find the comment and verify ownership
      const comment = await prisma.comment.findUnique({
        where: { id: commentId },
        select: { id: true, authorId: true, postId: true },
      });

      if (!comment) {
        throw new Error('Comment not found');
      }

      // Compare UUIDs for ownership check
      if (comment.authorId !== userUUID) {
        throw new Error('You can only delete your own comments');
      }

      // Delete the comment
      await prisma.comment.delete({
        where: { id: commentId },
      });

      // Update the post's comment count
      await prisma.post.update({
        where: { id: comment.postId },
        data: {
          commentsCount: {
            decrement: 1,
          },
        },
      });

      return { success: true };
    }),

  // Toggle reaction on a comment (emoji reactions)
  toggleReaction: protectedProcedure
    .input(z.object({
      commentId: z.string(),
      emoji: z.enum(['fire', 'love', 'laugh', 'sad', 'wow']),
    }))
    .mutation(async ({ input, ctx }: { input: { commentId: string; emoji: string }; ctx: Context & { user: NonNullable<Context['user']> } }) => {
      const { commentId, emoji } = input;
      const userClerkId = ctx.user.clerkId;

      // Get current user's UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);

      // Check if the comment exists
      const comment = await prisma.comment.findUnique({
        where: { id: commentId },
        select: { id: true, authorId: true },
      });

      if (!comment) {
        throw new Error('Comment not found');
      }

      // Check if user already has this reaction
      const existingReaction = await prisma.commentReaction.findUnique({
        where: {
          commentId_userId_emoji: {
            commentId,
            userId: userUUID,
            emoji,
          },
        },
      });

      if (existingReaction) {
        // Remove the reaction
        await prisma.commentReaction.delete({
          where: { id: existingReaction.id },
        });

        // Get updated reaction counts
        const reactions = await getReactionCounts(commentId);

        return {
          success: true,
          added: false,
          reactions,
        };
      } else {
        // Add the reaction
        await prisma.commentReaction.create({
          data: {
            commentId,
            userId: userUUID,
            emoji,
          },
        });

        // Get updated reaction counts
        const reactions = await getReactionCounts(commentId);

        return {
          success: true,
          added: true,
          reactions,
        };
      }
    }),

  // Get reactions for a comment
  getReactions: publicProcedure
    .input(z.object({
      commentId: z.string(),
    }))
    .query(async ({ input }: { input: { commentId: string } }) => {
      const { commentId } = input;

      const reactions = await getReactionCounts(commentId);
      return { reactions };
    }),

  // Legacy toggle like - now uses reaction system with 'love' emoji
  toggleLike: protectedProcedure
    .input(z.object({
      commentId: z.string(),
    }))
    .mutation(async ({ input, ctx }: { input: { commentId: string }; ctx: Context & { user: NonNullable<Context['user']> } }) => {
      const { commentId } = input;
      const userClerkId = ctx.user.clerkId;

      // Get current user's UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);

      // Check if the comment exists
      const comment = await prisma.comment.findUnique({
        where: { id: commentId },
        select: { id: true },
      });

      if (!comment) {
        throw new Error('Comment not found');
      }

      // Check if user already has a 'love' reaction (heart = like)
      const existingReaction = await prisma.commentReaction.findUnique({
        where: {
          commentId_userId_emoji: {
            commentId,
            userId: userUUID,
            emoji: 'love',
          },
        },
      });

      if (existingReaction) {
        // Remove the reaction
        await prisma.commentReaction.delete({
          where: { id: existingReaction.id },
        });

        // Count total love reactions
        const likesCount = await prisma.commentReaction.count({
          where: { commentId, emoji: 'love' },
        });

        return {
          success: true,
          isLiked: false,
          likesCount,
        };
      } else {
        // Add the reaction
        await prisma.commentReaction.create({
          data: {
            commentId,
            userId: userUUID,
            emoji: 'love',
          },
        });

        // Count total love reactions
        const likesCount = await prisma.commentReaction.count({
          where: { commentId, emoji: 'love' },
        });

        return {
          success: true,
          isLiked: true,
          likesCount,
        };
      }
    }),

  // Get comments by a specific user
  getCommentsByUser: publicProcedure
    .input(z.object({
      userId: z.string(), // clerkId
      limit: z.number().min(1).max(50).default(20),
      cursor: z.string().optional(),
    }))
    .query(async ({ input }: { input: { userId: string; limit: number; cursor?: string } }) => {
      const { userId: userClerkId, limit, cursor } = input;
      
      // Get user's UUID from clerkId
      let userUUID: string;
      try {
        userUUID = await getUserIdFromClerkId(userClerkId);
      } catch {
        // If user doesn't exist, return empty results
        return {
          comments: [],
          nextCursor: undefined,
        };
      }

      const comments = await prisma.comment.findMany({
        where: {
          authorId: userUUID,
        },
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: {
          createdAt: 'desc',
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
          post: {
            select: {
              id: true,
              caption: true,
              mediaUrls: true,
            },
          },
        },
      });

      let nextCursor: typeof cursor | undefined = undefined;
      if (comments.length > limit) {
        const nextItem = comments.pop();
        nextCursor = nextItem!.id;
      }

      return {
        comments,
        nextCursor,
      };
    }),
});
