import { z } from 'zod';
import { router, protectedProcedure, publicProcedure } from '../trpc.js';
import { prisma } from '../db.js';
import crypto from 'crypto';
import { createNotification } from '../services/notificationService.js';

// Reward tiers configuration - milestones and their rewards
const REWARD_TIERS = [
  { milestone: 1, type: 'STREAK_FREEZE' as const, amount: 1, description: 'Streak Freeze x1' },
  { milestone: 3, type: 'STREAK_FREEZE' as const, amount: 2, description: 'Streak Freeze x2' },
  { milestone: 5, type: 'BADGE' as const, amount: 1, description: 'Social Butterfly Badge' },
  { milestone: 10, type: 'PREMIUM_WEEK' as const, amount: 1, description: 'Premium Week' },
  { milestone: 25, type: 'VIP_STATUS' as const, amount: 1, description: 'VIP Ambassador Status' },
];

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

      // Get current referral count before incrementing
      const referrerData = await prisma.user.findUnique({
        where: { id: referrer.id },
        select: { referralRewardsCount: true, name: true, username: true },
      });

      const currentCount = referrerData?.referralRewardsCount || 0;
      const newCount = currentCount + 1;

      // Update the referrer's reward count
      await prisma.user.update({
        where: { id: referrer.id },
        data: {
          referralRewardsCount: newCount,
        },
      });

      // Check and grant milestone rewards
      for (const tier of REWARD_TIERS) {
        if (newCount === tier.milestone) {
          // Grant the reward
          await prisma.referralReward.create({
            data: {
              userId: referrer.id,
              type: tier.type,
              amount: tier.amount,
              milestone: tier.milestone,
            },
          });

          // Send notification about the reward
          await createNotification(
            referrer.clerkId,
            'GENERAL',
            '🎁 Referral Reward Unlocked!',
            `You earned ${tier.description} for ${tier.milestone} referral${tier.milestone > 1 ? 's' : ''}!`,
            {
              type: 'referral_reward',
              rewardType: tier.type,
              milestone: tier.milestone,
            }
          );
        }
      }

      // Create notification for the referrer about the new friend
      await createNotification(
        referrer.clerkId,
        'GENERAL',
        'Friend Joined!',
        'Someone you invited has joined Palytt!',
        {
          type: 'referral_completed',
          refereeId: newUser.id,
        }
      );

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

  /**
   * Get invite metadata for Open Graph previews
   */
  getInviteMetadata: publicProcedure
    .input(z.object({
      code: z.string().min(1),
    }))
    .query(async ({ input }) => {
      const user = await prisma.user.findUnique({
        where: { referralCode: input.code.toUpperCase() },
        select: { name: true, username: true, profileImage: true },
      });

      return {
        title: user ? `${user.name || user.username} invited you to Palytt` : 'Join Palytt',
        description: 'Discover amazing food experiences with friends',
        image: user?.profileImage || 'https://palytt.app/og-image.png',
      };
    }),

  /**
   * Get the current user's referral rewards
   */
  getMyRewards: protectedProcedure
    .query(async ({ ctx }) => {
      const userClerkId = ctx.user.clerkId;
      const userUUID = await getUserIdFromClerkId(userClerkId);

      const rewards = await prisma.referralReward.findMany({
        where: { userId: userUUID },
        orderBy: { createdAt: 'desc' },
      });

      // Count unclaimed rewards
      const unclaimedCount = rewards.filter(r => !r.claimedAt).length;

      return {
        rewards: rewards.map(r => ({
          id: r.id,
          type: r.type,
          amount: r.amount,
          milestone: r.milestone,
          claimedAt: r.claimedAt?.toISOString() || null,
          expiresAt: r.expiresAt?.toISOString() || null,
          createdAt: r.createdAt.toISOString(),
        })),
        unclaimedCount,
      };
    }),

  /**
   * Claim a referral reward
   */
  claimReward: protectedProcedure
    .input(z.object({
      rewardId: z.string().uuid(),
    }))
    .mutation(async ({ input, ctx }) => {
      const userClerkId = ctx.user.clerkId;
      const userUUID = await getUserIdFromClerkId(userClerkId);

      // Find the reward
      const reward = await prisma.referralReward.findFirst({
        where: {
          id: input.rewardId,
          userId: userUUID,
          claimedAt: null,
        },
      });

      if (!reward) {
        return {
          success: false,
          message: 'Reward not found or already claimed',
        };
      }

      // Check if expired
      if (reward.expiresAt && reward.expiresAt < new Date()) {
        return {
          success: false,
          message: 'Reward has expired',
        };
      }

      // Apply reward effect based on type
      if (reward.type === 'STREAK_FREEZE') {
        await prisma.user.update({
          where: { id: userUUID },
          data: {
            streakFreezeCount: {
              increment: reward.amount,
            },
          },
        });
      }
      // For PREMIUM_WEEK, PREMIUM_MONTH, BADGE, VIP_STATUS - 
      // these would be handled by the app logic when displaying user status

      // Mark reward as claimed
      await prisma.referralReward.update({
        where: { id: input.rewardId },
        data: { claimedAt: new Date() },
      });

      return {
        success: true,
        message: `${reward.type} reward claimed successfully!`,
        rewardType: reward.type,
        amount: reward.amount,
      };
    }),

  /**
   * Get available reward tiers (for displaying progress)
   */
  getRewardTiers: publicProcedure
    .query(async () => {
      return {
        tiers: REWARD_TIERS.map(tier => ({
          milestone: tier.milestone,
          type: tier.type,
          amount: tier.amount,
          description: tier.description,
        })),
      };
    }),
});

