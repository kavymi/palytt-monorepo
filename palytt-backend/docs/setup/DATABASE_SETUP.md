# Database Setup Guide

## Prerequisites
- PostgreSQL running on port 5432
- Node.js 18.12 or higher
- pnpm or npm

## Setup Instructions

### 1. Create Environment File
Create a `.env` file in the backend directory with the following content:

```env
# Database
DATABASE_URL="postgresql://palytt:palytt_password@localhost:5432/palytt_db"

# Server
NODE_ENV=development
PORT=4000
HOST=0.0.0.0

# CORS
CORS_ORIGIN=http://localhost:3000,http://localhost:5173

# Clerk (replace with your actual Clerk secret key)
CLERK_SECRET_KEY=your_clerk_secret_key_here
```

### 2. Install Dependencies
```bash
# Using npm (since Node version is 18.3.0)
npm install

# Or if you have a newer Node version, use pnpm:
pnpm install
```

### 3. Generate Prisma Client
```bash
npx prisma generate
```

### 4. Create Database Tables
```bash
# Push the schema to your database
npx prisma db push

# Or use migrations (recommended for production)
npx prisma migrate dev --name init
```

### 5. Verify Database Connection
```bash
# Open Prisma Studio to view your database
npx prisma studio
```

### 6. Start the Backend Server
```bash
npm run dev
```

## Docker Setup (Alternative)

If you prefer to use Docker for PostgreSQL:

```bash
# Start PostgreSQL using docker-compose
docker-compose up -d postgres

# The database will be available at:
# Host: localhost
# Port: 5432
# Database: palytt_db
# User: palytt
# Password: palytt_password
```

## Troubleshooting

### Connection Refused Error
- Ensure PostgreSQL is running: `pg_isready -h localhost -p 5432`
- Check if the database exists: `psql -U palytt -d palytt_db -c "\l"`

### Permission Denied
- Make sure the user has proper permissions:
```sql
CREATE USER palytt WITH PASSWORD 'palytt_password';
CREATE DATABASE palytt_db OWNER palytt;
GRANT ALL PRIVILEGES ON DATABASE palytt_db TO palytt;
```

### Prisma Client Not Found
- Run `npx prisma generate` after installing dependencies
- Make sure @prisma/client is installed

## Next Steps
After setting up the database, the backend will use PostgreSQL instead of in-memory storage for:
- Posts
- Users  
- Comments
- Likes
- Bookmarks

All data will now persist between server restarts! 