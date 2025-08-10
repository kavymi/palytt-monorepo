#!/bin/bash

# Test backend endpoints
echo "🚀 Testing Backend Endpoints"
echo "============================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base URL
BASE_URL="http://localhost:4000"

# Test headers (simulating a logged-in user)
HEADERS="-H 'Content-Type: application/json' -H 'Authorization: Bearer clerk_test_user_123' -H 'X-Clerk-User-Id: test_user_123'"

# 1. Health Check
echo -e "\n${BLUE}1. Testing Health Check...${NC}"
curl -s ${BASE_URL}/health | jq '.'

# 2. Create a Post
echo -e "\n${BLUE}2. Creating a test post...${NC}"
POST_DATA='{
  "shopName": "Test Cafe",
  "foodItem": "Avocado Toast",
  "description": "Delicious avocado toast with poached eggs",
  "rating": 4.5,
  "imageUrls": ["https://example.com/avocado-toast.jpg"],
  "tags": ["breakfast", "healthy"],
  "location": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "address": "123 Market St, San Francisco, CA",
    "name": "Test Cafe"
  },
  "isPublic": true
}'

RESPONSE=$(curl -s -X POST ${BASE_URL}/trpc/posts.create \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer clerk_test_user_123' \
  -H 'X-Clerk-User-Id: test_user_123' \
  -d "${POST_DATA}")

echo "$RESPONSE" | jq '.'

# Extract post ID for subsequent tests
POST_ID=$(echo "$RESPONSE" | jq -r '.result.data.post.id')

if [ "$POST_ID" != "null" ]; then
  echo -e "${GREEN}✅ Post created successfully with ID: $POST_ID${NC}"
else
  echo -e "${RED}❌ Failed to create post${NC}"
  exit 1
fi

# 3. Get All Posts
echo -e "\n${BLUE}3. Getting all posts...${NC}"
curl -s -G "${BASE_URL}/trpc/posts.list" \
  --data-urlencode 'input={"page":1,"limit":10}' | jq '.result.data.posts[0]'

# 4. Get Post by ID
echo -e "\n${BLUE}4. Getting post by ID...${NC}"
curl -s -G "${BASE_URL}/trpc/posts.getById" \
  --data-urlencode "input={\"id\":\"$POST_ID\"}" | jq '.result.data'

# 5. Toggle Like
echo -e "\n${BLUE}5. Toggling like on post...${NC}"
curl -s -X POST ${BASE_URL}/trpc/posts.toggleLike \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer clerk_test_user_123' \
  -H 'X-Clerk-User-Id: test_user_123' \
  -d "{\"postId\":\"$POST_ID\"}" | jq '.result.data'

# 6. Add Comment
echo -e "\n${BLUE}6. Adding a comment...${NC}"
curl -s -X POST ${BASE_URL}/trpc/posts.addComment \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer clerk_test_user_123' \
  -H 'X-Clerk-User-Id: test_user_123' \
  -d "{\"postId\":\"$POST_ID\",\"comment\":{\"content\":\"Great food!\"}}" | jq '.result.data'

# 7. Get Comments
echo -e "\n${BLUE}7. Getting comments...${NC}"
curl -s -G "${BASE_URL}/trpc/posts.getComments" \
  --data-urlencode "input={\"postId\":\"$POST_ID\",\"page\":1,\"limit\":10}" | jq '.result.data'

# 8. Toggle Bookmark
echo -e "\n${BLUE}8. Toggling bookmark...${NC}"
curl -s -X POST ${BASE_URL}/trpc/posts.toggleBookmark \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer clerk_test_user_123' \
  -H 'X-Clerk-User-Id: test_user_123' \
  -d "{\"postId\":\"$POST_ID\"}" | jq '.result.data'

echo -e "\n${GREEN}✨ All tests completed!${NC}" 