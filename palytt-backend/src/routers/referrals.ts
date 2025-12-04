import { z } from 'zod';
import { router, protectedProcedure, publicProcedure } from '../trpc.js';
import { prisma } from '../db.js';
import crypto from 'crypto';

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

// Generate a unique referral code
function generateReferralCode(): string {
  // Generate a 6-character alphanumeric code
  return crypto.randomBytes(3).toString('hex').toUpperCase();
}

export const referralsRouter = router({
  /**
   * Get or create the current user's referral code
   */
  getMyReferralCode: protectedProcedure
    .query(async ({ ctx }) => {
      const userClerkId = ctx.user.clerkId;

      let user = await prisma.user.findUnique({
        where: { clerkId: userClerkId },
        select: {
          id: true,
          referralCode: true,
          referralRewardsCount: true,
        },
      });

      if (!user) {
        throw new Error('User not found');
      }

      // Generate a referral code if the user doesn't have one
      if (!user.referralCode) {
        let code: string;
        let isUnique = false;

        // Keep generating until we get a unique code
        while (!isUnique) {
          code = generateReferralCode();
          const existing = await prisma.user.findUnique({
            where: { referralCode: code },
          });
          if (!existing) {
            isUnique = true;
            await prisma.user.update({
              where: { id: user.id },
              data: { referralCode: code },
            });
            user.referralCode = code;
          }
        }
      }

      return {
        code: user.referralCode,
        rewardsCount: user.referralRewardsCount,
      };
    }),

  /**
   * Get referral statistics for the current user
   */
  getMyReferralStats: protectedProcedure
    .query(async ({ ctx }) => {
      const userClerkId = ctx.user.clerkId;
      const userUUID = await getUserIdFromClerkId(userClerkId);

      // Get all referrals sent by this user
      const referrals = await prisma.referral.findMany({
        where: { referrerId: userUUID },
        include: {
          referee: {
            select: {
              id: true,
              name: true,
              username: true,
              profileImage: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      });

      // Count by status
      const pending = referrals.filter(r => r.status === 'PENDING').length;
      const rewarded = referrals.filter(r => r.status === 'REWARDED').length;

      // Get friends who joined
      const friendsJoined = referrals
        .filter(r => r.referee && (r.status === 'USED' || r.status === 'REWARDED'))
        .map(r => ({
          id: r.referee!.id,
          name: r.referee!.name,
          username: r.referee!.username,
          profileImage: r.referee!.profileImage,
          joinedAt: r.completedAt?.toISOString() || r.createdAt.toISOString(),
        }));

      return {
        totalInvitesSent: referrals.length,
        pendingInvites: pending,
        friendsJoined: friendsJoined.length,
        rewardsEarned: rewarded,
        friends: friendsJoined,
      };
    }),

  /**
   * Validate a referral code
   */
  validateCode: publicProcedure
    .input(z.object({
      code: z.string().min(1),
    }))
    .query(async ({ input }) => {
      const { code } = input;

      const user = await prisma.user.findUnique({
        where: { referralCode: code.toUpperCase() },
        select: {
          id: true,
          name: true,
          username: true,
          profileImage: true,
        },
      });

      if (!user) {
        return {
          valid: false,
          referrer: null,
        };
      }

      return {
        valid: true,
        referrer: {
          id: user.id,
          name: user.name,
          username: user.username,
          profileImage: user.profileImage,
        },
      };
    }),

  /**
   * Apply a referral code during signup
   * This should be called after a new user signs up with a referral code
   */
  applyReferralCode: protectedProcedure
    .input(z.object({
      code: z.string().min(1),
    }))
    .mutation(async ({ input, ctx }) => {
      const { code } = input;
      const newUserClerkId = ctx.user.clerkId;

      // Find the referrer by code
      const referrer = await prisma.user.findUnique({
        where: { referralCode: code.toUpperCase() },
        select: { id: true, clerkId: true },
      });

      if (!referrer) {
        return {
          success: false,
          message: 'Invalid referral code',
        };
      }

      // Get the new user
      const newUser = await prisma.user.findUnique({
        where: { clerkId: newUserClerkId },
        select: { id: true, referredBy: true },
      });

      if (!newUser) {
        return {
          success: false,
          message: 'User not found',
        };
      }

      // Check if user already has a referrer
      if (newUser.referredBy) {
        return {
          success: false,
          message: 'You have already used a referral code',
        };
      }

      // Prevent self-referral
      if (referrer.clerkId === newUserClerkId) {
        return {
          success: false,
          message: 'You cannot use your own referral code',
        };
      }

      // Create the referral record
      await prisma.referral.create({
        data: {
          code: code.toUpperCase(),
          referrerId: referrer.id,
          refereeId: newUser.id,
          status: 'USED',
          completedAt: new Date(),
        },
      });

      // Update the new user's referredBy field
      await prisma.user.update({
        where: { id: newUser.id },
        data: { referredBy: referrer.clerkId },
      });

      // Update the referrer's reward count
      await prisma.user.update({
        where: { id: referrer.id },
        data: {
          referralRewardsCount: {
            increment: 1,
          },
        },
      });

      // Create notification for the referrer
      await prisma.notification.create({
        data: {
          userId: referrer.id,
          type: 'GENERAL',
          title: 'Friend Joined!',
          message: 'Someone you invited has joined Palytt!',
          data: {
            type: 'referral_completed',
            refereeId: newUser.id,
          },
        },
      });

      return {
        success: true,
        message: 'Referral code applied successfully',
      };
    }),

  /**
   * Get list of pending referrals (codes that haven't been used yet)
   */
  getPendingReferrals: protectedProcedure
    .query(async ({ ctx }) => {
      const userClerkId = ctx.user.clerkId;
      const userUUID = await getUserIdFromClerkId(userClerkId);

      const referrals = await prisma.referral.findMany({
        where: {
          referrerId: userUUID,
          status: 'PENDING',
        },
        orderBy: { createdAt: 'desc' },
      });

      return {
        referrals: referrals.map(r => ({
          id: r.id,
          code: r.code,
          createdAt: r.createdAt.toISOString(),
        })),
      };
    }),

  /**
   * Create a shareable invite link (creates a new referral record)
   */
  createInviteLink: protectedProcedure
    .mutation(async ({ ctx }) => {
      const userClerkId = ctx.user.clerkId;
      const userUUID = await getUserIdFromClerkId(userClerkId);

      // Get user's referral code
      const user = await prisma.user.findUnique({
        where: { id: userUUID },
        select: { referralCode: true },
      });

      if (!user?.referralCode) {
        throw new Error('User does not have a referral code');
      }

      // The invite link uses the user's referral code
      const inviteLink = `https://palytt.app/invite/${user.referralCode}`;

      return {
        link: inviteLink,
        code: user.referralCode,
      };
    }),
});

