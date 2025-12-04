import { z } from 'zod';
import { router, protectedProcedure } from '../trpc.js';
import { prisma } from '../db.js';

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

export const gatheringsRouter = router({
  /**
   * Send a gathering invite to a friend
   */
  sendInvite: protectedProcedure
    .input(z.object({
      gatheringId: z.string(),
      inviteeId: z.string(), // clerkId of the user to invite
    }))
    .mutation(async ({ input, ctx }) => {
      const { gatheringId, inviteeId: inviteeClerkId } = input;
      const inviterClerkId = ctx.user.clerkId;

      // Get inviter UUID
      const inviterUUID = await getUserIdFromClerkId(inviterClerkId);
      
      // Get invitee UUID
      const inviteeUUID = await getUserIdFromClerkId(inviteeClerkId);

      // Check if invite already exists
      const existingInvite = await prisma.gatheringInvite.findUnique({
        where: {
          gatheringId_inviteeId: {
            gatheringId,
            inviteeId: inviteeUUID,
          },
        },
      });

      if (existingInvite) {
        return {
          success: false,
          invite: null,
          message: 'Invite already sent to this user',
        };
      }

      // Create the invite
      const invite = await prisma.gatheringInvite.create({
        data: {
          gatheringId,
          inviterId: inviterUUID,
          inviteeId: inviteeUUID,
          status: 'PENDING',
        },
      });

      // Create notification for the invitee
      const inviter = await prisma.user.findUnique({
        where: { id: inviterUUID },
        select: { name: true, username: true },
      });

      await prisma.notification.create({
        data: {
          userId: inviteeUUID,
          type: 'GATHERING_INVITE',
          title: 'Gathering Invitation',
          message: `${inviter?.name || inviter?.username || 'Someone'} invited you to a gathering`,
          data: {
            gatheringId,
            inviteId: invite.id,
            senderId: inviterClerkId,
            senderName: inviter?.name || inviter?.username,
          },
        },
      });

      return {
        success: true,
        invite: {
          id: invite.id,
          gatheringId: invite.gatheringId,
          inviterId: invite.inviterId,
          inviteeId: invite.inviteeId,
          status: invite.status,
          createdAt: invite.createdAt.toISOString(),
        },
        message: 'Invite sent successfully',
      };
    }),

  /**
   * Accept a gathering invite
   */
  acceptInvite: protectedProcedure
    .input(z.object({
      inviteId: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { inviteId } = input;
      const userClerkId = ctx.user.clerkId;

      // Get user UUID
      const userUUID = await getUserIdFromClerkId(userClerkId);

      // Find the invite
      const invite = await prisma.gatheringInvite.findUnique({
        where: { id: inviteId },
      });

      if (!invite) {
        throw new Error('Invite not found');
      }

      // Check if the current user is the invitee
      if (invite.inviteeId !== userUUID) {
        throw new Error('You can only accept invites sent to you');
      }

      // Check if invite is still pending
      if (invite.status !== 'PENDING') {
        throw new Error('Invite is no longer pending');
      }

      // Update the invite
      const updatedInvite = await prisma.gatheringInvite.update({
        where: { id: inviteId },
        data: {
          status: 'ACCEPTED',
          respondedAt: new Date(),
        },
      });

      return {
        success: true,
        invite: {
          id: updatedInvite.id,
          gatheringId: updatedInvite.gatheringId,
          status: updatedInvite.status,
        },
      };
    }),

  /**
   * Decline a gathering invite
   */
  declineInvite: protectedProcedure
    .input(z.object({
      inviteId: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const { inviteId } = input;
      const userClerkId = ctx.user.clerkId;

      // Get user UUID
      const userUUID = await getUserIdFromClerkId(userClerkId);

      // Find the invite
      const invite = await prisma.gatheringInvite.findUnique({
        where: { id: inviteId },
      });

      if (!invite) {
        throw new Error('Invite not found');
      }

      // Check if the current user is the invitee
      if (invite.inviteeId !== userUUID) {
        throw new Error('You can only decline invites sent to you');
      }

      // Update the invite
      const updatedInvite = await prisma.gatheringInvite.update({
        where: { id: inviteId },
        data: {
          status: 'DECLINED',
          respondedAt: new Date(),
        },
      });

      return {
        success: true,
        invite: {
          id: updatedInvite.id,
          gatheringId: updatedInvite.gatheringId,
          status: updatedInvite.status,
        },
      };
    }),

  /**
   * Get pending invites for the current user
   */
  getPendingInvites: protectedProcedure
    .input(z.object({
      limit: z.number().min(1).max(50).default(20),
      cursor: z.string().optional(),
    }))
    .query(async ({ input, ctx }) => {
      const { limit, cursor } = input;
      const userClerkId = ctx.user.clerkId;

      // Get user UUID
      const userUUID = await getUserIdFromClerkId(userClerkId);

      const invites = await prisma.gatheringInvite.findMany({
        where: {
          inviteeId: userUUID,
          status: 'PENDING',
        },
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: { createdAt: 'desc' },
        include: {
          inviter: {
            select: {
              id: true,
              clerkId: true,
              name: true,
              username: true,
              profileImage: true,
            },
          },
        },
      });

      let nextCursor: string | undefined;
      if (invites.length > limit) {
        const nextItem = invites.pop();
        nextCursor = nextItem!.id;
      }

      return {
        invites: invites.map((invite: any) => ({
          id: invite.id,
          gatheringId: invite.gatheringId,
          status: invite.status,
          createdAt: invite.createdAt.toISOString(),
          inviter: {
            id: invite.inviter.id,
            clerkId: invite.inviter.clerkId,
            name: invite.inviter.name,
            username: invite.inviter.username,
            profileImage: invite.inviter.profileImage,
          },
        })),
        nextCursor,
      };
    }),
});

