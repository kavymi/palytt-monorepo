import { z } from 'zod';
import { router, publicProcedure, protectedProcedure } from '../trpc';
import { prisma } from '../db';
import { createFriendRequestNotification, createFriendRequestAcceptedNotification } from '../services/notificationService.js';

export const friendsRouter = router({
  // Send a friend request
  sendRequest: protectedProcedure
    .input(z.object({
      receiverId: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { receiverId } = input;
      const senderId = ctx.user.clerkId;

      // Check if user is trying to send request to themselves
      if (senderId === receiverId) {
        throw new Error('Cannot send friend request to yourself');
      }

      // Check if receiver exists
      const receiver = await prisma.user.findUnique({
        where: { clerkId: receiverId },
        select: { id: true },
      });

      if (!receiver) {
        throw new Error('User not found');
      }

      // Check if there's already a friend relationship
      const existingFriend = await prisma.friend.findFirst({
        where: {
          OR: [
            { senderId, receiverId },
            { senderId: receiverId, receiverId: senderId },
          ],
        },
      });

      if (existingFriend) {
        if (existingFriend.status === 'ACCEPTED') {
          throw new Error('Already friends');
        } else if (existingFriend.status === 'PENDING') {
          throw new Error('Friend request already sent');
        } else if (existingFriend.status === 'BLOCKED') {
          throw new Error('Cannot send friend request');
        }
      }

      // Create friend request
      const friendRequest = await prisma.friend.create({
        data: {
          senderId,
          receiverId,
          status: 'PENDING',
        },
        include: {
          sender: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
            },
          },
          receiver: {
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

      // Create notification for friend request
      await createFriendRequestNotification(receiverId, senderId, friendRequest.id);

      return friendRequest;
    }),

  // Accept a friend request
  acceptRequest: protectedProcedure
    .input(z.object({
      requestId: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { requestId } = input;
      const userId = ctx.user.clerkId;

      // Find the friend request
      const friendRequest = await prisma.friend.findUnique({
        where: { id: requestId },
        include: {
          sender: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
            },
          },
          receiver: {
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

      if (!friendRequest) {
        throw new Error('Friend request not found');
      }

      // Check if the current user is the receiver
      if (friendRequest.receiverId !== userId) {
        throw new Error('You can only accept requests sent to you');
      }

      // Check if request is still pending
      if (friendRequest.status !== 'PENDING') {
        throw new Error('Friend request is no longer pending');
      }

      // Update friend request status
      const updatedFriend = await prisma.friend.update({
        where: { id: requestId },
        data: { status: 'ACCEPTED' },
        include: {
          sender: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
            },
          },
          receiver: {
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

      // Create notification for friend request acceptance
      await createFriendRequestAcceptedNotification(friendRequest.senderId, userId);

      return updatedFriend;
    }),

  // Reject/decline a friend request
  rejectRequest: protectedProcedure
    .input(z.object({
      requestId: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { requestId } = input;
      const userId = ctx.user.clerkId;

      // Find the friend request
      const friendRequest = await prisma.friend.findUnique({
        where: { id: requestId },
      });

      if (!friendRequest) {
        throw new Error('Friend request not found');
      }

      // Check if the current user is the receiver
      if (friendRequest.receiverId !== userId) {
        throw new Error('You can only reject requests sent to you');
      }

      // Delete the friend request
      await prisma.friend.delete({
        where: { id: requestId },
      });

      return { success: true };
    }),

  // Get all friends for a user
  getFriends: publicProcedure
    .input(z.object({
      userId: z.string().optional(), // If not provided, get current user's friends
      limit: z.number().min(1).max(100).default(50),
      cursor: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const { userId, limit, cursor } = input;
      const targetUserId = userId || ctx.user?.clerkId;

      if (!targetUserId) {
        throw new Error('User ID required');
      }

      const friends = await prisma.friend.findMany({
        where: {
          OR: [
            { senderId: targetUserId, status: 'ACCEPTED' },
            { receiverId: targetUserId, status: 'ACCEPTED' },
          ],
        },
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: {
          updatedAt: 'desc',
        },
        include: {
          sender: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
              bio: true,
            },
          },
          receiver: {
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

      let nextCursor: typeof cursor | undefined = undefined;
      if (friends.length > limit) {
        const nextItem = friends.pop();
        nextCursor = nextItem!.id;
      }

      // Transform the results to return the friend user data
      const friendUsers = friends.map(friendship => {
        const friendUser = friendship.senderId === targetUserId 
          ? friendship.receiver 
          : friendship.sender;
        
        return {
          ...friendUser,
          friendshipId: friendship.id,
          friendsSince: friendship.updatedAt,
        };
      });

      return {
        friends: friendUsers,
        nextCursor,
      };
    }),

  // Get pending friend requests (both sent and received)
  getPendingRequests: protectedProcedure
    .input(z.object({
      type: z.enum(['sent', 'received', 'all']).default('all'),
      limit: z.number().min(1).max(50).default(20),
      cursor: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const { type, limit, cursor } = input;
      const userId = ctx.user.clerkId;

      let whereClause: any = {
        status: 'PENDING',
      };

      if (type === 'sent') {
        whereClause.senderId = userId;
      } else if (type === 'received') {
        whereClause.receiverId = userId;
      } else {
        whereClause.OR = [
          { senderId: userId },
          { receiverId: userId },
        ];
      }

      const requests = await prisma.friend.findMany({
        where: whereClause,
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: {
          createdAt: 'desc',
        },
        include: {
          sender: {
            select: {
              id: true,
              clerkId: true,
              username: true,
              name: true,
              profileImage: true,
            },
          },
          receiver: {
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
      if (requests.length > limit) {
        const nextItem = requests.pop();
        nextCursor = nextItem!.id;
      }

      return {
        requests,
        nextCursor,
      };
    }),

  // Check if two users are friends
  areFriends: publicProcedure
    .input(z.object({
      userId1: z.string(),
      userId2: z.string(),
    }))
    .query(async ({ input }) => {
      const { userId1, userId2 } = input;

      const friendship = await prisma.friend.findFirst({
        where: {
          OR: [
            { senderId: userId1, receiverId: userId2, status: 'ACCEPTED' },
            { senderId: userId2, receiverId: userId1, status: 'ACCEPTED' },
          ],
        },
      });

      return { areFriends: !!friendship };
    }),

  // Remove/unfriend a user
  removeFriend: protectedProcedure
    .input(z.object({
      friendId: z.string(), // The clerkId of the friend to remove
    }))
    .mutation(async ({ input, ctx }) => {
      const { friendId } = input;
      const userId = ctx.user.clerkId;

      // Find the friendship
      const friendship = await prisma.friend.findFirst({
        where: {
          OR: [
            { senderId: userId, receiverId: friendId, status: 'ACCEPTED' },
            { senderId: friendId, receiverId: userId, status: 'ACCEPTED' },
          ],
        },
      });

      if (!friendship) {
        throw new Error('Friendship not found');
      }

      // Delete the friendship
      await prisma.friend.delete({
        where: { id: friendship.id },
      });

      return { success: true };
    }),

  // Block a user
  blockUser: protectedProcedure
    .input(z.object({
      userId: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { userId } = input;
      const blockerId = ctx.user.clerkId;

      if (blockerId === userId) {
        throw new Error('Cannot block yourself');
      }

      // Check if there's an existing friendship/request
      const existingRelation = await prisma.friend.findFirst({
        where: {
          OR: [
            { senderId: blockerId, receiverId: userId },
            { senderId: userId, receiverId: blockerId },
          ],
        },
      });

      if (existingRelation) {
        // Update existing relation to blocked
        await prisma.friend.update({
          where: { id: existingRelation.id },
          data: { status: 'BLOCKED' },
        });
      } else {
        // Create new blocked relation
        await prisma.friend.create({
          data: {
            senderId: blockerId,
            receiverId: userId,
            status: 'BLOCKED',
          },
        });
      }

      return { success: true };
    }),
});
