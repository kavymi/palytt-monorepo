#!/bin/sh
set -e

echo "🔄 Running database migrations..."
# Use pnpm to run the project's installed prisma version (5.22.0)
pnpm exec prisma migrate deploy

echo "✅ Migrations complete!"
echo "🚀 Starting server..."
exec pnpm start

