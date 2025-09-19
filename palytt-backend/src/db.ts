import pkg from '@prisma/client';
const { PrismaClient } = pkg;

const globalForPrisma = globalThis as unknown as { prisma: InstanceType<typeof PrismaClient> };

// Check for DATABASE_URL and provide helpful error message
if (!process.env.DATABASE_URL) {
  const errorMessage = `
❌ DATABASE_URL environment variable is not set!

For Railway deployment, you need to:
1. Go to your Railway project dashboard
2. Navigate to Variables tab
3. Add DATABASE_URL with your PostgreSQL connection string

Example format: postgresql://username:password@host:port/database

For local development, create a .env file with:
DATABASE_URL="postgresql://palytt:palytt_password@localhost:5432/palytt_db"
  `;
  
  console.error(errorMessage);
  
  // In production, we should fail fast
  if (process.env.NODE_ENV === 'production') {
    process.exit(1);
  }
}

export const prisma =
  globalForPrisma.prisma ||
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
    datasources: {
      db: {
        url: process.env.DATABASE_URL,
      },
    },
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}

// Test database connection on startup
prisma.$connect()
  .then(() => {
    console.log('✅ Database connected successfully');
  })
  .catch((error) => {
    console.error('❌ Database connection failed:', error.message);
    if (process.env.NODE_ENV === 'production') {
      process.exit(1);
    }
  });

// Helper function to ensure user exists or create one
export async function ensureUser(clerkId: string, email: string, username?: string | null) {
  return await prisma.user.upsert({
    where: { clerkId },
    update: {}, // Don't update anything if user exists
    create: {
      clerkId,
      email,
      username: username || null,
    },
  });
} 