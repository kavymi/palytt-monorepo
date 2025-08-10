#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Palytt Database Setup Script"
echo "================================"

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env file not found. Creating from example...${NC}"
    
    cat > .env << EOL
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
EOL
    
    echo -e "${GREEN}✅ Created .env file${NC}"
    echo -e "${YELLOW}⚠️  Please update CLERK_SECRET_KEY in .env with your actual key${NC}"
fi

# Install dependencies
echo -e "\n${YELLOW}📦 Installing dependencies...${NC}"
npm install

# Generate Prisma Client
echo -e "\n${YELLOW}🔧 Generating Prisma Client...${NC}"
npx prisma generate

# Check if PostgreSQL is running
echo -e "\n${YELLOW}🔍 Checking PostgreSQL connection...${NC}"
if pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PostgreSQL is running${NC}"
else
    echo -e "${RED}❌ PostgreSQL is not running on localhost:5432${NC}"
    echo "Please start PostgreSQL or run: docker-compose up -d postgres"
    exit 1
fi

# Push database schema
echo -e "\n${YELLOW}📊 Creating database tables...${NC}"
npx prisma db push

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Database tables created successfully${NC}"
else
    echo -e "${RED}❌ Failed to create database tables${NC}"
    echo "Please check your DATABASE_URL in .env"
    exit 1
fi

# Optional: Open Prisma Studio
echo -e "\n${GREEN}✅ Database setup complete!${NC}"
echo -e "\nYou can now:"
echo "  - Run the server: npm run dev"
echo "  - View database: npx prisma studio"
echo "  - Run migrations: npx prisma migrate dev"

echo -e "\n${YELLOW}Would you like to open Prisma Studio now? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    npx prisma studio
fi 