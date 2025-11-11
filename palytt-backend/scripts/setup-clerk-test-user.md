# Setup Clerk Test User for API Testing

## Overview
To test the protected friend endpoints, you need a user that exists in both Clerk (for authentication) and your database (for API operations).

## Your Clerk Configuration
- **Publishable Key:** `pk_test_bmF0dXJhbC13YWxsZXllLTQ4LmNsZXJrLmFjY291bnRzLmRldiQ`
- **Environment:** Test/Development
- **Dashboard:** https://dashboard.clerk.com/

## Option 1: Create Test User via Clerk Dashboard (Recommended)

### Step 1: Create User in Clerk
1. Go to https://dashboard.clerk.com/
2. Navigate to **Users** in the sidebar
3. Click **Create User**
4. Fill in the details:
   - **Email:** `test@palytt.app`
   - **Username:** `test_user`
   - **First Name:** `Test`
   - **Last Name:** `User`
   - **Password:** Set a password you'll remember
5. Click **Create User**
6. **IMPORTANT:** Copy the **User ID** (starts with `user_`)

### Step 2: Add User to Database
Once you have the Clerk User ID, update the database insertion script:

```bash
cd /Users/kavyrattana/Coding/palytt-monorepo/palytt-backend

# Edit the script to use your real Clerk ID
# Replace 'user_test_manual' with the actual Clerk ID from Step 1
```

Then run:
```bash
pnpm create:test-account
```

### Step 3: Log In to iOS App
1. Open the Palytt app on the simulator
2. Sign in with:
   - **Email:** `test@palytt.app`
   - **Password:** The password you set in Step 1
3. The app will authenticate with Clerk and sync with your database

## Option 2: Use Clerk's API to Create User

### Prerequisites
- Clerk Secret Key (from dashboard.clerk.com → API Keys)

### Create User Script

```typescript
// save as: scripts/create-clerk-user.ts
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function createClerkUser() {
  const CLERK_SECRET_KEY = process.env.CLERK_SECRET_KEY;
  
  if (!CLERK_SECRET_KEY) {
    console.error('❌ CLERK_SECRET_KEY environment variable not set');
    console.log('Get your secret key from: https://dashboard.clerk.com/');
    process.exit(1);
  }

  const userData = {
    email_address: ['test@palytt.app'],
    username: 'test_user',
    first_name: 'Test',
    last_name: 'User',
    password: 'TestPassword123!',
  };

  try {
    // Create user in Clerk
    const response = await fetch('https://api.clerk.com/v1/users', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${CLERK_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(userData),
    });

    if (!response.ok) {
      throw new Error(`Clerk API error: ${response.statusText}`);
    }

    const clerkUser = await response.json();
    console.log('✅ Created user in Clerk:', clerkUser.id);

    // Create user in database
    const dbUser = await prisma.user.create({
      data: {
        clerkId: clerkUser.id,
        email: userData.email_address[0],
        username: userData.username,
        name: `${userData.first_name} ${userData.last_name}`,
        bio: 'Test account for development',
        profileImage: 'https://i.pravatar.cc/150?img=50',
      },
    });

    console.log('✅ Created user in database:', dbUser.id);
    console.log('\n📋 Login Credentials:');
    console.log('   Email:', userData.email_address[0]);
    console.log('   Password:', userData.password);
    console.log('   Clerk ID:', clerkUser.id);
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

createClerkUser();
```

Run with:
```bash
CLERK_SECRET_KEY=your_secret_key_here pnpm tsx scripts/create-clerk-user.ts
```

## Option 3: Use Existing Test User from Seed

If you just want to test the API without logging into the app:

### Quick API Testing with cURL

```bash
# First, log in via the app to get a session token
# Then extract the token from the app's network requests

# Send friend request
curl -X POST "http://localhost:4000/trpc/friends.sendRequest" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"json":{"receiverId":"user_test_002"}}'
```

## Testing Flow

Once you have a working test account:

1. **Log in to the app** with your test credentials
2. **Search for users** - Try "alice", "bob", etc.
3. **Send friend requests**:
   - Alice Chen (@alice_chef) - user_test_001
   - Bob Martinez (@bob_foodie) - user_test_002
   - Carol Johnson (@carol_eats) - user_test_003
4. **Monitor backend logs** to see API calls
5. **Test friend features**:
   - View pending requests
   - Accept/reject requests
   - See friends list
   - Get friend suggestions

## Troubleshooting

### Issue: "User not found in database"
- Make sure you ran the database insert script after creating the Clerk user
- Verify the Clerk ID matches exactly

### Issue: "Authentication failed"
- Check that you're using the correct email/password
- Verify Clerk is configured correctly in the iOS app
- Check backend logs for authentication errors

### Issue: "Cannot send friend request"
- Make sure the receiver user exists in the database
- Check that you're not trying to friend yourself
- Verify you haven't already sent a request to that user

## Next Steps

After successful login:
1. Test all friend endpoints through the app UI
2. Monitor backend logs at `http://localhost:4000`
3. View database state with `pnpm prisma:studio`
4. Check friend requests in the Notifications tab

