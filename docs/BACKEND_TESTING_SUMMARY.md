# Backend Testing Summary

## Setup Completed ✅

### 1. Backend Server
- **Status:** Running successfully
- **URL:** http://localhost:4000
- **tRPC Panel:** http://localhost:4000/trpc/panel
- **Health Check:** http://localhost:4000/health

### 2. Test Database Seeding
Successfully created 10 test users:

| Username | Clerk ID | Name | Bio |
|----------|----------|------|-----|
| alice_chef | user_test_001 | Alice Chen | Food enthusiast \| NYC \| Love trying new restaurants 🍕 |
| bob_foodie | user_test_002 | Bob Martinez | Foodie & Photographer \| San Francisco \| Coffee addict ☕ |
| carol_eats | user_test_003 | Carol Johnson | Restaurant blogger \| LA \| Always hunting for the best tacos 🌮 |
| david_dines | user_test_004 | David Kim | Tech & Food \| Seattle \| Sushi lover 🍣 |
| emma_tastes | user_test_005 | Emma Wilson | Pastry chef \| Boston \| Sweet tooth 🍰 |
| frank_plates | user_test_006 | Frank Lopez | Food critic \| Miami \| BBQ enthusiast 🥩 |
| grace_grubs | user_test_007 | Grace Taylor | Vegetarian foodie \| Portland \| Farm to table advocate 🥗 |
| henry_eats | user_test_008 | Henry Brown | International cuisine explorer \| Chicago \| Spicy food lover 🌶️ |
| iris_dishes | user_test_009 | Iris Anderson | Food writer \| Denver \| Wine & dine enthusiast 🍷 |
| jack_meals | user_test_010 | Jack Robinson | Home cook sharing my journey \| Austin \| Tex-Mex expert 🌯 |

**Seeding Script:** `palytt-backend/scripts/seed-users.ts`
**Command:** `pnpm seed:users`

### 3. iOS App
- **Status:** Running on iPhone 17 Pro simulator
- **Bundle ID:** com.palytt.app
- **Simulator ID:** 08508F01-85DF-4F1A-8B4C-47DCF12F2E72

## Endpoint Testing Results

### Public Endpoints (No Auth Required) ✅

#### 1. User Search - `users.list`
```bash
curl -G "http://localhost:4000/trpc/users.list" \
  --data-urlencode 'input={"json":{"search":"alice"}}'
```
**Result:** Returns user list (note: search filtering needs improvement)

#### 2. Get User by Clerk ID - `users.getByClerkId`
```bash
curl -G "http://localhost:4000/trpc/users.getByClerkId" \
  --data-urlencode 'input={"clerkId":"user_test_001"}'
```
**Result:** ✅ Successfully returns user data
```json
{
  "id": "06dd91bc-24bc-4f7c-9e2a-31abfd89aaaf",
  "clerkId": "user_test_001",
  "email": "alice@test.com",
  "username": "alice_chef",
  "name": "Alice Chen",
  "bio": "Food enthusiast | NYC | Love trying new restaurants 🍕"
}
```

#### 3. Check Friendship Status - `friends.areFriends`
```bash
curl -G "http://localhost:4000/trpc/friends.areFriends" \
  --data-urlencode 'input={"userId1":"user_test_001","userId2":"user_test_002"}'
```
**Result:** ✅ Successfully returns friendship status
```json
{
  "areFriends": false
}
```

#### 4. Get Mutual Friends - `friends.getMutualFriends`
```bash
curl -G "http://localhost:4000/trpc/friends.getMutualFriends" \
  --data-urlencode 'input={"userId1":"user_test_001","userId2":"user_test_002"}'
```
**Result:** ✅ Successfully returns mutual friends list
```json
{
  "mutualFriends": [],
  "totalCount": 0
}
```

### Protected Endpoints (Auth Required) 🔒

The following endpoints require Clerk authentication and should be tested via the iOS app:

1. **`friends.sendRequest`** - Send a friend request
   - Input: `{ receiverId: string }`
   - Returns: Friend request object with sender/receiver info

2. **`friends.acceptRequest`** - Accept a friend request
   - Input: `{ requestId: string }`
   - Returns: Updated friend request with ACCEPTED status

3. **`friends.rejectRequest`** - Reject/decline a friend request
   - Input: `{ requestId: string }`
   - Returns: `{ success: true }`

4. **`friends.getFriends`** - Get all friends for a user
   - Input: `{ userId?: string, limit?: number, cursor?: string }`
   - Returns: Paginated list of friends

5. **`friends.getPendingRequests`** - Get pending friend requests
   - Input: `{ type: 'sent' | 'received' | 'all', limit?: number, cursor?: string }`
   - Returns: List of pending friend requests

6. **`friends.removeFriend`** - Remove/unfriend a user
   - Input: `{ friendId: string }`
   - Returns: `{ success: true }`

7. **`friends.blockUser`** - Block a user
   - Input: `{ userId: string }`
   - Returns: `{ success: true }`

8. **`friends.getFriendSuggestions`** - Get friend suggestions based on friends-of-friends
   - Input: `{ limit?: number, excludeRequested?: boolean }`
   - Returns: List of suggested users with mutual friend counts

## Testing via iOS App

To test the protected endpoints:

1. **Launch the app** (already running on simulator)
2. **Sign in** with Clerk authentication
3. **Navigate to friend features:**
   - Search for users: "alice", "bob", etc.
   - Send friend requests
   - Accept/reject requests
   - View friends list
   - See friend suggestions

## Files Created/Modified

### New Files:
- `palytt-backend/scripts/seed-users.ts` - Database seeding script
- `palytt-backend/scripts/test-friend-endpoints.sh` - Endpoint testing script
- `docs/BACKEND_TESTING_SUMMARY.md` - This document

### Modified Files:
- `palytt-backend/package.json` - Added `seed:users` script

## Quick Commands

```bash
# Start backend
cd palytt-backend && pnpm dev

# Seed test users
cd palytt-backend && pnpm seed:users

# Test public endpoints
cd palytt-backend && ./scripts/test-friend-endpoints.sh

# Build and run iOS app
cd palytt && xcodebuild -project Palytt.xcodeproj -scheme Palytt \
  -destination 'platform=iOS Simulator,id=08508F01-85DF-4F1A-8B4C-47DCF12F2E72' \
  -allowProvisioningUpdates build

# Install app on simulator
xcrun simctl install 08508F01-85DF-4F1A-8B4C-47DCF12F2E72 \
  /Users/kavyrattana/Library/Developer/Xcode/DerivedData/Palytt-*/Build/Products/Debug-iphonesimulator/Palytt.app

# Launch app
xcrun simctl launch 08508F01-85DF-4F1A-8B4C-47DCF12F2E72 com.palytt.app
```

## Notes

### Search Functionality Issue
The user search endpoint (`users.list`) is currently returning all users regardless of the search term. This may need to be investigated:
- Expected: Filtered results based on search term
- Actual: All 10 users returned

The search logic in `users.ts` uses:
```typescript
where: input.search
  ? {
      OR: [
        { name: { contains: input.search, mode: 'insensitive' } },
        { username: { contains: input.search, mode: 'insensitive' } },
        { email: { contains: input.search, mode: 'insensitive' } },
      ],
    }
  : {};
```

This should be working correctly, so the issue might be with how the search parameter is being passed or parsed.

## Next Steps

1. ✅ Backend running
2. ✅ Test users seeded
3. ✅ iOS app launched
4. ✅ Public endpoints tested
5. ⏳ Test protected endpoints via iOS app UI
6. 🔧 Fix user search filtering issue
7. 🔧 Implement friend request flow in iOS app UI (if not already present)

