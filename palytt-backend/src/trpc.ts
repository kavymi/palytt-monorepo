import { initTRPC } from '@trpc/server';
import type { CreateFastifyContextOptions } from '@trpc/server/adapters/fastify';
import { verifyToken } from '@clerk/backend';

/**
 * User interface for authenticated context
 */
export interface AuthenticatedUser {
  id: string;    // Generate a UUID or use clerkId as both
  clerkId: string;
}

/**
 * Context for tRPC procedures
 * This is where you'd add things like database connections, auth info, etc.
 */
export async function createContext({ req }: CreateFastifyContextOptions) {
  let user: AuthenticatedUser | null = null;
  
  // Extract authorization header
  const authHeader = req.headers.authorization;
  const clerkUserId = req.headers['x-clerk-user-id'];
  
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7); // Remove 'Bearer ' prefix
    
    // Development mode: Accept clerk_ prefixed tokens
    if (token.startsWith('clerk_') && clerkUserId && typeof clerkUserId === 'string') {
      console.log('⚠️ Using development authentication for user:', clerkUserId);
      user = {
        id: clerkUserId,
        clerkId: clerkUserId,
      };
    } else {
      try {
        // Production mode: Use Clerk's proper JWT verification
        user = await validateClerkToken(token);
      } catch (error) {
        console.error('Token verification failed:', error);
        // Don't throw here - let procedures handle authentication as needed
      }
    }
  }
  
  return {
    user,
    req,
  };
}

export type Context = Awaited<ReturnType<typeof createContext>>;

/**
 * Initialize tRPC instance
 */
const t = initTRPC.context<Context>().create();

/**
 * Export reusable router and procedure helpers
 */
export const router = t.router;
export const publicProcedure = t.procedure;
export const middleware = t.middleware;

/**
 * Authentication middleware
 */
const isAuthed = middleware(async ({ ctx, next }) => {
  if (!ctx.user) {
    throw new Error('Unauthorized - Please sign in');
  }
  
  return next({
    ctx: {
      ...ctx,
      user: ctx.user, // Now guaranteed to be non-null
    },
  });
});

/**
 * Protected procedure that requires authentication
 */
export const protectedProcedure = publicProcedure.use(isAuthed);

/**
 * Validate Clerk JWT token using the official Clerk backend SDK
 * This provides secure, production-ready authentication
 */
async function validateClerkToken(token: string): Promise<AuthenticatedUser | null> {
  try {
    // Get the secret key from environment
    const secretKey = process.env.CLERK_SECRET_KEY;
    
    if (!secretKey) {
      console.error('CLERK_SECRET_KEY is not set in environment variables');
      return null;
    }
    
    // Verify the session token using Clerk's backend SDK
    const payload = await verifyToken(token, {
      secretKey,
    });
    
    // The 'sub' claim contains the Clerk user ID
    if (!payload.sub) {
      console.warn('No subject claim in token');
      return null;
    }
    
    console.log('✅ Token verified for user:', payload.sub);
    
    return {
      id: payload.sub,      // Use clerkId as the id for simplicity
      clerkId: payload.sub,
    };
  } catch (error) {
    // Log specific error types for debugging
    if (error instanceof Error) {
      if (error.message.includes('expired')) {
        console.warn('Token expired');
      } else if (error.message.includes('invalid')) {
        console.warn('Invalid token signature');
      } else {
        console.error('Token verification error:', error.message);
      }
    }
    return null;
  }
}

// Rate limiting middleware (simple in-memory implementation)
const rateLimitMap = new Map<string, { count: number; resetTime: number }>();

const rateLimited = middleware(async ({ ctx, next }) => {
  const forwardedFor = ctx.req.headers['x-forwarded-for'];
  const identifier = ctx.user?.clerkId || 
    (Array.isArray(forwardedFor) ? forwardedFor[0] : forwardedFor) || 
    'anonymous';
  const now = Date.now();
  const limit = rateLimitMap.get(identifier);
  
  if (limit && limit.resetTime > now) {
    if (limit.count >= 100) { // 100 requests per minute
      throw new Error('Rate limit exceeded');
    }
    limit.count++;
  } else {
    rateLimitMap.set(identifier, { count: 1, resetTime: now + 60000 }); // Reset after 1 minute
  }
  
  // Clean up old entries periodically
  if (rateLimitMap.size > 1000) {
    for (const [key, value] of rateLimitMap.entries()) {
      if (value.resetTime < now) {
        rateLimitMap.delete(key);
      }
    }
  }
  
  return next();
});

/**
 * Enhanced procedures with rate limiting
 */
export const rateLimitedProcedure = publicProcedure.use(rateLimited);
export const protectedRateLimitedProcedure = protectedProcedure.use(rateLimited); 