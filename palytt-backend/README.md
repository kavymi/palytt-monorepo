# Palytt Backend

A modern, type-safe backend API built with tRPC, Fastify, and TypeScript.

## Features

- 🚀 **Fastify** - High-performance web framework
- 🔗 **tRPC v11** - End-to-end typesafe APIs
- 📝 **TypeScript** - Full type safety
- ✅ **Zod** - Runtime validation
- 🔄 **WebSocket Support** - Real-time subscriptions
- 🎯 **ES Modules** - Modern JavaScript modules
- 📦 **pnpm Workspace** - Integrated with monorepo
- 🗄️ **PostgreSQL** - Production-ready database with Prisma ORM
- 🔐 **Clerk** - Authentication and user management

## Getting Started

### Prerequisites

- Node.js 18+ 
- pnpm (this project uses pnpm workspaces)
- PostgreSQL 14+ (or use Docker Compose)

### Database Setup

#### Quick Setup (Recommended)

Run the automated setup script:

```bash
cd palytt-backend
./scripts/setup-db.sh
```

This will:
- Create a `.env` file if needed
- Install dependencies
- Generate Prisma Client
- Create database tables
- Optionally open Prisma Studio

#### Manual Setup

1. Ensure PostgreSQL is running on port 5432
2. Create `.env` file with your database credentials
3. Install dependencies: `npm install`
4. Generate Prisma Client: `npx prisma generate`
5. Create database tables: `npx prisma db push`

### Installation

From the root of the monorepo:

```bash
pnpm install
```

### Development

Start the development server:

```bash
cd palytt-backend
pnpm dev
```

The server will start on `http://localhost:4000` with:
- tRPC endpoint: `http://localhost:4000/trpc`
- Health check: `http://localhost:4000/health`

### Building

Build for production:

```bash
pnpm build
```

### Running in Production

```bash
pnpm start
```

## Environment Variables

Create a `.env` file in the backend directory:

```env
# Server Configuration
NODE_ENV=development
PORT=4000
HOST=0.0.0.0

# CORS Configuration
CORS_ORIGIN=http://localhost:3000,http://localhost:5173

# Database Configuration
POSTGRES_USER=palytt
POSTGRES_PASSWORD=palytt_password
POSTGRES_DB=palytt_db
DATABASE_URL=postgresql://palytt:palytt_password@localhost:5432/palytt_db

# Authentication
CLERK_SECRET_KEY=your_clerk_secret_key_here
```

## Project Structure

```
palytt-backend/
├── src/
│   ├── index.ts          # Main server file
│   ├── trpc.ts          # tRPC context and configuration
│   ├── db.ts            # Prisma database client
│   └── routers/
│       ├── app.ts       # Main app router
│       ├── posts.ts     # Posts router with CRUD operations
│       ├── users.ts     # Users router
│       └── example.ts   # Example router with sample procedures
├── prisma/
│   └── schema.prisma    # Database schema definition
├── scripts/
│   └── setup-db.sh      # Database setup script
├── dist/                # Production build output
├── docker-compose.yml   # Docker configuration
├── Dockerfile          # Container configuration
├── package.json
├── tsconfig.json
└── README.md
```

## API Structure

The API is organized into routers. The main router combines all sub-routers:

```typescript
// Access example endpoints:
trpc.example.hello({ name: "World" })
trpc.example.getUser({ id: "uuid" })
trpc.example.createUser({ name: "John", email: "john@example.com" })
trpc.example.listUsers({ page: 1, limit: 10 })
```

## Adding New Routers

1. Create a new router file in `src/routers/`:

```typescript
// src/routers/posts.ts
import { z } from 'zod';
import { router, publicProcedure } from '../trpc.js';

export const postsRouter = router({
  list: publicProcedure.query(() => {
    return { posts: [] };
  }),
});
```

2. Add it to the main app router:

```typescript
// src/routers/app.ts
import { postsRouter } from './posts.js';

export const appRouter = router({
  example: exampleRouter,
  posts: postsRouter, // Add here
});
```

## Type Safety

The backend exports its router type for use in frontend clients:

```typescript
import type { AppRouter } from '@palytt/backend/src/routers/app';
```

## Docker Support

The backend includes Docker and Docker Compose support with PostgreSQL database.

### Using Docker Compose

Start the services (backend + PostgreSQL):

```bash
docker-compose up -d
```

Stop the services:

```bash
docker-compose down
```

Stop and remove volumes (careful - this deletes the database):

```bash
docker-compose down -v
```

View logs:

```bash
docker-compose logs -f
```

### Docker Configuration

The `docker-compose.yml` includes:
- PostgreSQL 16 database
- Backend service with hot reload in development
- Health checks for database
- Persistent volume for database data
- Network isolation

## Scripts

- `pnpm dev` - Start development server with hot reload
- `pnpm build` - Build for production
- `pnpm start` - Run production build
- `pnpm typecheck` - Type check without building
- `pnpm lint` - Run ESLint
- `pnpm format` - Format code with Prettier 