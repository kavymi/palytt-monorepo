import { z } from 'zod';
import { router, publicProcedure, protectedProcedure } from '../trpc.js';
import { prisma, ensureUser } from '../db.js';
import { createFriendRequestNotification, createFriendRequestAcceptedNotification } from '../services/notificationService.js';

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

export const friendsRouter = router({
  // Send a friend request
  sendRequest: protectedProcedure
    .input(z.object({
      receiverId: z.string(), // This is the clerkId of the receiver
    }))
    .mutation(async ({ input, ctx }) => {
      const { receiverId: receiverClerkId } = input;
      const senderClerkId = ctx.user.clerkId;

      // Check if user is trying to send request to themselves
      if (senderClerkId === receiverClerkId) {
        throw new Error('Cannot send friend request to yourself');
      }

      // Get sender UUID (ensure user exists in DB)
      const senderUUID = await ensureUserIdFromClerkId(senderClerkId);

      // Get receiver UUID
      const receiverUUID = await getUserIdFromClerkId(receiverClerkId);

      // Check if there's already a friend relationship
      const existingFriend = await prisma.friend.findFirst({
        where: {
          OR: [
            { senderId: senderUUID, receiverId: receiverUUID },
            { senderId: receiverUUID, receiverId: senderUUID },
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

      // Create friend request using UUIDs
      const friendRequest = await prisma.friend.create({
        data: {
          senderId: senderUUID,
          receiverId: receiverUUID,
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

      // Create notification for friend request (using clerkIds for notification service)
      await createFriendRequestNotification(receiverClerkId, senderClerkId, friendRequest.id);

      return friendRequest;
    }),

  // Accept a friend request
  acceptRequest: protectedProcedure
    .input(z.object({
      requestId: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { requestId } = input;
      const userClerkId = ctx.user.clerkId;

      // Get current user's UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);

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

      // Check if the current user is the receiver (compare UUIDs)
      if (friendRequest.receiverId !== userUUID) {
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

      // Create notification for friend request acceptance (using clerkIds)
      await createFriendRequestAcceptedNotification(friendRequest.sender.clerkId, userClerkId);

      return updatedFriend;
    }),

  // Reject/decline a friend request
  rejectRequest: protectedProcedure
    .input(z.object({
      requestId: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { requestId } = input;
      const userClerkId = ctx.user.clerkId;

      // Get current user's UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);

      // Find the friend request
      const friendRequest = await prisma.friend.findUnique({
        where: { id: requestId },
      });

      if (!friendRequest) {
        throw new Error('Friend request not found');
      }

      // Check if the current user is the receiver (compare UUIDs)
      if (friendRequest.receiverId !== userUUID) {
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
      userId: z.string().optional(), // clerkId - If not provided, get current user's friends
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

      const friends = await prisma.friend.findMany({
        where: {
          OR: [
            { senderId: targetUUID, status: 'ACCEPTED' },
            { receiverId: targetUUID, status: 'ACCEPTED' },
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
        const friendUser = friendship.senderId === targetUUID 
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
      const userClerkId = ctx.user.clerkId;

      // Get current user's UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);

      let whereClause: any = {
        status: 'PENDING',
      };

      if (type === 'sent') {
        whereClause.senderId = userUUID;
      } else if (type === 'received') {
        whereClause.receiverId = userUUID;
      } else {
        whereClause.OR = [
          { senderId: userUUID },
          { receiverId: userUUID },
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
      userId1: z.string(), // clerkId
      userId2: z.string(), // clerkId
    }))
    .query(async ({ input }) => {
      const { userId1: clerkId1, userId2: clerkId2 } = input;

      // Get UUIDs for both users
      let uuid1: string, uuid2: string;
      try {
        [uuid1, uuid2] = await Promise.all([
          getUserIdFromClerkId(clerkId1),
          getUserIdFromClerkId(clerkId2),
        ]);
      } catch {
        // If either user doesn't exist, they can't be friends
        return { areFriends: false };
      }

      const friendship = await prisma.friend.findFirst({
        where: {
          OR: [
            { senderId: uuid1, receiverId: uuid2, status: 'ACCEPTED' },
            { senderId: uuid2, receiverId: uuid1, status: 'ACCEPTED' },
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
      const { friendId: friendClerkId } = input;
      const userClerkId = ctx.user.clerkId;

      // Get UUIDs
      const userUUID = await ensureUserIdFromClerkId(userClerkId);
      const friendUUID = await getUserIdFromClerkId(friendClerkId);

      // Find the friendship
      const friendship = await prisma.friend.findFirst({
        where: {
          OR: [
            { senderId: userUUID, receiverId: friendUUID, status: 'ACCEPTED' },
            { senderId: friendUUID, receiverId: userUUID, status: 'ACCEPTED' },
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
      userId: z.string(), // clerkId of user to block
    }))
    .mutation(async ({ input, ctx }) => {
      const { userId: targetClerkId } = input;
      const blockerClerkId = ctx.user.clerkId;

      if (blockerClerkId === targetClerkId) {
        throw new Error('Cannot block yourself');
      }

      // Get UUIDs
      const blockerUUID = await ensureUserIdFromClerkId(blockerClerkId);
      const targetUUID = await getUserIdFromClerkId(targetClerkId);

      // Check if there's an existing friendship/request
      const existingRelation = await prisma.friend.findFirst({
        where: {
          OR: [
            { senderId: blockerUUID, receiverId: targetUUID },
            { senderId: targetUUID, receiverId: blockerUUID },
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
            senderId: blockerUUID,
            receiverId: targetUUID,
            status: 'BLOCKED',
          },
        });
      }

      return { success: true };
    }),

  // Get mutual friends between two users
  getMutualFriends: publicProcedure
    .input(z.object({
      userId1: z.string(), // clerkId
      userId2: z.string(), // clerkId
      limit: z.number().min(1).max(50).default(10),
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
        // If either user doesn't exist, they have no mutual friends
        return { mutualFriends: [], totalCount: 0 };
      }

      // Get friends of both users
      const [user1Friends, user2Friends] = await Promise.all([
        prisma.friend.findMany({
          where: {
            OR: [
              { senderId: uuid1, status: 'ACCEPTED' },
              { receiverId: uuid1, status: 'ACCEPTED' },
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
              { senderId: uuid2, status: 'ACCEPTED' },
              { receiverId: uuid2, status: 'ACCEPTED' },
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

      // Extract friend user IDs (UUIDs)
      const user1FriendIds = new Set(
        user1Friends.map((f: any) => f.senderId === uuid1 ? f.receiverId : f.senderId)
      );
      const user2FriendIds = new Set(
        user2Friends.map((f: any) => f.senderId === uuid2 ? f.receiverId : f.senderId)
      );

      // Find mutual friend IDs (UUIDs)
      const mutualFriendIds = Array.from(user1FriendIds).filter(id => user2FriendIds.has(id));

      // Get mutual friend details
      const mutualFriends = await prisma.user.findMany({
        where: {
          id: {
            in: mutualFriendIds.slice(0, limit) as string[],
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
      const userClerkId = ctx.user.clerkId;

      // Get current user's UUID
      const userUUID = await ensureUserIdFromClerkId(userClerkId);

      // Get current user's friends
      const userFriends = await prisma.friend.findMany({
        where: {
          OR: [
            { senderId: userUUID, status: 'ACCEPTED' },
            { receiverId: userUUID, status: 'ACCEPTED' },
          ],
        },
      });

      const userFriendIds = userFriends.map((f: any) => 
        f.senderId === userUUID ? f.receiverId : f.senderId
      );

      if (userFriendIds.length === 0) {
        // If user has no friends, return random suggested users
        const randomUsers = await prisma.user.findMany({
          where: {
            id: {
              not: userUUID,
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
              { senderId: userUUID },
              { receiverId: userUUID },
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
        
        // Skip if this is one of the user's existing friends
        if (userFriendIds.includes(suggestedUser.id)) {
          continue;
        }

        const mutualFriendId = userFriendIds.includes(friendship.senderId)
          ? friendship.senderId
          : friendship.receiverId;

        if (suggestionMap.has(suggestedUser.id)) {
          const existing = suggestionMap.get(suggestedUser.id)!;
          existing.mutualFriendsCount++;
          existing.mutualFriends.push(mutualFriendId);
        } else {
          suggestionMap.set(suggestedUser.id, {
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
              { senderId: userUUID, status: { in: ['PENDING', 'ACCEPTED'] } },
              { receiverId: userUUID, status: { in: ['PENDING', 'ACCEPTED'] } },
            ],
          },
        });

        const requestedUserIds = new Set(
          existingRequests.map((req: any) => 
            req.senderId === userUUID ? req.receiverId : req.senderId
          )
        );

        finalSuggestions = finalSuggestions.filter(
          suggestion => !requestedUserIds.has(suggestion.user.id)
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
