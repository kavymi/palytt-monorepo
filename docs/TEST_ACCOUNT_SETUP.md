# Test Account Setup for API Testing

## Quick Summary

To test the protected friend endpoints, you need a user that exists in **both** Clerk (for authentication) AND your database (for API operations).

## ✅ Current Status

### Backend
- ✅ Running at `http://localhost:4000`
- ✅ 10 test users seeded in database
- ✅ Friend endpoints ready

### iOS App  
- ✅ Running on iPhone 17 Pro simulator
- ✅ Clerk configured with publishable key

### Database
- ✅ Test account placeholder created (`test@palytt.app`)
- ⏳ Needs real Clerk ID to function

## 🎯 Option 1: Quick Setup via Clerk Dashboard (Recommended)

### Step 1: Create User in Clerk

1. Go to **https://dashboard.clerk.com/**
2. Navigate to **Users** tab
3. Click **"Create User"**
4. Fill in:
   ```
   Email:      test@palytt.app
   Username:   test_user
   First Name: Test
   Last Name:  User
   Password:   [Choose a password]
   ```
5. Click **Create**
6. **COPY THE USER ID** (looks like `user_2abc123def456`)

### Step 2: Update Database with Clerk ID

```bash
cd palytt-backend

# Run the update script with your Clerk User ID
pnpm update:test-clerk-id user_YOUR_ACTUAL_CLERK_ID_HERE
```

Example:
```bash
pnpm update:test-clerk-id user_2abc123def456
```

### Step 3: Log In to iOS App

1. Look at the running iOS simulator
2. Click **Sign In** (or sign up if needed)
3. Enter:
   - Email: `test@palytt.app`
   - Password: [The password you set in Step 1]
4. You're now authenticated! 🎉

## 🧪 Option 2: Test Without Real Login

If you just want to test the API endpoints without the iOS app:

### Create a Temporary Test Session

```typescript
// In scripts/create-temp-test-session.ts
// This would generate a test JWT token for API testing
// (Not implemented yet - would require Clerk secret key)
```

**Note:** This is more complex and requires Clerk secret key. Option 1 is recommended.

## 📱 Testing Friend Features

Once logged in, you can:

### 1. Search for Users
- Type "alice", "bob", "carol" in the search
- See the 10 test users we created

### 2. Send Friend Requests
Available test users:
- alice_chef (user_test_001) - Alice Chen
- bob_foodie (user_test_002) - Bob Martinez  
- carol_eats (user_test_003) - Carol Johnson
- david_dines (user_test_004) - David Kim
- emma_tastes (user_test_005) - Emma Wilson
- frank_plates (user_test_006) - Frank Lopez
- grace_grubs (user_test_007) - Grace Taylor
- henry_eats (user_test_008) - Henry Brown
- iris_dishes (user_test_009) - Iris Anderson
- jack_meals (user_test_010) - Jack Robinson

### 3. View & Manage Requests
- Go to Notifications/Profile to see pending requests
- Accept or reject requests
- View your friends list
- See friend suggestions

## 🔍 Monitoring & Debugging

### Backend Logs
The backend terminal will show all API calls:
```bash
POST /trpc/friends.sendRequest
GET  /trpc/friends.getFriends
POST /trpc/friends.acceptRequest
```

### Database Viewer
```bash
cd palytt-backend
pnpm prisma:studio
```

This opens a web UI at `http://localhost:5555` to view/edit database records.

### tRPC Panel
Visit: `http://localhost:4000/trpc/panel`

Interactive API playground (requires authentication for protected endpoints).

## 🛠️ Scripts Available

```bash
# Create initial test account (without Clerk ID)
pnpm create:test-account

# Update test account with real Clerk ID
pnpm update:test-clerk-id <CLERK_USER_ID>

# Seed 10 test users
pnpm seed:users

# Test public endpoints
./scripts/test-friend-endpoints.sh

# View database
pnpm prisma:studio
```

## ❓ Troubleshooting

### "User not found" Error
- Make sure you ran `pnpm update:test-clerk-id` with your actual Clerk User ID
- Verify the Clerk ID in database matches the one in Clerk dashboard

### "Authentication failed"
- Double-check your password
- Make sure Clerk user exists at https://dashboard.clerk.com/
- Try logging out and back in

### "Cannot send friend request"
- Make sure the receiver user exists in database
- Check you're not trying to friend yourself  
- Verify you haven't already sent a request

### Backend Connection Issues
```bash
# Check if backend is running
curl http://localhost:4000/health

# If not running, restart:
cd palytt-backend
pnpm dev
```

## 📊 API Endpoints Reference

### Public Endpoints (No Auth)
- `users.list` - Search users
- `users.getByClerkId` - Get user profile
- `friends.areFriends` - Check friendship status
- `friends.getMutualFriends` - Get mutual friends

### Protected Endpoints (Auth Required)
- `friends.sendRequest` - Send friend request
- `friends.acceptRequest` - Accept friend request
- `friends.rejectRequest` - Reject friend request  
- `friends.getFriends` - Get friends list
- `friends.getPendingRequests` - Get pending requests
- `friends.removeFriend` - Remove friend
- `friends.blockUser` - Block user
- `friends.getFriendSuggestions` - Get suggestions

## 🎉 Success Criteria

You'll know everything is working when:
1. ✅ You can log in to the iOS app
2. ✅ You can search and see test users
3. ✅ You can send a friend request
4. ✅ Backend logs show the API call
5. ✅ Friend request appears in notifications
6. ✅ You can accept/reject requests
7. ✅ Friends list updates correctly

## 📚 Related Documentation

- **Backend Testing:** `docs/BACKEND_TESTING_SUMMARY.md`
- **Clerk Setup Guide:** `palytt-backend/scripts/setup-clerk-test-user.md`
- **Friend Endpoints:** `palytt-backend/src/routers/friends.ts`

## 🔐 Security Note

This is a **development/test environment**. Never use these patterns in production:
- Never hardcode test passwords
- Never commit Clerk secret keys
- Always use environment variables for sensitive data
- Use proper authentication middleware in production

