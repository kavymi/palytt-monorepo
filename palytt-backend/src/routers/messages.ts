import { z } from 'zod';
import { router, protectedProcedure } from '../trpc.js';
import { prisma } from '../db.js';

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

      const chatroomsWithDetails = chatrooms.map((chatroom: any) => ({
        ...chatroom,
        lastMessage: chatroom.messages[0] || null,
        unreadCount: chatroom._count.messages,
        otherParticipants: chatroom.participants
          .filter((p: any) => p.userId !== userId)
          .map((p: any) => p.user),
      }));

      return {
        chatrooms: chatroomsWithDetails,
        nextCursor,
      };
    }),

  // Create a new chatroom (direct message)
  createChatroom: protectedProcedure
    .input(z.object({
      participantId: z.string().optional(), // For direct messages
      participantIds: z.array(z.string()).optional(), // For group messages
      type: z.enum(['DIRECT', 'GROUP']).default('DIRECT'),
      name: z.string().optional(),
      description: z.string().optional(),
      imageUrl: z.string().optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { participantId, participantIds, type, name, description, imageUrl } = input;
      const userId = ctx.user.clerkId;

      // For direct messages, check if chatroom already exists
      if (type === 'DIRECT') {
        if (!participantId) {
          throw new Error('participantId is required for direct messages');
        }

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
      } else if (type === 'GROUP') {
        if (!participantIds || participantIds.length === 0) {
          throw new Error('participantIds is required for group messages');
        }
        if (!name) {
          throw new Error('name is required for group messages');
        }
      }

      // Create new chatroom
      const chatroom = await prisma.chatroom.create({
        data: {
          type,
          name,
          description,
          imageUrl,
          participants: {
            create: [
              {
                userId,
                isAdmin: true,
              },
              ...(type === 'DIRECT' && participantId ? [{
                userId: participantId,
                isAdmin: false,
              }] : []),
              ...(type === 'GROUP' && participantIds ? participantIds.map((id: any) => ({
                userId: id,
                isAdmin: false,
              })) : []),
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
      messageType: z.enum(['TEXT', 'IMAGE', 'VIDEO', 'AUDIO', 'FILE', 'POST_SHARE', 'PLACE_SHARE', 'LINK_SHARE']).default('TEXT'),
      mediaUrl: z.string().optional(),
      sharedContentId: z.string().optional(), // For post/place shares
      linkPreview: z.object({
        title: z.string(),
        description: z.string().optional(),
        imageUrl: z.string().optional(),
        url: z.string(),
      }).optional(), // For link shares
    }))
    .mutation(async ({ input, ctx }) => {
      const { chatroomId, content, messageType, mediaUrl, sharedContentId, linkPreview } = input;
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

      // Prepare message data
      const messageData = {
        chatroomId,
        senderId: userId,
        content,
        messageType,
        mediaUrl,
        ...(sharedContentId && { 
          metadata: { sharedContentId } 
        }),
        ...(linkPreview && { 
          metadata: { linkPreview } 
        }),
      };

      // Create the message
      const message = await prisma.message.create({
        data: messageData,
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
        data: userIds.map((newUserId: any) => ({
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

  // Update group settings (name, description, image)
  updateGroupSettings: protectedProcedure
    .input(z.object({
      chatroomId: z.string(),
      name: z.string().optional(),
      description: z.string().optional(),
      imageUrl: z.string().optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { chatroomId, name, description, imageUrl } = input;
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
        throw new Error('You must be an admin to update group settings');
      }

      if (participant.chatroom.type === 'DIRECT') {
        throw new Error('Cannot update settings for direct messages');
      }

      // Update chatroom
      const updatedChatroom = await prisma.chatroom.update({
        where: { id: chatroomId },
        data: {
          ...(name && { name }),
          ...(description && { description }),
          ...(imageUrl && { imageUrl }),
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
        },
      });

      return updatedChatroom;
    }),

  // Make participant admin
  makeAdmin: protectedProcedure
    .input(z.object({
      chatroomId: z.string(),
      userId: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { chatroomId, userId: targetUserId } = input;
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
        throw new Error('You must be an admin to make others admin');
      }

      if (participant.chatroom.type === 'DIRECT') {
        throw new Error('Cannot make admin in direct messages');
      }

      // Update target participant to admin
      await prisma.chatroomParticipant.updateMany({
        where: {
          chatroomId,
          userId: targetUserId,
          leftAt: null,
        },
        data: {
          isAdmin: true,
        },
      });

      return { success: true };
    }),

  // Remove participant from group
  removeParticipant: protectedProcedure
    .input(z.object({
      chatroomId: z.string(),
      userId: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { chatroomId, userId: targetUserId } = input;
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
        throw new Error('You must be an admin to remove participants');
      }

      if (participant.chatroom.type === 'DIRECT') {
        throw new Error('Cannot remove participants from direct messages');
      }

      // Mark target participant as left
      await prisma.chatroomParticipant.updateMany({
        where: {
          chatroomId,
          userId: targetUserId,
          leftAt: null,
        },
        data: {
          leftAt: new Date(),
        },
      });

      return { success: true };
    }),

  // Get shared media in conversation
  getSharedMedia: protectedProcedure
    .input(z.object({
      chatroomId: z.string(),
      messageType: z.enum(['IMAGE', 'VIDEO', 'AUDIO', 'FILE', 'POST_SHARE', 'PLACE_SHARE', 'LINK_SHARE']).optional(),
      limit: z.number().min(1).max(50).default(20),
      cursor: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const { chatroomId, messageType, limit, cursor } = input;
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
          messageType: messageType || {
            in: ['IMAGE', 'VIDEO', 'AUDIO', 'FILE', 'POST_SHARE', 'PLACE_SHARE', 'LINK_SHARE']
          },
          createdAt: {
            gte: participant.joinedAt,
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

      return {
        messages,
        nextCursor,
      };
    }),
});
