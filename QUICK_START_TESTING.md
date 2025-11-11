# Quick Start: Test Friend Endpoints in 5 Minutes

## Step 1: Create Clerk User (1 min)

1. Open: **https://dashboard.clerk.com/**
2. Click **"Users"** in sidebar
3. Click **"Create User"** button
4. Fill in:
   ```
   Email:      test@palytt.app
   Username:   test_user
   First Name: Test
   Last Name:  User
   Password:   TestPassword123!
   ```
5. Click **"Create"**
6. **COPY the User ID** (looks like: `user_2abc123def456`)

## Step 2: Link to Database (30 seconds)

```bash
cd palytt-backend
pnpm update:test-clerk-id user_YOUR_COPIED_ID_HERE
```

Example:
```bash
pnpm update:test-clerk-id user_2abc123def456
```

## Step 3: Login & Test (2 minutes)

1. **Look at your iOS Simulator** (should still be running)
2. **Click "Sign In"** or **"Get Started"**
3. Enter:
   - Email: `test@palytt.app`
   - Password: `TestPassword123!`
4. **You're in!** 🎉

## Step 4: Test Friend Features

Now you can test everything:

### ✅ Search for Users
- Type "alice" in search
- Type "bob" 
- You should see the 10 test users

### ✅ Send Friend Request
- Click on **Alice Chen** (@alice_chef)
- Click **"Add Friend"** or **"Send Request"**
- Watch backend terminal for: `POST /trpc/friends.sendRequest`

### ✅ View Requests
- Go to **Notifications** or **Profile**
- See pending requests

### ✅ Accept/Reject
- Click Accept or Decline
- Watch backend logs

### ✅ View Friends
- Go to **Friends List**
- See your connections

## Backend Monitoring

Your backend terminal will show all API calls in real-time:
```
POST /trpc/friends.sendRequest
GET  /trpc/friends.getPendingRequests  
POST /trpc/friends.acceptRequest
GET  /trpc/friends.getFriends
```

## Database Viewer

To see the data changing:
```bash
cd palytt-backend
pnpm prisma:studio
```
Opens at: http://localhost:5555

---

## 🤖 Option 2: Automated (if you have Clerk Secret Key)

If you have your Clerk Secret Key:

```bash
cd palytt-backend
CLERK_SECRET_KEY=sk_test_YOUR_KEY pnpm setup:test-user
```

This will:
- ✅ Create user in Clerk automatically
- ✅ Create user in database automatically
- ✅ Show you the credentials
- ✅ Ready to test immediately!

Get your secret key from: https://dashboard.clerk.com/ → API Keys

---

## Quick Reference

**Test Users Available:**
- alice_chef (Alice Chen)
- bob_foodie (Bob Martinez)
- carol_eats (Carol Johnson)
- david_dines (David Kim)
- emma_tastes (Emma Wilson)

**Your Login:**
- Email: test@palytt.app
- Password: TestPassword123!

**Backend:**
- API: http://localhost:4000
- Panel: http://localhost:4000/trpc/panel
- Health: http://localhost:4000/health

**Commands:**
```bash
# View database
pnpm prisma:studio

# Restart backend
pnpm dev

# Test endpoints
./scripts/test-friend-endpoints.sh
```

---

## Troubleshooting

**App not responding?**
- Check simulator is running
- Check backend is running at :4000

**Can't log in?**
- Verify user was created in Clerk dashboard
- Verify user was added to database with correct Clerk ID
- Check password matches

**Friend request failed?**
- Check backend logs for error
- Verify receiver user exists
- Check you're not trying to friend yourself

---

**That's it! You're ready to test! 🚀**

