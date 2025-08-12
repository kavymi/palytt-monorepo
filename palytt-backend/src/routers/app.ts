import { router } from '../trpc.js';
import { exampleRouter } from './example.js';
import { usersRouter } from './users.js';
import { postsRouter } from './posts.js';
import { commentsRouter } from './comments.js';
import { friendsRouter } from './friends.js';
import { followsRouter } from './follows.js';
import { messagesRouter } from './messages.js';
import { notificationsRouter } from './notifications.js';
import { placesRouter } from './places.js';
import { listsRouter } from './lists.js';

/**
 * Main app router
 * 
 * Add your routers here as your API grows
 */
export const appRouter = router({
  example: exampleRouter,
  users: usersRouter,
  posts: postsRouter,
  comments: commentsRouter,
  friends: friendsRouter,
  follows: followsRouter,
  messages: messagesRouter,
  notifications: notificationsRouter,
  places: placesRouter,
  lists: listsRouter,
  // Add more routers here:
  // auth: authRouter,
  // shops: shopsRouter,
});

/**
 * Export type definition of the entire API
 * This is used by the client to have full typesafety
 */
export type AppRouter = typeof appRouter; 