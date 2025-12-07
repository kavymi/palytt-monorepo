import { z } from 'zod';

/**
 * Shared enum schemas used across backend and Convex
 */

/**
 * Friend status enum
 */
export const FriendStatusEnum = z.enum(['PENDING', 'ACCEPTED', 'BLOCKED']);

/**
 * Message type enum
 */
export const MessageTypeEnum = z.enum([
  'TEXT',
  'IMAGE',
  'VIDEO',
  'AUDIO',
  'FILE',
  'POST_SHARE',
  'PLACE_SHARE',
  'LINK_SHARE',
]);

/**
 * Chatroom type enum
 */
export const ChatroomTypeEnum = z.enum(['DIRECT', 'GROUP']);

/**
 * Notification type enum
 */
export const NotificationTypeEnum = z.enum([
  'POST_LIKE',
  'COMMENT',
  'COMMENT_LIKE',
  'FOLLOW',
  'FRIEND_REQUEST',
  'FRIEND_ACCEPTED',
  'FRIEND_POST',
  'MESSAGE',
  'POST_MENTION',
  'GATHERING_INVITE',
  'GENERAL',
]);

/**
 * Gathering invite status enum
 */
export const GatheringInviteStatusEnum = z.enum([
  'PENDING',
  'ACCEPTED',
  'DECLINED',
  'EXPIRED',
]);

/**
 * Referral status enum
 */
export const ReferralStatusEnum = z.enum([
  'PENDING',
  'USED',
  'REWARDED',
  'EXPIRED',
]);

/**
 * Reward type enum
 */
export const RewardTypeEnum = z.enum([
  'STREAK_FREEZE',
  'PREMIUM_WEEK',
  'PREMIUM_MONTH',
  'BADGE',
  'VIP_STATUS',
]);

/**
 * Platform enum
 */
export const PlatformEnum = z.enum(['IOS', 'ANDROID', 'WEB']);

/**
 * Type exports for TypeScript usage
 */
export type FriendStatus = z.infer<typeof FriendStatusEnum>;
export type MessageType = z.infer<typeof MessageTypeEnum>;
export type ChatroomType = z.infer<typeof ChatroomTypeEnum>;
export type NotificationType = z.infer<typeof NotificationTypeEnum>;
export type GatheringInviteStatus = z.infer<typeof GatheringInviteStatusEnum>;
export type ReferralStatus = z.infer<typeof ReferralStatusEnum>;
export type RewardType = z.infer<typeof RewardTypeEnum>;
export type Platform = z.infer<typeof PlatformEnum>;

/**
 * Helper function to generate Convex-compatible literal union
 * This can be used to generate Convex schema validators
 */
export function getConvexNotificationTypes() {
  return [
    'POST_LIKE',
    'COMMENT',
    'COMMENT_LIKE',
    'FOLLOW',
    'FRIEND_REQUEST',
    'FRIEND_ACCEPTED',
    'FRIEND_POST',
    'MESSAGE',
    'POST_MENTION',
    'GATHERING_INVITE',
    'GENERAL',
  ] as const;
}

