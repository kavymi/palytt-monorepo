import { z } from 'zod';
import { router, publicProcedure, protectedProcedure } from '../trpc.js';
import { prisma } from '../db.js';
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
      const friendUsers = friends.map((friendship: any) => {
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

  // Get mutual friends between two users
  getMutualFriends: publicProcedure
    .input(z.object({
      userId1: z.string(),
      userId2: z.string(),
      limit: z.number().min(1).max(50).default(10),
    }))
    .query(async ({ input }) => {
      const { userId1, userId2, limit } = input;

      // Get friends of both users
      const [user1Friends, user2Friends] = await Promise.all([
        prisma.friend.findMany({
          where: {
            OR: [
              { senderId: userId1, status: 'ACCEPTED' },
              { receiverId: userId1, status: 'ACCEPTED' },
            ],
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
        }),
        prisma.friend.findMany({
          where: {
            OR: [
              { senderId: userId2, status: 'ACCEPTED' },
              { receiverId: userId2, status: 'ACCEPTED' },
            ],
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
        })
      ]);

      // Extract friend user IDs
      const user1FriendIds = new Set(
        user1Friends.map((f: any) => f.senderId === userId1 ? f.receiverId : f.senderId)
      );
      const user2FriendIds = new Set(
        user2Friends.map((f: any) => f.senderId === userId2 ? f.receiverId : f.senderId)
      );

      // Find mutual friend IDs
      const mutualFriendIds = Array.from(user1FriendIds).filter(id => user2FriendIds.has(id));

      // Get mutual friend details
      const mutualFriends = await prisma.user.findMany({
        where: {
          clerkId: {
            in: mutualFriendIds.slice(0, limit),
          },
        },
        select: {
          id: true,
          clerkId: true,
          username: true,
          name: true,
          profileImage: true,
          bio: true,
        },
        take: limit,
      });

      return {
        mutualFriends,
        totalCount: mutualFriendIds.length,
      };
    }),

  // Get friend suggestions based on friends-of-friends
  getFriendSuggestions: protectedProcedure
    .input(z.object({
      limit: z.number().min(1).max(50).default(20),
      excludeRequested: z.boolean().default(true),
    }))
    .query(async ({ input, ctx }) => {
      const { limit, excludeRequested } = input;
      const userId = ctx.user.clerkId;

      // Get current user's friends
      const userFriends = await prisma.friend.findMany({
        where: {
          OR: [
            { senderId: userId, status: 'ACCEPTED' },
            { receiverId: userId, status: 'ACCEPTED' },
          ],
        },
      });

      const userFriendIds = userFriends.map((f: any) => 
        f.senderId === userId ? f.receiverId : f.senderId
      );

      if (userFriendIds.length === 0) {
        // If user has no friends, return random suggested users
        const randomUsers = await prisma.user.findMany({
          where: {
            clerkId: {
              not: userId,
            },
          },
          take: limit,
          orderBy: {
            createdAt: 'desc',
          },
          select: {
            id: true,
            clerkId: true,
            username: true,
            name: true,
            profileImage: true,
            bio: true,
            followerCount: true,
          },
        });

        return {
          suggestions: randomUsers.map((user: any) => ({
            ...user,
            mutualFriendsCount: 0,
            connectionReason: 'new_user' as const,
          })),
        };
      }

      // Get friends of friends
      const friendsOfFriends = await prisma.friend.findMany({
        where: {
          OR: [
            { senderId: { in: userFriendIds }, status: 'ACCEPTED' },
            { receiverId: { in: userFriendIds }, status: 'ACCEPTED' },
          ],
          NOT: {
            OR: [
              { senderId: userId },
              { receiverId: userId },
              { senderId: { in: userFriendIds } },
              { receiverId: { in: userFriendIds } },
            ],
          },
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
              followerCount: true,
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
              followerCount: true,
            },
          },
        },
      });

      // Count mutual friends for each suggestion
      const suggestionMap = new Map<string, {
        user: any;
        mutualFriendsCount: number;
        mutualFriends: string[];
      }>();

      for (const friendship of friendsOfFriends) {
        const suggestedUser = userFriendIds.includes(friendship.senderId) 
          ? friendship.receiver 
          : friendship.sender;
        
        const mutualFriendId = userFriendIds.includes(friendship.senderId)
          ? friendship.senderId
          : friendship.receiverId;

        if (suggestionMap.has(suggestedUser.clerkId)) {
          const existing = suggestionMap.get(suggestedUser.clerkId)!;
          existing.mutualFriendsCount++;
          existing.mutualFriends.push(mutualFriendId);
        } else {
          suggestionMap.set(suggestedUser.clerkId, {
            user: suggestedUser,
            mutualFriendsCount: 1,
            mutualFriends: [mutualFriendId],
          });
        }
      }

      // Exclude users with existing friend requests if specified
      let finalSuggestions = Array.from(suggestionMap.values());
      
      if (excludeRequested) {
        const existingRequests = await prisma.friend.findMany({
          where: {
            OR: [
              { senderId: userId, status: { in: ['PENDING', 'ACCEPTED'] } },
              { receiverId: userId, status: { in: ['PENDING', 'ACCEPTED'] } },
            ],
          },
        });

        const requestedUserIds = new Set(
          existingRequests.map((req: any) => 
            req.senderId === userId ? req.receiverId : req.senderId
          )
        );

        finalSuggestions = finalSuggestions.filter(
          suggestion => !requestedUserIds.has(suggestion.user.clerkId)
        );
      }

      // Sort by mutual friends count and follower count
      finalSuggestions.sort((a, b) => {
        if (a.mutualFriendsCount !== b.mutualFriendsCount) {
          return b.mutualFriendsCount - a.mutualFriendsCount;
        }
        return b.user.followerCount - a.user.followerCount;
      });

      const result = finalSuggestions.slice(0, limit).map(suggestion => ({
        ...suggestion.user,
        mutualFriendsCount: suggestion.mutualFriendsCount,
        connectionReason: 'mutual_friends' as const,
      }));

      return {
        suggestions: result,
      };
    }),
});
