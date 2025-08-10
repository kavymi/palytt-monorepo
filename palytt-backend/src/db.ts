import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ||
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}

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