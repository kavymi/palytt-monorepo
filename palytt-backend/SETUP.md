# Palytt Backend Setup Guide

## ⚠️ Current Status

The backend is functional but requires proper security configuration before production use.

### Security Warning
The current JWT validation is **temporary and insecure**. It's suitable for development only.

## 🚨 Node.js Version Requirement

**IMPORTANT**: The backend requires Node.js v18.12+ to run. The current Fastify version (5.x) is incompatible with older Node.js versions.

If you see this error:
```
TypeError: diagnostics.tracingChannel is not a function
```

You MUST update Node.js before proceeding.

## 🚀 Quick Start (Development)

### 1. Update Node.js (REQUIRED)
```bash
# Check your current version
node --version

# If less than v18.12, update using nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 18.12
nvm use 18.12

# Or with Homebrew on macOS:
brew install node@18
brew link --overwrite node@18
```

### 2. Create Environment File
```bash
# Copy the example file
cp .env.example .env

# Edit .env and add your Clerk secret key
# Get it from: https://dashboard.clerk.com/apps/YOUR_APP/instances/YOUR_INSTANCE/api-keys
```

### 3. Install Dependencies
```bash
# With updated Node.js:
pnpm install

# Or if pnpm still has issues:
npm install
```

### 4. Start the Server
```bash
pnpm dev
# or
npm run dev
```

## 🔒 Production Setup

### Prerequisites
- Node.js v18.12+ (REQUIRED - backend won't run without this)
- Clerk account with secret key
- PostgreSQL database (optional for now)

### 1. Install Production Dependencies
```bash
pnpm add @clerk/backend
```

### 2. Update JWT Verification
Replace the temporary JWT validation in `src/trpc.ts` with:

```typescript
import { verifyToken } from '@clerk/backend';

async function validateClerkToken(token: string): Promise<AuthenticatedUser | null> {
  try {
    const payload = await verifyToken(token, {
      secretKey: process.env.CLERK_SECRET_KEY,
    });
    
    if (!payload.sub) {
      return null;
    }
    
    return {
      clerkId: payload.sub,
    };
  } catch (error) {
    console.error('Clerk token verification failed:', error);
    return null;
  }
}
```

### 3. Environment Variables (Production)
```env
# Production values
CLERK_PUBLISHABLE_KEY=pk_live_YOUR_KEY
CLERK_SECRET_KEY=sk_live_YOUR_SECRET_KEY
NODE_ENV=production
PORT=4000

# CORS (adjust for your domains)
CORS_ORIGIN=https://yourdomain.com,capacitor://localhost
```

## 🧪 Testing Authentication

### 1. Test Health Endpoint
```bash
curl http://localhost:4000/health
# Should return: {"status":"ok"}
```

### 2. Test tRPC Panel
Open http://localhost:4000/trpc/panel in your browser

### 3. Test Protected Endpoint
```bash
# Get a session token from your frontend first
curl -H "Authorization: Bearer YOUR_SESSION_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{}' \
  http://localhost:4000/trpc/posts.list
```

## 📝 API Endpoints

### User Management (Public)
- `users.upsert` - Create/update user
- `users.upsertByAppleId` - Apple Sign-In specific
- `users.upsertByGoogleId` - Google Sign-In specific
- `users.getByClerkId` - Get user by Clerk ID

### Posts (Protected - Requires Authentication)
- `posts.create` - Create new post
- `posts.list` - List posts
- `posts.update` - Update post
- `posts.delete` - Delete post

## 🐛 Troubleshooting

### Node.js Version Error
If you see: `TypeError: diagnostics.tracingChannel is not a function`

**Solution**: You MUST update Node.js to v18.12 or higher. Fastify 5.x requires newer Node.js APIs.

### pnpm Version Error
If you see: "This version of pnpm requires at least Node.js v18.12"

**Solution**: Update Node.js first, then pnpm will work.

### Cannot Find Module Error
If you see module resolution errors:

```bash
# Clear node_modules and reinstall
rm -rf node_modules pnpm-lock.yaml
pnpm install
```

### JWT Validation Warnings
If you see: "Using INSECURE JWT validation"

**This is expected** in development until @clerk/backend is installed. The temporary validation allows development to continue but should NEVER be used in production.

## 🔄 Next Steps

1. **Immediate**
   - Update Node.js to v18.12+
   - Create .env file with Clerk keys
   - Test all authentication flows

2. **Before Beta**
   - Install @clerk/backend
   - Replace temporary JWT validation
   - Set up PostgreSQL database
   - Add Prisma ORM

3. **Before Production**
   - Security audit
   - Rate limiting
   - Error monitoring (Sentry)
   - Health checks and metrics

## 📚 Resources

- [Node.js Installation Guide](https://nodejs.org/en/download/package-manager)
- [Clerk Backend SDK](https://clerk.com/docs/backend-requests/handling/nodejs)
- [tRPC Documentation](https://trpc.io/docs)
- [Fastify Documentation](https://fastify.dev/) 