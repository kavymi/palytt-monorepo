import { z } from 'zod';

/**
 * Common schemas used across multiple routers
 */

/**
 * Pagination input schema
 */
export const PaginationInputSchema = z.object({
  page: z.number().int().positive().default(1),
  limit: z.number().int().positive().max(100).default(20),
});

/**
 * Pagination output schema
 */
export const PaginationOutputSchema = z.object({
  page: z.number().int().positive(),
  limit: z.number().int().positive(),
  total: z.number().int().nonnegative(),
  totalPages: z.number().int().nonnegative(),
});

/**
 * Success response schema
 */
export const SuccessResponseSchema = z.object({
  success: z.boolean(),
  message: z.string().optional(),
});

/**
 * Timestamp fields (ISO strings)
 */
export const TimestampSchema = z.object({
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
});

/**
 * Location schema
 */
export const LocationSchema = z.object({
  latitude: z.number(),
  longitude: z.number(),
  address: z.string(),
  name: z.string().optional(),
});

/**
 * UUID parameter schema
 */
export const UuidParamSchema = z.object({
  id: z.string().uuid(),
});

/**
 * Clerk ID parameter schema
 */
export const ClerkIdParamSchema = z.object({
  clerkId: z.string().min(1),
});

