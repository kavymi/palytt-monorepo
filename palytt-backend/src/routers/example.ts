import { z } from 'zod';
import { router, publicProcedure } from '../trpc.js';

export const exampleRouter = router({
  /**
   * Simple query example
   */
  hello: publicProcedure
    .input(
      z.object({
        name: z.string().optional(),
      })
    )
    .query(({ input }) => {
      return {
        greeting: `Hello ${input.name ?? 'World'}!`,
        timestamp: new Date().toISOString(),
      };
    }),

  /**
   * Query with more complex validation
   */
  getUser: publicProcedure
    .input(
      z.object({
        id: z.string().uuid(),
      })
    )
    .query(async ({ input }) => {
      // In a real app, you'd fetch from database
      return {
        id: input.id,
        name: 'John Doe',
        email: 'john@example.com',
        createdAt: new Date().toISOString(),
      };
    }),

  /**
   * Mutation example
   */
  createUser: publicProcedure
    .input(
      z.object({
        name: z.string().min(1).max(100),
        email: z.string().email(),
        age: z.number().int().positive().optional(),
      })
    )
    .mutation(async ({ input }) => {
      // In a real app, you'd save to database
      const newUser = {
        id: crypto.randomUUID(),
        ...input,
        createdAt: new Date().toISOString(),
      };
      
      return {
        success: true,
        user: newUser,
      };
    }),

  /**
   * List query with pagination
   */
  listUsers: publicProcedure
    .input(
      z.object({
        page: z.number().int().positive().default(1),
        limit: z.number().int().positive().max(100).default(10),
        search: z.string().optional(),
      })
    )
    .query(async ({ input }) => {
      // Mock data - replace with database query
      const users = Array.from({ length: 50 }, (_, i) => ({
        id: crypto.randomUUID(),
        name: `User ${i + 1}`,
        email: `user${i + 1}@example.com`,
        createdAt: new Date(Date.now() - i * 24 * 60 * 60 * 1000).toISOString(),
      }));

      // Apply search filter
      const filtered = input.search
        ? users.filter(u => 
            u.name.toLowerCase().includes(input.search!.toLowerCase()) ||
            u.email.toLowerCase().includes(input.search!.toLowerCase())
          )
        : users;

      // Apply pagination
      const start = (input.page - 1) * input.limit;
      const end = start + input.limit;
      const paginatedUsers = filtered.slice(start, end);

      return {
        users: paginatedUsers,
        pagination: {
          page: input.page,
          limit: input.limit,
          total: filtered.length,
          totalPages: Math.ceil(filtered.length / input.limit),
        },
      };
    }),
}); 