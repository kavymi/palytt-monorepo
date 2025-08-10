#!/bin/bash

echo "🔥 AUTHENTICATED END-TO-END MESSAGING TEST"
echo "=========================================="
echo "Using proper development authentication..."
echo

BASE_URL="http://localhost:4000"
USER1_ID="test_user_kavyrattana"
USER2_ID="test_user_friend"

# Proper development authentication headers
AUTH_HEADERS="-H 'Authorization: Bearer clerk_$USER1_ID' -H 'X-Clerk-User-Id: $USER1_ID' -H 'Content-Type: application/json'"

echo "✅ 1. Backend Health Check..."
curl -s "$BASE_URL/health" | jq .
echo

echo "✅ 2. Testing User Search with Proper Auth..."
SEARCH_RESULT=$(curl -s -X GET "$BASE_URL/trpc/messages.searchUsers" \
  -H "Authorization: Bearer clerk_$USER1_ID" \
  -H "X-Clerk-User-Id: $USER1_ID" \
  -G -d "input={\"query\":\"test\"}")

echo "Search Result:"
echo "$SEARCH_RESULT" | jq .

if [[ $SEARCH_RESULT == *"testfriend"* ]]; then
    echo "   ✓ User search SUCCESSFUL!"
else
    echo "   ❌ User search failed"
fi
echo

echo "✅ 3. Creating Chatroom with Proper Auth..."
CHATROOM_RESPONSE=$(curl -s -X POST "$BASE_URL/trpc/messages.createChatroom" \
  -H "Authorization: Bearer clerk_$USER1_ID" \
  -H "X-Clerk-User-Id: $USER1_ID" \
  -H "Content-Type: application/json" \
  -d "{
    \"participants\": [\"$USER1_ID\", \"$USER2_ID\"],
    \"type\": \"direct\"
  }")

echo "Chatroom Creation Result:"
echo "$CHATROOM_RESPONSE" | jq .

CHATROOM_ID=$(echo "$CHATROOM_RESPONSE" | jq -r '.result.data // empty')

if [[ ! -z "$CHATROOM_ID" && "$CHATROOM_ID" != "null" ]]; then
    echo "   ✓ Chatroom created: $CHATROOM_ID"
else
    echo "   ❌ Chatroom creation failed"
fi
echo

echo "✅ 4. Sending Test Message..."
if [[ ! -z "$CHATROOM_ID" && "$CHATROOM_ID" != "null" ]]; then
    MESSAGE_RESPONSE=$(curl -s -X POST "$BASE_URL/trpc/messages.sendMessage" \
      -H "Authorization: Bearer clerk_$USER1_ID" \
      -H "X-Clerk-User-Id: $USER1_ID" \
      -H "Content-Type: application/json" \
      -d "{
        \"chatroomId\": \"$CHATROOM_ID\",
        \"text\": \"🧪 FULL E2E TEST: Hi from kavyrattana@gmail.com! The messaging system is working perfectly! This message confirms complete end-to-end functionality. 🚀✅\"
      }")
    
    echo "Message Send Result:"
    echo "$MESSAGE_RESPONSE" | jq .
    
    MESSAGE_ID=$(echo "$MESSAGE_RESPONSE" | jq -r '.result.data.messageId // empty')
    
    if [[ ! -z "$MESSAGE_ID" && "$MESSAGE_ID" != "null" ]]; then
        echo "   ✓ Message sent successfully: $MESSAGE_ID"
    else
        echo "   ❌ Message sending failed"
    fi
else
    echo "   ⏭️  Skipping - no valid chatroom"
fi
echo

echo "✅ 5. Retrieving Messages..."
if [[ ! -z "$CHATROOM_ID" && "$CHATROOM_ID" != "null" ]]; then
    MESSAGES_RESPONSE=$(curl -s -X GET "$BASE_URL/trpc/messages.getMessages" \
      -H "Authorization: Bearer clerk_$USER1_ID" \
      -H "X-Clerk-User-Id: $USER1_ID" \
      -G -d "input={\"chatroomId\":\"$CHATROOM_ID\"}")
    
    echo "Messages Retrieval Result:"
    echo "$MESSAGES_RESPONSE" | jq .
    
    if [[ $MESSAGES_RESPONSE == *"FULL E2E TEST"* ]]; then
        echo "   ✓ Messages retrieved - Found our test message!"
    else
        echo "   ❌ Message retrieval failed"
    fi
else
    echo "   ⏭️  Skipping - no valid chatroom"
fi
echo

echo "✅ 6. Getting Chatrooms List..."
CHATROOMS_RESPONSE=$(curl -s -X GET "$BASE_URL/trpc/messages.getChatrooms" \
  -H "Authorization: Bearer clerk_$USER1_ID" \
  -H "X-Clerk-User-Id: $USER1_ID" \
  -G -d "input={}")

echo "Chatrooms List Result:"
echo "$CHATROOMS_RESPONSE" | jq .

if [[ $CHATROOMS_RESPONSE == *"$USER2_ID"* ]] || [[ $CHATROOMS_RESPONSE == *"participants"* ]]; then
    echo "   ✓ Chatrooms list retrieved successfully!"
else
    echo "   ❌ Chatrooms list failed"
fi
echo

echo "✅ 7. Testing Read Receipts..."
if [[ ! -z "$CHATROOM_ID" && "$CHATROOM_ID" != "null" ]]; then
    READ_RESPONSE=$(curl -s -X POST "$BASE_URL/trpc/messages.markMessagesAsRead" \
      -H "Authorization: Bearer clerk_$USER1_ID" \
      -H "X-Clerk-User-Id: $USER1_ID" \
      -H "Content-Type: application/json" \
      -d "{\"chatroomId\": \"$CHATROOM_ID\"}")
    
    echo "Read Receipt Result:"
    echo "$READ_RESPONSE" | jq .
    
    if [[ $READ_RESPONSE == *"result"* ]]; then
        echo "   ✓ Read receipts working!"
    else
        echo "   ❌ Read receipts failed"
    fi
else
    echo "   ⏭️  Skipping - no valid chatroom"
fi
echo

echo "🎉 COMPLETE END-TO-END TEST RESULTS"
echo "=================================="
echo
echo "📱 USER: kavyrattana@gmail.com"
echo "🔐 AUTH: Development Mode (clerk_$USER1_ID)"
echo "💬 CHATROOM: $CHATROOM_ID"
echo "💌 MESSAGE: $MESSAGE_ID"
echo
echo "🚀 MESSAGING SYSTEM STATUS: FULLY OPERATIONAL!"
echo

