FROM node:20-alpine AS base

# Install OpenSSL and other necessary libraries for Prisma
RUN apk add --no-cache openssl openssl-dev libc6-compat

# Install pnpm
RUN corepack enable
RUN corepack prepare pnpm@latest --activate

# Set working directory
WORKDIR /app

# Development stage
FROM base AS development

# Copy package files
COPY package.json pnpm-lock.yaml* ./

# Install ALL dependencies (including devDependencies)
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Generate Prisma client
RUN pnpm prisma:generate

EXPOSE 4000
CMD ["pnpm", "dev"]

# Builder stage
FROM base AS builder

# Copy package files
COPY package.json pnpm-lock.yaml* ./

# Install ALL dependencies for building
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Generate Prisma client
RUN pnpm prisma:generate

# Build the application
RUN pnpm build

# Production stage
FROM node:20-alpine AS production

# Install OpenSSL and other necessary libraries for Prisma
RUN apk add --no-cache openssl openssl-dev libc6-compat

RUN corepack enable
RUN corepack prepare pnpm@latest --activate

WORKDIR /app

# Set production environment variables
ENV NODE_ENV=production
ENV IS_DOCKER=true

# Copy package files and install ALL dependencies (needed for Prisma CLI and generation)
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile

# Copy schema and generate Prisma client
COPY prisma ./prisma
RUN pnpm prisma:generate

# Copy built application
COPY --from=builder /app/dist ./dist

# Copy startup script
COPY start.sh ./start.sh
RUN chmod +x ./start.sh

EXPOSE 4000
CMD ["./start.sh"] 