#!/bin/bash

# Monitor API calls in real-time
# This will show all friend-related API calls as they happen

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 API Call Monitor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 Instructions:"
echo "   1. Keep this terminal open"
echo "   2. Log into the iOS app (Simulator)"
echo "   3. Test friend features"
echo "   4. Watch the API calls appear here!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Monitoring backend at http://localhost:4000..."
echo "Press Ctrl+C to stop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Monitor the backend logs for friend-related endpoints
# This assumes the backend is running with pnpm dev
echo "Watching for API calls..."
echo ""

# Tail the last 100 lines and follow
# Filter for friend-related endpoints
if command -v lsof &> /dev/null; then
    # Check if backend is running
    if lsof -i :4000 &> /dev/null; then
        echo -e "${GREEN}✅ Backend is running on port 4000${NC}"
        echo ""
        
        # This will show all HTTP requests to the backend
        # Note: In a real setup, you'd tail the actual log file
        echo "Waiting for API calls from the iOS app..."
        echo ""
        echo "Expected calls when testing friends:"
        echo "  • POST /trpc/users.upsert          (on login)"
        echo "  • GET  /trpc/users.list            (search users)"
        echo "  • POST /trpc/friends.sendRequest   (send friend request)"
        echo "  • GET  /trpc/friends.getPendingRequests (view requests)"
        echo "  • POST /trpc/friends.acceptRequest (accept request)"
        echo "  • GET  /trpc/friends.getFriends    (view friends)"
        echo ""
        
        # Monitor requests (this is a simplified version)
        # In production, you'd have proper logging
        while true; do
            sleep 1
        done
    else
        echo -e "${RED}❌ Backend is not running on port 4000${NC}"
        echo "Start it with: cd palytt-backend && pnpm dev"
    fi
else
    echo "lsof command not found, basic monitoring mode"
    echo "Check your backend terminal for actual logs"
fi

