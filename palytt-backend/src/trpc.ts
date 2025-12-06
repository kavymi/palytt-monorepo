import { initTRPC } from '@trpc/server';
import type { CreateFastifyContextOptions } from '@trpc/server/adapters/fastify';
import { verifyToken } from '@clerk/backend';
import { updateUserActivity } from './services/reengagementService.js';

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
  
  // Debug logging for authentication
  console.log('🔐 Auth Debug:', {
    hasAuthHeader: !!authHeader,
    authHeaderPrefix: authHeader?.substring(0, 20),
    hasClerkUserId: !!clerkUserId,
    clerkUserId: clerkUserId,
  });
  
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
        console.log('🔑 Attempting to validate Clerk JWT token...');
        user = await validateClerkToken(token);
        if (user) {
          console.log('✅ Token validated successfully for user:', user.clerkId);
        } else {
          console.log('❌ Token validation returned null');
        }
      } catch (error) {
        console.error('Token verification failed:', error);
        // Don't throw here - let procedures handle authentication as needed
      }
    }
  } else {
    console.log('⚠️ No Bearer token found in Authorization header');
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
 * Also updates user activity for re-engagement tracking
 */
const isAuthed = middleware(async ({ ctx, next }) => {
  if (!ctx.user) {
    throw new Error('Unauthorized - Please sign in');
  }
  
  // Update user activity for re-engagement notifications (non-blocking)
  updateUserActivity(ctx.user.clerkId).catch(() => {
    // Silently ignore errors - activity tracking should not block requests
  });
  
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
    
    // Get the publishable key to derive the issuer URL
    // The publishable key contains the Clerk instance URL (base64 encoded after the prefix)
    const publishableKey = process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY || process.env.CLERK_PUBLISHABLE_KEY;
    
    // Derive issuer from publishable key if available
    let issuer: string | undefined;
    if (publishableKey) {
      try {
        // Extract the base64 part after pk_test_ or pk_live_
        const base64Part = publishableKey.replace(/^pk_(test|live)_/, '');
        const decoded = Buffer.from(base64Part, 'base64').toString('utf-8').replace(/\0/g, '');
        // The decoded value is the Clerk frontend API domain (e.g., "natural-walleye-48.clerk.accounts.dev")
        if (decoded && decoded.includes('clerk')) {
          issuer = `https://${decoded}`;
          console.log('🔗 Using Clerk issuer:', issuer);
        }
      } catch (e) {
        console.warn('Could not derive issuer from publishable key');
      }
    }
    
    // Verify the session token using Clerk's backend SDK
    const payload = await verifyToken(token, {
      secretKey,
      ...(issuer && { issuer }),
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