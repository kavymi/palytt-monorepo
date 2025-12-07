import { z } from 'zod';
import { TimestampSchema } from './common.schema.js';

/**
 * User-related schemas
 */

/**
 * Base user schema matching Prisma User model
 */
export const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  username: z.string().min(1).max(50).nullable(),
  name: z.string().min(1).max(200).nullable(),
  bio: z.string().max(500).nullable(),
  profileImage: z.string().url().nullable(),
  website: z.string().url().nullable(),
  clerkId: z.string().min(1),
  followerCount: z.number().int().default(0),
  followingCount: z.number().int().default(0),
  postsCount: z.number().int().default(0),
  isVerified: z.boolean().default(false),
  isActive: z.boolean().default(true),
  createdAt: z.string(),
  updatedAt: z.string(),
});

/**
 * User info schema (minimal user data for includes)
 */
export const UserInfoSchema = z.object({
  id: z.string().uuid(),
  clerkId: z.string().min(1),
  username: z.string().nullable(),
  name: z.string().nullable(),
  profileImage: z.string().url().nullable(),
  bio: z.string().nullable(),
  isVerified: z.boolean().optional(),
});

/**
 * Create user input schema
 */
export const CreateUserSchema = z.object({
  email: z.string().email(),
  username: z.string().min(1).max(50).nullable().optional(),
  name: z.string().min(1).max(200).nullable().optional(),
  bio: z.string().max(500).nullable().optional(),
  profileImage: z.string().url().nullable().optional(),
  website: z.string().url().nullable().optional(),
  clerkId: z.string().min(1),
  // iOS app may send these additional fields - accept but ignore
  firstName: z.string().nullable().optional(),
  lastName: z.string().nullable().optional(),
  avatarUrl: z.string().nullable().optional(),
  appleId: z.string().nullable().optional(),
  googleId: z.string().nullable().optional(),
});

/**
 * Update user input schema
 */
export const UpdateUserSchema = z.object({
  username: z.string().min(1).max(50).nullable().optional(),
  name: z.string().min(1).max(200).nullable().optional(),
  bio: z.string().max(500).nullable().optional(),
  profileImage: z.string().url().nullable().optional(),
  website: z.string().url().nullable().optional(),
  // iOS app may send these additional fields
  firstName: z.string().nullable().optional(),
  lastName: z.string().nullable().optional(),
  avatarUrl: z.string().nullable().optional(),
  dietaryPreferences: z.array(z.string()).optional(),
});

/**
 * User response schema (for create/update responses)
 */
export const UserResponseSchema = z.object({
  success: z.boolean(),
  user: UserSchema,
  created: z.boolean().optional(),
  isNewUser: z.boolean().optional(),
});

/**
 * User list response schema
 */
export const UserListResponseSchema = z.object({
  users: z.array(UserSchema),
  pagination: z.object({
    page: z.number().int().positive(),
    limit: z.number().int().positive(),
    total: z.number().int().nonnegative(),
    totalPages: z.number().int().nonnegative(),
  }),
});

/**
 * User stats response schema
 */
export const UserStatsResponseSchema = z.object({
  postsCount: z.number().int().nonnegative(),
  commentsCount: z.number().int().nonnegative(),
  likesCount: z.number().int().nonnegative(),
  bookmarksCount: z.number().int().nonnegative(),
  followerCount: z.number().int().nonnegative(),
  followingCount: z.number().int().nonnegative(),
});

/**
 * Streak info response schema
 */
export const StreakInfoResponseSchema = z.object({
  currentStreak: z.number().int().nonnegative(),
  longestStreak: z.number().int().nonnegative(),
  lastPostDate: z.string().nullable(),
  isStreakActive: z.boolean(),
  daysSinceLastPost: z.number().int().nonnegative(),
  streakFreezeCount: z.number().int().nonnegative(),
  nextMilestone: z.number().int().positive().nullable(),
  achievedMilestones: z.array(z.number().int().positive()),
});

/**
 * Phone hash search response schema
 */
export const PhoneHashSearchResponseSchema = z.object({
  users: z.array(UserInfoSchema.extend({
    phoneHash: z.string().nullable(),
    followerCount: z.number().int().nonnegative(),
    followingCount: z.number().int().nonnegative(),
    postsCount: z.number().int().nonnegative(),
    isVerified: z.boolean(),
    isActive: z.boolean(),
  })),
  matchedHashes: z.array(z.string()),
});

/**
 * User search response schema
 */
export const UserSearchResponseSchema = z.array(
  UserSchema.extend({
    _id: z.string().uuid(),
    displayName: z.string().nullable(),
    firstName: z.string().nullable(),
    lastName: z.string().nullable(),
    avatarUrl: z.string().url().nullable(),
  })
);

