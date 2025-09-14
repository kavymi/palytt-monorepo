import { z } from 'zod';
import { router, publicProcedure, protectedProcedure, type Context } from '../trpc.js';
import { prisma } from '../db.js';
import { createPostCommentNotification } from '../services/notificationService.js';

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

      return {
        comments,
        nextCursor,
      };
    }),

  // Add a new comment to a post
  addComment: protectedProcedure
    .input(z.object({
      postId: z.string(),
      content: z.string().min(1).max(500),
    }))
    .mutation(async ({ input, ctx }: { input: { postId: string; content: string }; ctx: Context & { user: NonNullable<Context['user']> } }) => {
      const { postId, content } = input;
      const userId = ctx.user.clerkId;

      // First, verify the post exists
      const post = await prisma.post.findUnique({
        where: { id: postId },
        select: { id: true },
      });

      if (!post) {
        throw new Error('Post not found');
      }

      // Create the comment
      const comment = await prisma.comment.create({
        data: {
          postId,
          authorId: userId,
          content,
        },
        include: {
          author: {
            select: {
              id: true,
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

      // Create notification for post comment
      await createPostCommentNotification(postId, userId, content);

      return comment;
    }),

  // Delete a comment (only by the author)
  deleteComment: protectedProcedure
    .input(z.object({
      commentId: z.string(),
    }))
    .mutation(async ({ input, ctx }: { input: { commentId: string }; ctx: Context & { user: NonNullable<Context['user']> } }) => {
      const { commentId } = input;
      const userId = ctx.user.clerkId;

      // Find the comment and verify ownership
      const comment = await prisma.comment.findUnique({
        where: { id: commentId },
        select: { id: true, authorId: true, postId: true },
      });

      if (!comment) {
        throw new Error('Comment not found');
      }

      if (comment.authorId !== userId) {
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

  // Toggle like on a comment (if we want to support comment likes)
  toggleLike: protectedProcedure
    .input(z.object({
      commentId: z.string(),
    }))
    .mutation(async ({ input }: { input: { commentId: string } }) => {
      const { commentId } = input;
      // Note: userId available from ctx.user.clerkId if needed for future functionality

      // Check if the comment exists
      const comment = await prisma.comment.findUnique({
        where: { id: commentId },
        select: { id: true },
      });

      if (!comment) {
        throw new Error('Comment not found');
      }

      // For now, we'll return a simple response since comment likes aren't in the schema
      // This can be extended later if comment likes are added to the database schema
      return { 
        success: true, 
        message: 'Comment like functionality not yet implemented in database schema' 
      };
    }),

  // Get comments by a specific user
  getCommentsByUser: publicProcedure
    .input(z.object({
      userId: z.string(),
      limit: z.number().min(1).max(50).default(20),
      cursor: z.string().optional(),
    }))
    .query(async ({ input }: { input: { userId: string; limit: number; cursor?: string } }) => {
      const { userId, limit, cursor } = input;
      
      const comments = await prisma.comment.findMany({
        where: {
          authorId: userId,
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
