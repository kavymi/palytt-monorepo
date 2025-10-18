# Palytt Backend Documentation

**Last Updated:** October 19, 2025

This directory contains all documentation for the Palytt backend Node.js/tRPC API. The documentation is organized into the following categories:

---

## 📂 Documentation Structure

### ⚙️ [Setup](./setup/)

Installation, configuration, and database setup:

- **[DATABASE_SETUP.md](./setup/DATABASE_SETUP.md)** - PostgreSQL database setup and configuration guide

### 🔌 [Integration](./integration/)

Frontend integration, authentication, and API connection docs:

- **[INTEGRATION_COMPLETE.md](./integration/INTEGRATION_COMPLETE.md)** - Frontend-backend integration completion
- **[AUTHENTICATION_COMPLETED.md](./integration/AUTHENTICATION_COMPLETED.md)** - Authentication system implementation details
- **[BOOKMARK_ISSUE_RESOLVED.md](./integration/BOOKMARK_ISSUE_RESOLVED.md)** - Bookmark feature bug fixes

---

## 🚀 Quick Start

### Local Development Setup

1. **Prerequisites:**
   ```bash
   node >= 18.x
   pnpm >= 8.x
   postgresql >= 14.x
   ```

2. **Install dependencies:**
   ```bash
   cd palytt-backend
   pnpm install
   ```

3. **Setup database:**
   Follow the [DATABASE_SETUP.md](./setup/DATABASE_SETUP.md) guide

4. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. **Run migrations:**
   ```bash
   pnpm prisma migrate dev
   ```

6. **Start development server:**
   ```bash
   pnpm dev
   ```

7. **Access endpoints:**
   - **API:** http://localhost:4000
   - **tRPC Panel:** http://localhost:4000/trpc/panel
   - **Health Check:** http://localhost:4000/health

---

## 📖 API Documentation

### Architecture Overview

The backend uses the following stack:

- **Framework:** Fastify (high-performance Node.js web framework)
- **API Layer:** tRPC (end-to-end typesafe APIs)
- **Database:** PostgreSQL via Prisma ORM
- **Authentication:** Clerk JWT validation
- **Real-time:** WebSocket support via Fastify WebSocket plugin

### Directory Structure

```
palytt-backend/
├── src/
│   ├── routers/           # tRPC route handlers
│   │   ├── users.ts       # User management
│   │   ├── posts.ts       # Post CRUD
│   │   ├── comments.ts    # Comments
│   │   ├── messages.ts    # Messaging
│   │   ├── friends.ts     # Friend requests
│   │   ├── follows.ts     # Follow relationships
│   │   ├── notifications.ts # Notifications
│   │   ├── places.ts      # Location/places
│   │   ├── lists.ts       # User lists
│   │   └── app.ts         # Router composition
│   ├── services/          # Business logic (recommended to add)
│   ├── db.ts             # Prisma client
│   ├── trpc.ts           # tRPC configuration
│   └── index.ts          # Server entry point
├── prisma/
│   ├── schema.prisma     # Database schema
│   └── migrations/       # Migration files
└── dist/                 # Compiled output
```

### Available Routers

#### Users Router (`users.ts`)
- User CRUD operations
- Profile management
- User search

#### Posts Router (`posts.ts`)
- Post creation and management
- Feed generation
- Like/bookmark functionality

#### Comments Router (`comments.ts`)
- Comment CRUD
- Nested comments support

#### Messages Router (`messages.ts`)
- Direct messaging
- Group chats
- Message history

#### Friends Router (`friends.ts`)
- Friend requests
- Friend list management
- Mutual friends

#### Follows Router (`follows.ts`)
- Follow/unfollow users
- Follower/following lists

#### Notifications Router (`notifications.ts`)
- Notification delivery
- Read status management

#### Places Router (`places.ts`)
- Location data
- Place search

#### Lists Router (`lists.ts`)
- Custom user lists
- List sharing

---

## 🔐 Authentication

The backend uses Clerk for authentication. See [AUTHENTICATION_COMPLETED.md](./integration/AUTHENTICATION_COMPLETED.md) for details.

### Auth Flow

1. Client authenticates with Clerk (iOS app)
2. Client receives JWT token
3. Client includes token in `Authorization: Bearer <token>` header
4. Backend validates token with Clerk
5. User context injected into tRPC context

### Protected Procedures

```typescript
// Example from src/trpc.ts
export const protectedProcedure = t.procedure.use(async ({ ctx, next }) => {
  if (!ctx.user) {
    throw new TRPCError({ code: 'UNAUTHORIZED' });
  }
  return next({
    ctx: {
      user: ctx.user,
    },
  });
});
```

---

## 🗄️ Database Schema

### Core Models

- **User** - User accounts and profiles
- **Post** - User-generated content posts
- **Comment** - Post comments
- **Like** - Post likes
- **Bookmark** - Saved posts
- **List** - Custom user lists
- **Friend** - Friend relationships
- **Follow** - Follow relationships
- **Message** - Direct messages
- **Chatroom** - Chat conversations
- **Notification** - User notifications

See `prisma/schema.prisma` for full schema details.

### Running Migrations

```bash
# Create a new migration
pnpm prisma migrate dev --name migration_name

# Apply migrations in production
pnpm prisma migrate deploy

# Reset database (WARNING: deletes all data)
pnpm prisma migrate reset
```

---

## 🧪 Testing

### Running Tests

```bash
# Run all tests
pnpm test

# Run specific test file
pnpm test path/to/test.spec.ts

# Run with coverage
pnpm test:coverage
```

### Test Scripts

The backend can be tested using the included scripts:

```bash
# Test backend connectivity
./test-backend.sh
```

---

## 📊 Monitoring & Logging

### Logging

The backend uses Pino for structured logging:

```typescript
// Development: pretty-printed logs
// Production: JSON logs

server.log.info('Server started');
server.log.error({ err }, 'Error occurred');
```

### Health Check

Monitor backend health:

```bash
curl http://localhost:4000/health
```

Response:
```json
{
  "status": "ok",
  "timestamp": "2025-10-19T06:17:00.000Z",
  "uptime": 123.456
}
```

---

## 🚀 Deployment

### Environment Variables

Required for production:

```bash
# Database
DATABASE_URL=postgresql://user:password@host:5432/database

# Clerk Authentication
CLERK_SECRET_KEY=sk_live_xxxxx

# Server Configuration
NODE_ENV=production
PORT=4000

# CORS
CORS_ORIGIN=https://app.palytt.com
```

### Build for Production

```bash
# Install dependencies
pnpm install --prod

# Run Prisma generation
pnpm prisma generate

# Build TypeScript
pnpm build

# Start server
pnpm start
```

### Docker Deployment

```bash
# Build image
docker build -t palytt-backend .

# Run container
docker run -p 4000:4000 --env-file .env palytt-backend
```

Or use docker-compose:

```bash
docker-compose up -d
```

---

## 🔧 Development Tools

### tRPC Panel

Interactive API explorer available at: http://localhost:4000/trpc/panel

Use this to:
- Test API endpoints
- View request/response types
- Debug queries and mutations

### Prisma Studio

Visual database editor:

```bash
pnpm prisma studio
```

Opens at: http://localhost:5555

---

## 📚 Additional Resources

### Related Documentation

- **iOS Frontend Docs:** `palytt/docs/`
- **Architecture Analysis:** `palytt/docs/architecture/ARCHITECTURE_ANALYSIS.md`
- **Frontend Integration:** `palytt/docs/integration/`

### External Documentation

- [tRPC Documentation](https://trpc.io/docs)
- [Prisma Documentation](https://www.prisma.io/docs)
- [Fastify Documentation](https://www.fastify.io/docs/latest/)
- [Clerk Documentation](https://clerk.com/docs)

---

## 🐛 Troubleshooting

### Common Issues

**Database connection errors:**
- Verify `DATABASE_URL` is correct
- Ensure PostgreSQL is running
- Check database exists and user has permissions

**Authentication errors:**
- Verify `CLERK_SECRET_KEY` is set
- Check Clerk dashboard for API key
- Ensure client sends proper JWT token

**Type errors:**
- Run `pnpm prisma generate` after schema changes
- Restart TypeScript server in IDE
- Clear `node_modules` and reinstall

**Port already in use:**
- Change `PORT` in `.env`
- Kill existing process: `lsof -ti:4000 | xargs kill`

---

## 💡 Need Help?

- **Setup issues:** Review [DATABASE_SETUP.md](./setup/DATABASE_SETUP.md)
- **Integration issues:** Review [integration](./integration/) directory
- **Architecture questions:** Review frontend's [ARCHITECTURE_ANALYSIS.md](../palytt/docs/architecture/ARCHITECTURE_ANALYSIS.md)

---

## 🤝 Contributing

When adding new features:

1. **Define types** in Prisma schema first
2. **Run migrations** to update database
3. **Create tRPC router** for new endpoints
4. **Add validation** using Zod schemas
5. **Update documentation** in this directory
6. **Write tests** for new functionality
7. **Update frontend types** via tRPC


