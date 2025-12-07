import { z } from 'zod';
import { LocationSchema, TimestampSchema } from './common.schema.js';
import { UserInfoSchema } from './user.schema.js';

/**
 * Post-related schemas
 */

/**
 * Mention schema
 */
export const MentionSchema = z.object({
  type: z.string(),
  text: z.string(),
  targetId: z.string(),
  start: z.number().int().nonnegative(),
  end: z.number().int().nonnegative(),
});

/**
 * Create post input schema
 */
export const CreatePostInputSchema = z.object({
  shopName: z.string().min(1),
  foodItem: z.string().min(1),
  description: z.string().optional(),
  rating: z.number().min(1).max(5),
  imageUrl: z.string().url().optional(),
  imageUrls: z.array(z.string().url()),
  tags: z.array(z.string()),
  location: LocationSchema.optional(),
  isPublic: z.boolean().default(true),
  mentions: z.array(MentionSchema).optional(),
});

/**
 * Post response schema
 */
export const PostResponseSchema = z.object({
  id: z.string().uuid(),
  authorId: z.string().uuid(),
  authorClerkId: z.string().min(1),
  shopId: z.string().uuid().nullable(),
  shopName: z.string(),
  foodItem: z.string(),
  description: z.string().nullable(),
  rating: z.number().min(1).max(5).nullable(),
  imageUrl: z.string().url().nullable(),
  imageUrls: z.array(z.string().url()),
  tags: z.array(z.string()),
  location: LocationSchema.nullable(),
  isPublic: z.boolean(),
  likesCount: z.number().int().nonnegative(),
  commentsCount: z.number().int().nonnegative(),
  savesCount: z.number().int().nonnegative().optional(),
  viewsCount: z.number().int().nonnegative().optional(),
  isLiked: z.boolean().optional(),
  isBookmarked: z.boolean().optional(),
  mentions: z.array(MentionSchema).optional(),
  createdAt: z.string(),
  updatedAt: z.string(),
  // Author information (if included)
  authorDisplayName: z.string().nullable().optional(),
  authorUsername: z.string().nullable().optional(),
  authorAvatarUrl: z.string().url().nullable().optional(),
});

/**
 * Create post response schema
 */
export const CreatePostResponseSchema = z.object({
  success: z.boolean(),
  post: PostResponseSchema,
});

/**
 * Post list response schema
 */
export const PostListResponseSchema = z.object({
  posts: z.array(PostResponseSchema),
  pagination: z.object({
    page: z.number().int().positive(),
    limit: z.number().int().positive(),
    total: z.number().int().nonnegative(),
    totalPages: z.number().int().nonnegative(),
  }).optional(),
  total: z.number().int().nonnegative().optional(),
  hasMore: z.boolean().optional(),
});

/**
 * Like response schema
 */
export const LikeResponseSchema = z.object({
  success: z.boolean(),
  isLiked: z.boolean(),
  likesCount: z.number().int().nonnegative(),
});

/**
 * Bookmark response schema
 */
export const BookmarkResponseSchema = z.object({
  success: z.boolean(),
  isBookmarked: z.boolean(),
});

/**
 * Post likes response schema
 */
export const PostLikesResponseSchema = z.object({
  users: z.array(UserInfoSchema),
  total: z.number().int().nonnegative(),
  hasMore: z.boolean(),
});

