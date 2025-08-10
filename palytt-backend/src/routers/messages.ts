import { z } from 'zod';
import { router, publicProcedure, protectedProcedure } from '../trpc';
import { prisma } from '../db';

export const messagesRouter = router({
  // Get all chatrooms for the current user
  getChatrooms: protectedProcedure
    .input(z.object({
      limit: z.number().min(1).max(50).default(20),
      cursor: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const { limit, cursor } = input;
      const userId = ctx.user.clerkId;

      const chatrooms = await prisma.chatroom.findMany({
        where: {
          participants: {
            some: {
              userId,
              leftAt: null, // Only active participants
            },
          },
        },
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: {
          lastMessageAt: 'desc',
        },
        include: {
          participants: {
            where: {
              leftAt: null,
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
          },
          messages: {
            take: 1,
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
                },
              },
            },
          },
          _count: {
            select: {
              messages: {
                where: {
                  readAt: null,
                  senderId: { not: userId },
                },
              },
            },
          },
        },
      });

      let nextCursor: typeof cursor | undefined = undefined;
      if (chatrooms.length > limit) {
        const nextItem = chatrooms.pop();
        nextCursor = nextItem!.id;
      }

      const chatroomsWithDetails = chatrooms.map(chatroom => ({
        ...chatroom,
        lastMessage: chatroom.messages[0] || null,
        unreadCount: chatroom._count.messages,
        otherParticipants: chatroom.participants
          .filter(p => p.userId !== userId)
          .map(p => p.user),
      }));

      return {
        chatrooms: chatroomsWithDetails,
        nextCursor,
      };
    }),

  // Create a new chatroom (direct message)
  createChatroom: protectedProcedure
    .input(z.object({
      participantId: z.string(), // For direct messages
      type: z.enum(['DIRECT', 'GROUP']).default('DIRECT'),
      name: z.string().optional(),
      description: z.string().optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { participantId, type, name, description } = input;
      const userId = ctx.user.clerkId;

      // For direct messages, check if chatroom already exists
      if (type === 'DIRECT') {
        const existingChatroom = await prisma.chatroom.findFirst({
          where: {
            type: 'DIRECT',
            participants: {
              every: {
                userId: {
                  in: [userId, participantId],
                },
              },
            },
            AND: {
              participants: {
                some: {
                  userId: participantId,
                },
              },
            },
          },
          include: {
            participants: {
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
            },
          },
        });

        if (existingChatroom) {
          return existingChatroom;
        }
      }

      // Create new chatroom
      const chatroom = await prisma.chatroom.create({
        data: {
          type,
          name,
          description,
          participants: {
            create: [
              {
                userId,
                isAdmin: true,
              },
              ...(type === 'DIRECT' ? [{
                userId: participantId,
                isAdmin: false,
              }] : []),
            ],
          },
        },
        include: {
          participants: {
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
          },
        },
      });

      return chatroom;
    }),

  // Send a message to a chatroom
  sendMessage: protectedProcedure
    .input(z.object({
      chatroomId: z.string(),
      content: z.string().min(1).max(1000),
      messageType: z.enum(['TEXT', 'IMAGE', 'VIDEO', 'AUDIO', 'FILE']).default('TEXT'),
      mediaUrl: z.string().optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { chatroomId, content, messageType, mediaUrl } = input;
      const userId = ctx.user.clerkId;

      // Verify user is a participant in the chatroom
      const participant = await prisma.chatroomParticipant.findFirst({
        where: {
          chatroomId,
          userId,
          leftAt: null,
        },
      });

      if (!participant) {
        throw new Error('You are not a participant in this chatroom');
      }

      // Create the message
      const message = await prisma.message.create({
        data: {
          chatroomId,
          senderId: userId,
          content,
          messageType,
          mediaUrl,
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
        },
      });

      // Update chatroom's last message time
      await prisma.chatroom.update({
        where: { id: chatroomId },
        data: { lastMessageAt: new Date() },
      });

      return message;
    }),

  // Get messages from a chatroom
  getMessages: protectedProcedure
    .input(z.object({
      chatroomId: z.string(),
      limit: z.number().min(1).max(100).default(50),
      cursor: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const { chatroomId, limit, cursor } = input;
      const userId = ctx.user.clerkId;

      // Verify user is a participant
      const participant = await prisma.chatroomParticipant.findFirst({
        where: {
          chatroomId,
          userId,
        },
      });

      if (!participant) {
        throw new Error('You are not a participant in this chatroom');
      }

      const messages = await prisma.message.findMany({
        where: {
          chatroomId,
          createdAt: {
            gte: participant.joinedAt, // Only messages since user joined
          },
        },
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
        },
      });

      let nextCursor: typeof cursor | undefined = undefined;
      if (messages.length > limit) {
        const nextItem = messages.pop();
        nextCursor = nextItem!.id;
      }

      // Reverse to show oldest first
      const orderedMessages = messages.reverse();

      return {
        messages: orderedMessages,
        nextCursor,
      };
    }),

  // Mark messages as read
  markMessagesAsRead: protectedProcedure
    .input(z.object({
      chatroomId: z.string(),
      messageIds: z.array(z.string()).optional(), // If not provided, mark all unread as read
    }))
    .mutation(async ({ input, ctx }) => {
      const { chatroomId, messageIds } = input;
      const userId = ctx.user.clerkId;

      // Verify user is a participant
      const participant = await prisma.chatroomParticipant.findFirst({
        where: {
          chatroomId,
          userId,
        },
      });

      if (!participant) {
        throw new Error('You are not a participant in this chatroom');
      }

      const now = new Date();

      if (messageIds && messageIds.length > 0) {
        // Mark specific messages as read
        await prisma.message.updateMany({
          where: {
            id: { in: messageIds },
            chatroomId,
            senderId: { not: userId }, // Don't mark own messages
            readAt: null,
          },
          data: {
            readAt: now,
          },
        });
      } else {
        // Mark all unread messages as read
        await prisma.message.updateMany({
          where: {
            chatroomId,
            senderId: { not: userId },
            readAt: null,
          },
          data: {
            readAt: now,
          },
        });
      }

      // Update participant's last read time
      await prisma.chatroomParticipant.update({
        where: { id: participant.id },
        data: { lastReadAt: now },
      });

      return { success: true };
    }),

  // Add participants to a group chatroom
  addParticipants: protectedProcedure
    .input(z.object({
      chatroomId: z.string(),
      userIds: z.array(z.string()),
    }))
    .mutation(async ({ input, ctx }) => {
      const { chatroomId, userIds } = input;
      const userId = ctx.user.clerkId;

      // Verify user is an admin of the chatroom
      const participant = await prisma.chatroomParticipant.findFirst({
        where: {
          chatroomId,
          userId,
          isAdmin: true,
          leftAt: null,
        },
        include: {
          chatroom: true,
        },
      });

      if (!participant) {
        throw new Error('You must be an admin to add participants');
      }

      if (participant.chatroom.type === 'DIRECT') {
        throw new Error('Cannot add participants to direct messages');
      }

      // Add new participants
      const newParticipants = await prisma.chatroomParticipant.createMany({
        data: userIds.map(newUserId => ({
          chatroomId,
          userId: newUserId,
          isAdmin: false,
        })),
        skipDuplicates: true,
      });

      return { success: true, added: newParticipants.count };
    }),

  // Leave a chatroom
  leaveChatroom: protectedProcedure
    .input(z.object({
      chatroomId: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { chatroomId } = input;
      const userId = ctx.user.clerkId;

      // Find the participant record
      const participant = await prisma.chatroomParticipant.findFirst({
        where: {
          chatroomId,
          userId,
          leftAt: null,
        },
      });

      if (!participant) {
        throw new Error('You are not a participant in this chatroom');
      }

      // Mark as left
      await prisma.chatroomParticipant.update({
        where: { id: participant.id },
        data: { leftAt: new Date() },
      });

      return { success: true };
    }),

  // Get unread message count across all chatrooms
  getUnreadCount: protectedProcedure
    .query(async ({ ctx }) => {
      const userId = ctx.user.clerkId;

      const unreadCount = await prisma.message.count({
        where: {
          chatroom: {
            participants: {
              some: {
                userId,
                leftAt: null,
              },
            },
          },
          senderId: { not: userId },
          readAt: null,
        },
      });

      return { unreadCount };
    }),
});
