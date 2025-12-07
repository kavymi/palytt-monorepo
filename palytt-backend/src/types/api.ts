import type { inferRouterInputs, inferRouterOutputs } from '@trpc/server';
import type { AppRouter } from '../routers/app.js';

/**
 * Type-safe API types exported from the backend
 * 
 * These types can be used by:
 * - Frontend clients (web, iOS) for type-safe API calls
 * - Type generation scripts
 * - Documentation generators
 */

/**
 * The main app router type
 */
export type { AppRouter };

/**
 * Infer input types for all router procedures
 * 
 * Usage:
 * ```typescript
 * type CreateUserInput = RouterInput['users']['create'];
 * ```
 */
export type RouterInput = inferRouterInputs<AppRouter>;

/**
 * Infer output types for all router procedures
 * 
 * Usage:
 * ```typescript
 * type CreateUserOutput = RouterOutput['users']['create'];
 * type User = RouterOutput['users']['getById'];
 * ```
 */
export type RouterOutput = inferRouterOutputs<AppRouter>;

/**
 * Helper type to extract input type for a specific procedure
 * 
 * Usage:
 * ```typescript
 * type Input = ProcedureInput<'users', 'create'>;
 * ```
 */
export type ProcedureInput<
  TRouter extends keyof RouterInput,
  TProcedure extends keyof RouterInput[TRouter]
> = RouterInput[TRouter][TProcedure];

/**
 * Helper type to extract output type for a specific procedure
 * 
 * Usage:
 * ```typescript
 * type Output = ProcedureOutput<'users', 'create'>;
 * ```
 */
export type ProcedureOutput<
  TRouter extends keyof RouterOutput,
  TProcedure extends keyof RouterOutput[TRouter]
> = RouterOutput[TRouter][TProcedure];

