import Fastify from 'fastify';
import cors from '@fastify/cors';
import websocket from '@fastify/websocket';
import { fastifyTRPCPlugin } from '@trpc/server/adapters/fastify';
import { createContext } from './trpc.js';
import { appRouter } from './routers/app.js';

const server = Fastify({
  logger: {
    level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
    transport: process.env.NODE_ENV !== 'production' 
      ? {
          target: 'pino-pretty',
          options: {
            colorize: true,
            translateTime: 'HH:MM:ss Z',
            ignore: 'pid,hostname',
          },
        }
      : undefined,
  },
  maxParamLength: 5000,
});

// Register plugins
await server.register(cors, {
  origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000', 'http://localhost:5173'],
  credentials: true,
});

// Register WebSocket support for subscriptions
await server.register(websocket);

// Register tRPC
await server.register(fastifyTRPCPlugin, {
  prefix: '/trpc',
  trpcOptions: {
    router: appRouter,
    createContext,
    onError({ path, error }: { path?: string; error: Error }) {
      console.error(`Error in tRPC handler on path '${path}':`, error);
    },
  },
  useWSS: true, // Enable WebSocket support
});

// Health check endpoint
server.get('/health', async () => {
  return { 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  };
});

// Root endpoint
server.get('/', async () => {
  return { 
    message: 'Palytt Backend API',
    version: '0.1.0',
    endpoints: {
      health: '/health',
      trpc: '/trpc',
    },
  };
});

// Start server
const start = async () => {
  try {
    const port = process.env.PORT ? parseInt(process.env.PORT, 10) : 4000;
    const host = process.env.HOST || '0.0.0.0';
    
    await server.listen({ port, host });
    
    console.log(`
🚀 Server ready at: http://localhost:${port}
⚡ tRPC endpoint: http://localhost:${port}/trpc
🌐 tRPC panel: http://localhost:${port}/trpc/panel
💓 Health check: http://localhost:${port}/health
    `);
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
};

// Handle graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');
  await server.close();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully...');
  await server.close();
  process.exit(0);
});

start(); 