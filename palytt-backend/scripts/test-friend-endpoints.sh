#!/bin/bash

# Test Friend Endpoints Script
# This script demonstrates how to test the friend-related endpoints

set -e

# Backend URL
BASE_URL="http://localhost:4000"

echo "🧪 Testing Friend Endpoints"
echo "================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}📋 Test Users Available:${NC}"
echo "  1. alice_chef (user_test_001) - Alice Chen"
echo "  2. bob_foodie (user_test_002) - Bob Martinez"
echo "  3. carol_eats (user_test_003) - Carol Johnson"
echo "  4. david_dines (user_test_004) - David Kim"
echo "  5. emma_tastes (user_test_005) - Emma Wilson"
echo "  6. frank_plates (user_test_006) - Frank Lopez"
echo "  7. grace_grubs (user_test_007) - Grace Taylor"
echo "  8. henry_eats (user_test_008) - Henry Brown"
echo "  9. iris_dishes (user_test_009) - Iris Anderson"
echo "  10. jack_meals (user_test_010) - Jack Robinson"
echo ""

# Test 1: Search for users
echo -e "${GREEN}Test 1: Search for users${NC}"
echo "Searching for 'alice'..."
curl -s -G "${BASE_URL}/trpc/users.list" \
  --data-urlencode 'input={"json":{"search":"alice"}}' | \
  python3 -m json.tool | head -30
echo ""
echo ""

# Test 2: Get a specific user
echo -e "${GREEN}Test 2: Get user by Clerk ID${NC}"
echo "Getting Alice's profile..."
curl -s -G "${BASE_URL}/trpc/users.getByClerkId" \
  --data-urlencode 'input={"clerkId":"user_test_001"}' | \
  python3 -m json.tool
echo ""
echo ""

# Test 3: Check if two users are friends (public endpoint)
echo -e "${GREEN}Test 3: Check if users are friends (Alice & Bob)${NC}"
curl -s -G "${BASE_URL}/trpc/friends.areFriends" \
  --data-urlencode 'input={"userId1":"user_test_001","userId2":"user_test_002"}' | \
  python3 -m json.tool
echo ""
echo ""

# Test 4: Get mutual friends (public endpoint)
echo -e "${GREEN}Test 4: Get mutual friends between Alice and Bob${NC}"
curl -s -G "${BASE_URL}/trpc/friends.getMutualFriends" \
  --data-urlencode 'input={"userId1":"user_test_001","userId2":"user_test_002"}' | \
  python3 -m json.tool
echo ""
echo ""

echo -e "${YELLOW}⚠️  Note: Protected endpoints require authentication${NC}"
echo ""
echo "The following endpoints require authentication (via iOS app or Clerk token):"
echo "  - friends.sendRequest (POST) - Send a friend request"
echo "  - friends.acceptRequest (POST) - Accept a friend request"
echo "  - friends.rejectRequest (POST) - Reject a friend request"
echo "  - friends.getFriends (GET) - Get user's friends list"
echo "  - friends.getPendingRequests (GET) - Get pending friend requests"
echo "  - friends.removeFriend (POST) - Remove a friend"
echo "  - friends.blockUser (POST) - Block a user"
echo "  - friends.getFriendSuggestions (GET) - Get friend suggestions"
echo ""
echo "To test these endpoints:"
echo "1. Launch the iOS app on the simulator"
echo "2. Sign in with Clerk authentication"
echo "3. Use the app's UI to test friend features"
echo "4. Or extract the auth token from the app and use it in curl requests"
echo ""

echo -e "${GREEN}✅ Public endpoint tests completed!${NC}"
echo ""
echo "Backend is running at: ${BASE_URL}"
echo "tRPC panel: ${BASE_URL}/trpc/panel"
echo "Health check: ${BASE_URL}/health"

